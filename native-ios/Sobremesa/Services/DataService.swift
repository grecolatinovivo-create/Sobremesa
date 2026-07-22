//
//  DataService.swift
//  Sobremesa
//
//  Il "backend" di Sobremesa, dietro un protocollo: oggi è un servizio
//  locale su SwiftData (LocalDataService); domani può diventare un client
//  di rete senza toccare le view né l'engine.
//

import Foundation
import SwiftData

// MARK: - Esiti

/// Esito di un invito alla tavola.
enum InviteOutcome: Equatable {
    /// La persona si è seduta subito.
    case seated
    /// Tavola piena: l'invito resta in sospeso finché non si libera una sedia.
    case tableFull
}

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

/// Le operazioni di prodotto. Tutte le mutazioni passano da qui:
/// nessuna view scrive direttamente nei modelli.
@MainActor
protocol DataService {
    var engine: SobremesaEngine { get }

    /// Esiste già il profilo dell'utente?
    func hasProfile() -> Bool
    /// Crea il profilo reale al primo accesso (Sign in with Apple).
    func createProfile(name: String, appleUserID: String?)

    // Persone e tavola
    func me() -> Person?
    func updateName(_ name: String)
    func friendCount() -> Int
    func isFriend(_ person: Person) -> Bool
    func pendingInvitee() -> Person?
    func invite(_ person: Person) -> InviteOutcome
    func freeChair(_ friendship: Friendship) -> [AppNotice]
    func cancelPendingInvite()

    // Salotto
    func publish(text: String, category: PostCategory, in circolo: Circolo?) -> [AppNotice]
    func toggleNutre(on post: Post)
    func addComment(to post: Post, text: String) -> [AppNotice]

    // Circoli
    func myMemberships() -> [Membership]
    func membership(of circolo: Circolo) -> Membership?
    func joinCircle(_ circolo: Circolo) -> Bool
    func createCircle(name: String, theme: String, category: PostCategory) -> [AppNotice]
    func leaveCircle(_ circolo: Circolo)
    func retakeWord(in circolo: Circolo) -> [AppNotice]
    func accept(_ request: JoinRequest) -> [AppNotice]
    func decline(_ request: JoinRequest)

    /// Rivaluta la brace di tutti i circoli abitati (avvio, foreground, debug).
    func evaluateEmbers(now: Date) -> [AppNotice]
    /// Solo DEBUG: sposta indietro le date di attività per testare la meccanica.
    func simulateSilence(days: Int) -> [AppNotice]

    // Backend
    /// Riversa il mondo del server nello store locale (v. SyncApply).
    func applySync(_ payload: SyncPayload)

    // Profilo
    func resetAllData()

    #if DEBUG
    /// Solo sviluppo: popola il mondo demo per esercitare le meccaniche.
    func seedDemoData()
    #endif
}

// MARK: - LocalDataService

/// Implementazione locale su SwiftData del backend simulato.
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

    func friendCount() -> Int {
        (try? context.fetchCount(FetchDescriptor<Friendship>())) ?? 0
    }

    func updateName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let me = me() else { return }
        me.name = trimmed
        save()
    }

    func isFriend(_ person: Person) -> Bool {
        let friendships = (try? context.fetch(FetchDescriptor<Friendship>())) ?? []
        return friendships.contains { $0.person === person }
    }

    func pendingInvitee() -> Person? {
        var d = FetchDescriptor<Person>(predicate: #Predicate { $0.hasPendingInvite })
        d.fetchLimit = 1
        return (try? context.fetch(d))?.first
    }

    func myMemberships() -> [Membership] {
        let d = FetchDescriptor<Membership>(predicate: #Predicate { $0.person?.isMe == true })
        return (try? context.fetch(d)) ?? []
    }

    func membership(of circolo: Circolo) -> Membership? {
        myMemberships().first { $0.circolo === circolo }
    }

    private func memberships(of person: Person) -> [Membership] {
        let all = (try? context.fetch(FetchDescriptor<Membership>())) ?? []
        return all.filter { $0.person === person }
    }

    // MARK: Punteggio (unico punto di mutazione)

    /// Applica un'azione al punteggio di una persona e registra l'evento.
    private func applyScore(_ action: ParticipationAction, to person: Person, in circolo: Circolo? = nil) {
        person.score = engine.apply(action, to: person.score)
        context.insert(ParticipationEvent(person: person,
                                          circolo: circolo,
                                          action: action,
                                          points: engine.points(for: action)))
    }

    /// Registra attività nel circolo: azzera il silenzio e il flag di penalità.
    private func touchActivity(_ membership: Membership, at date: Date = .now) {
        membership.lastActivity = date
        membership.silencePenaltyApplied = false
    }

    // MARK: Tavola

    func invite(_ person: Person) -> InviteOutcome {
        // Già a tavola? Nessun doppione (doppio tap, richieste duplicate).
        guard !isFriend(person) else { return .seated }
        if engine.canSeatNewFriend(currentFriendCount: friendCount()) {
            seat(person)
            return .seated
        } else {
            // Un solo invito in sospeso alla volta: l'ultimo vince.
            pendingInvitee()?.hasPendingInvite = false
            person.hasPendingInvite = true
            save()
            return .tableFull
        }
    }

    func freeChair(_ friendship: Friendship) -> [AppNotice] {
        var notices: [AppNotice] = []
        // Chi si alza non sparisce dal mondo: torna tra le persone invitabili.
        friendship.person?.isCandidate = true
        context.delete(friendship)
        save()
        // Auto-seduta: se c'è un invito in sospeso e ora c'è una sedia libera.
        if let pending = pendingInvitee(),
           engine.shouldAutoSeat(hasPendingInvite: true, currentFriendCount: friendCount()) {
            seat(pending)
            notices.append(AppNotice(message: String(format: String(localized: "toast.seated", bundle: L10n.bundle), pending.name)))
        }
        return notices
    }

    func cancelPendingInvite() {
        pendingInvitee()?.hasPendingInvite = false
        save()
    }

    private func seat(_ person: Person) {
        person.hasPendingInvite = false
        person.isCandidate = false
        context.insert(Friendship(person: person))
        save()
    }

    // MARK: Salotto

    func publish(text: String, category: PostCategory, in circolo: Circolo?) -> [AppNotice] {
        guard let me = me() else { return [] }
        // Destinazione stantia (es. espulsi mentre l'app era in background):
        // il post va alla tavola, mai in un circolo che non si abita più.
        let target = circolo.flatMap { membership(of: $0) != nil ? $0 : nil }
        var notices: [AppNotice] = []
        let post = Post(author: me, circolo: target, category: category, text: text)
        context.insert(post)
        applyScore(.pubblicazione, to: me, in: target)
        // Pubblicare in un circolo è partecipazione attiva: azzera il silenzio.
        if let target, let membership = membership(of: target) {
            touchActivity(membership)
            notices.append(braceNotice(for: target))
        }
        save()
        return notices
    }

    func toggleNutre(on post: Post) {
        // Toggle senza doppio conteggio: il mio Nutre è un flag, non un incremento cieco.
        post.nutritoDaMe.toggle()
        save()
    }

    func addComment(to post: Post, text: String) -> [AppNotice] {
        guard let me = me() else { return [] }
        var notices: [AppNotice] = []
        let comment = Comment(post: post, author: me, text: text)
        context.insert(comment)
        applyScore(.commento, to: me, in: post.circolo)
        // Commentare un post di circolo azzera il silenzio in QUEL circolo.
        if let circolo = post.circolo, let membership = membership(of: circolo) {
            touchActivity(membership)
            notices.append(braceNotice(for: circolo))
        }
        save()
        return notices
    }

    private func braceNotice(for circolo: Circolo) -> AppNotice {
        AppNotice(message: String(format: String(localized: "toast.brace.viva", bundle: L10n.bundle),
                                  circolo.displayName))
    }

    // MARK: Circoli

    func joinCircle(_ circolo: Circolo) -> Bool {
        guard let me = me(),
              engine.canJoinCircle(currentCircleCount: myMemberships().count),
              membership(of: circolo) == nil else { return false }
        context.insert(Membership(person: me, circolo: circolo))
        circolo.memberCount += 1
        save()
        return true
    }

    func leaveCircle(_ circolo: Circolo) {
        guard let membership = membership(of: circolo) else { return }
        context.delete(membership)
        circolo.memberCount = max(0, circolo.memberCount - 1)
        // Uscita volontaria: nessuna penalità (DECISIONI.md #6).
        save()
    }

    func retakeWord(in circolo: Circolo) -> [AppNotice] {
        guard let me = me(), let membership = membership(of: circolo) else { return [] }
        touchActivity(membership)
        applyScore(.ripresaParola, to: me, in: circolo)
        save()
        return [braceNotice(for: circolo)]
    }

    func accept(_ request: JoinRequest) -> [AppNotice] {
        guard let person = request.person, let circolo = request.circolo else { return [] }
        // Già membro? La richiesta è solo da archiviare.
        guard !memberships(of: person).contains(where: { $0.circolo === circolo }) else {
            context.delete(request)
            save()
            return []
        }
        // Anche chi chiede di entrare abita al massimo 5 circoli.
        guard engine.canAcceptJoinRequest(requesterCircleCount: memberships(of: person).count) else {
            return []
        }
        context.insert(Membership(person: person, circolo: circolo))
        circolo.memberCount += 1
        context.delete(request)
        save()
        return [AppNotice(message: String(format: String(localized: "toast.accolto", bundle: L10n.bundle),
                                          person.name, circolo.displayName))]
    }

    func decline(_ request: JoinRequest) {
        context.delete(request)
        save()
    }

    // MARK: La regola della brace (valutazione temporale)

    func evaluateEmbers(now: Date = .now) -> [AppNotice] {
        guard let me = me() else { return [] }
        var notices: [AppNotice] = []
        for membership in myMemberships() {
            guard let circolo = membership.circolo else { continue }
            // La brace ha senso solo in compagnia: da soli resta in attesa.
            guard circolo.memberCount >= engine.rules.emberMinimumMembers else { continue }
            let evaluation = engine.evaluateEmber(lastActivity: membership.lastActivity,
                                                  now: now,
                                                  penaltyAlreadyApplied: membership.silencePenaltyApplied)
            if evaluation.applySilencePenalty {
                membership.silencePenaltyApplied = true
                applyScore(.silenzio, to: me, in: circolo)
                // Il valore della penalità viene da ProductRules, mai hardcoded nel copy.
                notices.append(AppNotice(message: String(format: String(localized: "toast.penalita", bundle: L10n.bundle),
                                                         circolo.displayName,
                                                         engine.points(for: .silenzio)),
                                         sticky: true))
            }
            // L'animatore non viene espulso dal proprio circolo: il luogo è suo.
            if evaluation.expel && !circolo.animatedByMe {
                let days = engine.daysOfSilence(since: membership.lastActivity, now: now)
                context.delete(membership)
                circolo.memberCount = max(0, circolo.memberCount - 1)
                applyScore(.espulsione, to: me, in: circolo)
                notices.append(AppNotice(message: String(format: String(localized: "toast.espulsione", bundle: L10n.bundle),
                                                         circolo.displayName, days),
                                         sticky: true))
            }
        }
        save()
        return notices
    }

    func simulateSilence(days: Int) -> [AppNotice] {
        // Sposta indietro le date reali: la meccanica resta identica alla produzione.
        for membership in myMemberships() {
            membership.lastActivity = membership.lastActivity.addingTimeInterval(-Double(days) * 86_400)
        }
        save()
        return evaluateEmbers(now: .now)
    }

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

    func createCircle(name: String, theme: String, category: PostCategory) -> [AppNotice] {
        guard let me = me(),
              engine.canJoinCircle(currentCircleCount: myMemberships().count) else { return [] }
        // Aperto: i circoli fondati dagli utenti si trovano con la ricerca.
        let circolo = Circolo(nameKey: name, themeKey: theme, category: category,
                              isOpen: true, animatedByMe: true,
                              memberCount: 1, isSeedContent: false)
        context.insert(circolo)
        context.insert(Membership(person: me, circolo: circolo))
        save()
        return [AppNotice(message: String(format: String(localized: "toast.circolo.creato", bundle: L10n.bundle), name))]
    }

    func resetAllData() {
        purgeEverything()
        UserDefaults.standard.set(false, forKey: seedFlagKey)
    }

    private func purgeEverything() {
        try? context.delete(model: ParticipationEvent.self)
        try? context.delete(model: JoinRequest.self)
        try? context.delete(model: Comment.self)
        try? context.delete(model: Post.self)
        try? context.delete(model: Membership.self)
        try? context.delete(model: Friendship.self)
        try? context.delete(model: Circolo.self)
        try? context.delete(model: Person.self)
        save()
    }

    private func save() {
        try? context.save()
    }

    // MARK: Seed demo (SOLO build di sviluppo)

    #if DEBUG
    /// Popola il mondo demo. MAI chiamato in produzione: serve in sviluppo
    /// per esercitare le meccaniche senza aspettare persone vere.
    func seedDemoData() {
        guard me() == nil else { return }

        let now = Date.now
        func hoursAgo(_ h: Double) -> Date { now.addingTimeInterval(-h * 3600) }
        func daysAgo(_ d: Double) -> Date { now.addingTimeInterval(-d * 86_400) }

        // — Io
        let me = Person(name: "Giampiero",
                        bioKey: "seed.me.bio",
                        interestKeys: ["interest.classici", "interest.poesia"],
                        score: 63, isMe: true)
        context.insert(me)

        // — Amici (9 sedie occupate)
        let friendSpecs: [(String, Int, [String])] = [
            ("Elena Marchetti", 88, ["interest.poesia", "interest.cinemadessai"]),
            ("Marco Bellandi",  76, ["interest.jazz", "interest.storia"]),
            ("Sofia Ricci",     91, ["interest.artecontemporanea", "interest.romanzo"]),
            ("Andrea Fontana",  62, ["interest.teatro", "interest.filosofia"]),
            ("Giulia Serra",    55, ["interest.fotografia", "interest.poesia"]),
            ("Tommaso Vitale",  49, ["interest.musicaclassica", "interest.cinema"]),
            ("Chiara Leone",    47, ["interest.saggistica", "interest.artecontemporanea"]),
            ("Davide Moro",     38, ["interest.cinema", "interest.jazz"]),
            ("Anna Bassi",      71, ["interest.romanzo", "interest.viaggio"])
        ]
        var friends: [Person] = []
        for (name, score, interests) in friendSpecs {
            let p = Person(name: name, interestKeys: interests, score: score)
            context.insert(p)
            context.insert(Friendship(person: p, since: daysAgo(Double.random(in: 30...300))))
            friends.append(p)
        }

        // — Candidati all'invito (5)
        let candidateSpecs: [(String, Int, [String])] = [
            ("Pietro Colombo", 71, ["interest.fotografia", "interest.jazz"]),
            ("Laura Ferri",    83, ["interest.teatro", "interest.poesia"]),
            ("Stefano Galli",  42, ["interest.cinema", "interest.storia"]),
            ("Marta Rinaldi",  58, ["interest.artecontemporanea", "interest.viaggio"]),
            ("Nicola Sartori", 35, ["interest.musicaclassica", "interest.filosofia"])
        ]
        for (name, score, interests) in candidateSpecs {
            context.insert(Person(name: name, interestKeys: interests, score: score, isCandidate: true))
        }

        // — Circoli (7: 2 abitati + 1 animato da me, 4 a catalogo)
        let novecento = Circolo(nameKey: "seed.circle.novecento.name",
                                themeKey: "seed.circle.novecento.theme",
                                category: .libro, isOpen: false, memberCount: 14, isSeedContent: true)
        let cineforum = Circolo(nameKey: "seed.circle.cineforum.name",
                                themeKey: "seed.circle.cineforum.theme",
                                category: .film, isOpen: false, memberCount: 9, isSeedContent: true)
        let salaAscolto = Circolo(nameKey: "seed.circle.salaascolto.name",
                                  themeKey: "seed.circle.salaascolto.theme",
                                  category: .musica, isOpen: false,
                                  animatedByMe: true, memberCount: 7, isSeedContent: true)
        let sguardi = Circolo(nameKey: "seed.circle.sguardi.name",
                              themeKey: "seed.circle.sguardi.theme",
                              category: .arte, memberCount: 21, isSeedContent: true)
        let palcoscenico = Circolo(nameKey: "seed.circle.palcoscenico.name",
                                   themeKey: "seed.circle.palcoscenico.theme",
                                   category: .teatro, memberCount: 12, isSeedContent: true)
        let ideeTramonto = Circolo(nameKey: "seed.circle.ideetramonto.name",
                                   themeKey: "seed.circle.ideetramonto.theme",
                                   category: .idea, memberCount: 17, isSeedContent: true)
        let taccuino = Circolo(nameKey: "seed.circle.taccuino.name",
                               themeKey: "seed.circle.taccuino.theme",
                               category: .libro, memberCount: 11, isSeedContent: true)
        [novecento, cineforum, salaAscolto, sguardi, palcoscenico, ideeTramonto, taccuino]
            .forEach { context.insert($0) }

        // — Le mie membership: una brace che si affievolisce, due vive.
        context.insert(Membership(person: me, circolo: novecento,
                                  joinedAt: daysAgo(120), lastActivity: daysAgo(3)))
        context.insert(Membership(person: me, circolo: cineforum,
                                  joinedAt: daysAgo(80), lastActivity: daysAgo(1.2)))
        context.insert(Membership(person: me, circolo: salaAscolto,
                                  joinedAt: daysAgo(200), lastActivity: hoursAgo(10)))

        // — Richieste d'ingresso al circolo che animo (punteggi contrastanti).
        let bianca = Person(name: "Bianca Romano", score: 82,
                            isCandidate: false)
        bianca.interestKeys = ["interest.jazz", "interest.minimalismo"]
        let otto = Person(name: "Otto Krause", score: 31)
        otto.interestKeys = ["interest.cinema", "interest.saggistica"]
        context.insert(bianca)
        context.insert(otto)
        context.insert(JoinRequest(circolo: salaAscolto, person: bianca, createdAt: hoursAgo(20)))
        context.insert(JoinRequest(circolo: salaAscolto, person: otto, createdAt: hoursAgo(44)))

        // — Post e commenti demo (contenuti = chiavi di localizzazione).
        let p1 = Post(author: friends[0], circolo: novecento, category: .libro,
                      text: "seed.post.1", isSeedContent: true,
                      createdAt: hoursAgo(2), nutreCount: 4)
        let p2 = Post(author: friends[1], circolo: cineforum, category: .film,
                      text: "seed.post.2", isSeedContent: true,
                      createdAt: hoursAgo(5), nutreCount: 2)
        let p3 = Post(author: friends[2], circolo: nil, category: .arte,
                      text: "seed.post.3", isSeedContent: true,
                      createdAt: hoursAgo(8), nutreCount: 6)
        let p4 = Post(author: friends[8], circolo: salaAscolto, category: .musica,
                      text: "seed.post.4", isSeedContent: true,
                      createdAt: hoursAgo(26), nutreCount: 3)
        let p5 = Post(author: friends[3], circolo: nil, category: .idea,
                      text: "seed.post.5", isSeedContent: true,
                      createdAt: hoursAgo(30), nutreCount: 1)
        [p1, p2, p3, p4, p5].forEach { context.insert($0) }

        let commentSpecs: [(Post, Person, String, Double)] = [
            (p1, friends[1], "seed.comment.1", 1),
            (p2, friends[2], "seed.comment.2", 3),
            (p3, friends[8], "seed.comment.3", 6),
            (p3, friends[3], "seed.comment.4", 7),
            (p4, friends[4], "seed.comment.5", 20),
            (p5, friends[5], "seed.comment.6", 22)
        ]
        for (post, author, key, hours) in commentSpecs {
            context.insert(Comment(post: post, author: author, text: key,
                                   isSeedContent: true, createdAt: hoursAgo(hours)))
        }

        // — Un po' di storia del punteggio (arriva a 63 da 50: +8 post, +5 commenti).
        let history: [(ParticipationAction, Double)] = [
            (.pubblicazione, 21), (.pubblicazione, 17), (.pubblicazione, 12), (.pubblicazione, 6),
            (.commento, 19), (.commento, 15), (.commento, 9), (.commento, 4), (.commento, 2)
        ]
        for (action, day) in history {
            context.insert(ParticipationEvent(person: me, action: action,
                                              points: engine.points(for: action),
                                              date: daysAgo(day)))
        }

        save()
    }
    #endif
}
