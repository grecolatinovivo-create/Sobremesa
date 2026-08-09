//
//  DataService.swift
//  Sobremesa
//
//  Le operazioni di prodotto, dietro un protocollo: le view non scrivono
//  mai direttamente nei modelli. Il server è la fonte di verità; qui vive
//  l'effetto locale ottimistico e la valutazione temporale della brace.
//

import Foundation
import SwiftData

// MARK: - Notifica in-app

/// Notifica in-app prodotta da un'operazione (da mostrare come toast).
struct AppNotice: Identifiable, Equatable {
    let id = UUID()
    /// Messaggio già localizzato e formattato.
    let message: String
    /// true = evento grave (penalità, espulsione): il banner resta finché
    /// l'utente non lo chiude (UX_SPEC §3.3), niente auto-dismiss.
    var sticky: Bool = false
}

// MARK: - Protocollo

@MainActor
protocol DataService {
    var engine: SobremesaEngine { get }

    // Profilo
    func hasProfile() -> Bool
    func createProfile(name: String, appleUserID: String?)
    func me() -> Person?
    func updateName(_ name: String)
    func resetAllData()

    // Tavoli
    func myMemberships() -> [Membership]
    func membership(of tavolo: Tavolo) -> Membership?
    func createTable(name: String, theme: String, category: PostCategory, isOpen: Bool) -> [AppNotice]
    func joinTable(_ tavolo: Tavolo) -> Bool
    func leaveTable(_ tavolo: Tavolo)
    func retakeWord(at tavolo: Tavolo) -> [AppNotice]
    func accept(_ request: JoinRequest) -> [AppNotice]
    func decline(_ request: JoinRequest)

    // Conversazione
    func sendMessage(_ text: String, at tavolo: Tavolo) -> [AppNotice]
    func toggleNutre(on messaggio: Messaggio)

    /// Rivaluta la brace di tutti i tavoli abitati (avvio, foreground, debug).
    func evaluateEmbers(now: Date) -> [AppNotice]
    #if DEBUG
    /// Solo DEBUG: sposta indietro le date di attività per testare la meccanica.
    func simulateSilence(days: Int) -> [AppNotice]
    #endif

    /// Nutre totali ricevuti sui MIEI messaggi (per il toast di gratitudine).
    func myReceivedNutre() -> Int
    /// Segna letta la conversazione del tavolo (alimenta i "nuovi interventi").
    func markRead(_ tavolo: Tavolo)

    // Backend
    /// Riversa il mondo del server nello store locale (v. SyncApply).
    func applySync(_ payload: SyncPayload)
}

// MARK: - LocalDataService

@MainActor
final class LocalDataService: DataService {

    let engine: SobremesaEngine
    let context: ModelContext  // interno: usato anche da SyncApply
    private let seedFlagKey = "sobremesa.didSeed"

    init(context: ModelContext, engine: SobremesaEngine = SobremesaEngine()) {
        self.context = context
        self.engine = engine
    }

    // MARK: Fetch di base

    func me() -> Person? {
        var d = FetchDescriptor<Person>(predicate: #Predicate { $0.isMe })
        d.fetchLimit = 1
        return (try? context.fetch(d))?.first
    }

    func updateName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let me = me() else { return }
        me.name = trimmed
        save()
    }

    func myMemberships() -> [Membership] {
        let d = FetchDescriptor<Membership>(predicate: #Predicate { $0.person?.isMe == true })
        return ((try? context.fetch(d)) ?? []).sorted { $0.joinedAt < $1.joinedAt }
    }

    func membership(of tavolo: Tavolo) -> Membership? {
        myMemberships().first { $0.tavolo === tavolo }
    }

    // MARK: Punteggio (unico punto di mutazione)

    private func applyScore(_ action: ParticipationAction, to person: Person, at tavolo: Tavolo? = nil) {
        person.score = engine.apply(action, to: person.score)
        context.insert(ParticipationEvent(person: person,
                                          tavolo: tavolo,
                                          action: action,
                                          points: engine.points(for: action)))
    }

    /// Attività al tavolo: azzera il silenzio e il flag di penalità.
    private func touchActivity(_ membership: Membership, at date: Date = .now) {
        membership.lastActivity = date
        membership.silencePenaltyApplied = false
    }

    // MARK: Tavoli

    func createTable(name: String, theme: String, category: PostCategory, isOpen: Bool) -> [AppNotice] {
        guard let me = me(),
              engine.canJoinCircle(currentCircleCount: myMemberships().count) else { return [] }
        let tavolo = Tavolo(name: name, theme: theme, category: category,
                            isOpen: isOpen, animatedByMe: true, memberCount: 1)
        context.insert(tavolo)
        context.insert(Membership(person: me, tavolo: tavolo))
        save()
        return [AppNotice(message: String(format: String(localized: "toast.tavolo.fondato", bundle: L10n.bundle), name))]
    }

    func joinTable(_ tavolo: Tavolo) -> Bool {
        guard let me = me(),
              engine.canJoinCircle(currentCircleCount: myMemberships().count),
              tavolo.memberCount < engine.rules.maxFriends,
              membership(of: tavolo) == nil else { return false }
        context.insert(Membership(person: me, tavolo: tavolo))
        tavolo.memberCount += 1
        save()
        return true
    }

    func leaveTable(_ tavolo: Tavolo) {
        guard let membership = membership(of: tavolo) else { return }
        context.delete(membership)
        tavolo.memberCount = max(0, tavolo.memberCount - 1)
        // Uscita volontaria: nessuna penalità (DECISIONI.md #6).
        save()
    }

    func retakeWord(at tavolo: Tavolo) -> [AppNotice] {
        guard let me = me(), let membership = membership(of: tavolo) else { return [] }
        touchActivity(membership)
        applyScore(.ripresaParola, to: me, at: tavolo)
        save()
        return [braceNotice(for: tavolo)]
    }

    func accept(_ request: JoinRequest) -> [AppNotice] {
        guard let person = request.person, let tavolo = request.tavolo else { return [] }
        context.delete(request)
        // La guardia vera (12 sedie) sta sul server: qui solo l'ottimismo,
        // il sync successivo riallinea in ogni caso.
        context.insert(Membership(person: person, tavolo: tavolo))
        tavolo.memberCount += 1
        save()
        return [AppNotice(message: String(format: String(localized: "toast.accolto", bundle: L10n.bundle),
                                          person.name, tavolo.name))]
    }

    func decline(_ request: JoinRequest) {
        context.delete(request)
        save()
    }

    // MARK: Conversazione

    func sendMessage(_ text: String, at tavolo: Tavolo) -> [AppNotice] {
        guard let me = me(), let membership = membership(of: tavolo) else { return [] }
        context.insert(Messaggio(author: me, tavolo: tavolo, text: text))
        // Parlare al tavolo è partecipazione: +1 e la brace si ravviva.
        applyScore(.commento, to: me, at: tavolo)
        touchActivity(membership)
        save()
        return []
    }

    func toggleNutre(on messaggio: Messaggio) {
        // Il proprio piatto non si nutre da soli.
        guard messaggio.author?.isMe != true else { return }
        // Toggle senza doppio conteggio: il mio Nutre è un flag, non un incremento cieco.
        messaggio.nutritoDaMe.toggle()
        save()
    }

    func myReceivedNutre() -> Int {
        let all = (try? context.fetch(FetchDescriptor<Messaggio>())) ?? []
        return all.filter { $0.author?.isMe == true }.reduce(0) { $0 + $1.nutreCount }
    }

    func markRead(_ tavolo: Tavolo) {
        membership(of: tavolo)?.lastReadAt = .now
        save()
    }

    private func braceNotice(for tavolo: Tavolo) -> AppNotice {
        AppNotice(message: String(format: String(localized: "toast.brace.viva", bundle: L10n.bundle),
                                  tavolo.name))
    }

    // MARK: La regola della brace (valutazione temporale)

    func evaluateEmbers(now: Date = .now) -> [AppNotice] {
        guard let me = me() else { return [] }
        var notices: [AppNotice] = []
        for membership in myMemberships() {
            guard let tavolo = membership.tavolo else { continue }
            // La brace ha senso solo in compagnia: da soli resta in attesa.
            guard tavolo.memberCount >= engine.rules.emberMinimumMembers else { continue }
            let evaluation = engine.evaluateEmber(lastActivity: membership.lastActivity,
                                                  now: now,
                                                  penaltyAlreadyApplied: membership.silencePenaltyApplied)
            if evaluation.applySilencePenalty {
                membership.silencePenaltyApplied = true
                applyScore(.silenzio, to: me, at: tavolo)
                // Il valore della penalità viene da ProductRules, mai hardcoded nel copy.
                notices.append(AppNotice(message: String(format: String(localized: "toast.penalita", bundle: L10n.bundle),
                                                         tavolo.name,
                                                         engine.points(for: .silenzio)),
                                         sticky: true))
            }
            // L'animatore non viene espulso dal proprio tavolo: il luogo è suo.
            if evaluation.expel && !tavolo.animatedByMe {
                let days = engine.daysOfSilence(since: membership.lastActivity, now: now)
                context.delete(membership)
                tavolo.memberCount = max(0, tavolo.memberCount - 1)
                applyScore(.espulsione, to: me, at: tavolo)
                notices.append(AppNotice(message: String(format: String(localized: "toast.espulsione", bundle: L10n.bundle),
                                                         tavolo.name, days),
                                         sticky: true))
            }
        }
        save()
        return notices
    }

    #if DEBUG
    func simulateSilence(days: Int) -> [AppNotice] {
        // Sposta indietro le date reali: la meccanica resta identica alla produzione.
        for membership in myMemberships() {
            membership.lastActivity = membership.lastActivity.addingTimeInterval(-Double(days) * 86_400)
        }
        save()
        return evaluateEmbers(now: .now)
    }
    #endif

    // MARK: Profilo e reset

    func hasProfile() -> Bool {
        // Migrazione dalle build demo: quei dati erano finti, si riparte da zero.
        if UserDefaults.standard.bool(forKey: seedFlagKey) {
            purgeEverything()
            UserDefaults.standard.set(false, forKey: seedFlagKey)
            return false
        }
        return me() != nil
    }

    func createProfile(name: String, appleUserID: String?) {
        guard me() == nil else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = trimmed.isEmpty
            ? String(localized: "onboarding.fallback.name", bundle: L10n.bundle)
            : trimmed
        context.insert(Person(name: displayName,
                              score: engine.rules.initialScore,
                              isMe: true,
                              appleUserID: appleUserID))
        save()
    }

    func resetAllData() {
        purgeEverything()
        UserDefaults.standard.set(false, forKey: seedFlagKey)
    }

    private func purgeEverything() {
        try? context.delete(model: ParticipationEvent.self)
        try? context.delete(model: JoinRequest.self)
        try? context.delete(model: Messaggio.self)
        try? context.delete(model: Membership.self)
        try? context.delete(model: Tavolo.self)
        try? context.delete(model: Person.self)
        save()
    }

    private func save() {
        try? context.save()
    }
}
