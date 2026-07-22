//
//  AppStore.swift
//  Sobremesa
//
//  Lo store osservabile (MVVM, @Observable): le view leggono con @Query
//  e mutano SOLO attraverso questi metodi. Qui vivono anche i toast
//  (le notifiche in-app) e lo stato dell'invito in sospeso.
//

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppStore {

    /// Il backend (oggi locale, domani remoto): mai le view direttamente sui modelli.
    private let data: DataService
    /// Richiami locali della brace (giorno 4 e giorno 7).
    private let notifications: NotificationScheduler
    /// Il backend vero (Vercel): il server decide, il locale fotografa.
    private let api = APIClient()
    /// L'accesso è fallito (rete o token): l'onboarding lo mostra inline.
    var authError = false

    /// Regole di prodotto correnti (unica fonte dei numeri di business).
    var rules: ProductRules { data.engine.rules }
    var engine: SobremesaEngine { data.engine }

    /// Toast corrente (notifica in-app).
    var toast: AppNotice?
    /// Persona con invito in sospeso (tavola piena): guida il pannello in Tavola.
    var pendingInvitee: Person?
    /// Serve l'onboarding (nessun profilo)? Deciso in bootstrap().
    var needsOnboarding = true

    /// La lingua dell'app: di serie quella del telefono, ma si sceglie
    /// da Tu → Lingua. Cambia subito, senza riavviare.
    var language: AppLanguage = .system {
        didSet {
            guard language != oldValue else { return }
            UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.storageKey)
            L10n.bundle = language.bundle
            // Anche ciò che il sistema disegna (bottone Apple, formati)
            // si adegua al prossimo avvio: qui prepariamo il terreno.
            if language == .system {
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            } else {
                UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
            }
            // Le notifiche già in coda parlano la vecchia lingua: si rifanno.
            refreshEmberReminders()
        }
    }

    /// Il Locale da iniettare nell'ambiente SwiftUI alla radice.
    var appLocale: Locale { language.locale }

    private var toastTask: Task<Void, Never>?

    init(data: DataService) {
        self.data = data
        self.notifications = NotificationScheduler(rules: data.engine.rules)
        // Deciso subito, prima del primo frame: chi ha già il profilo
        // non deve vedere nemmeno un lampo della schermata di accesso.
        self.needsOnboarding = !data.hasProfile()
        // La lingua scelta (se c'è) si applica prima del primo frame.
        self.language = AppLanguage.saved
        L10n.bundle = language.bundle
    }

    // MARK: Ciclo di vita

    func bootstrap() {
        needsOnboarding = !data.hasProfile()
        guard !needsOnboarding else { return }
        pendingInvitee = data.pendingInvitee()
        show(notices: data.evaluateEmbers(now: .now))
        refreshEmberReminders()
        syncNow()
    }

    /// Primo accesso: il server verifica il token di Apple, rilascia la
    /// sessione, e SOLO allora si apparecchia. Errori mostrati inline.
    func completeOnboarding(name: String, appleUserID: String?, identityToken: String?) {
        guard let identityToken else {
            authError = true
            return
        }
        authError = false
        Task {
            do {
                let auth = try await api.authApple(identityToken: identityToken, name: name)
                SessionStore.save(auth.token)
                let serverName = auth.user.name.trimmingCharacters(in: .whitespacesAndNewlines)
                data.createProfile(name: serverName.isEmpty || serverName == "…" ? name : serverName,
                                   appleUserID: appleUserID)
                withAnimation { needsOnboarding = !data.hasProfile() }
                await performSync()
            } catch {
                authError = true
            }
        }
    }

    /// Il nome è dell'utente: si può sempre correggere (Tu).
    func updateName(_ name: String) {
        data.updateName(name)
        remote { try await self.api.updateName(name) }
    }

    // MARK: Sincronizzazione col server

    /// Ricerca corrente nel catalogo dei circoli aperti.
    var catalogQuery = ""

    func syncNow(query: String? = nil) {
        if let query { catalogQuery = query }
        Task { await performSync() }
    }

    private func performSync() async {
        guard SessionStore.token != nil else { return }
        do {
            let payload = try await api.sync(catalogQuery: catalogQuery)
            data.applySync(payload)
            pendingInvitee = data.pendingInvitee()
            refreshEmberReminders()
        } catch {
            // Offline: si resta sulla fotografia locale, senza drammi.
        }
    }

    /// Mutazione remota: prova, riallinea; se la rete manca, lo dice.
    private func remote(_ operation: @escaping () async throws -> Void) {
        Task {
            do {
                try await operation()
                await performSync()
            } catch APIError.notAuthenticated {
                // Profili nati prima del backend: si continua in locale.
            } catch {
                show(message: String(localized: "toast.offline", bundle: L10n.bundle))
            }
        }
    }

    /// A ogni ritorno in foreground il tempo reale viene rivalutato.
    func appBecameActive() {
        guard !needsOnboarding else { return }
        show(notices: data.evaluateEmbers(now: .now))
        refreshEmberReminders()
        syncNow()
    }

    /// Riallinea i richiami locali della brace alle date reali.
    private func refreshEmberReminders() {
        let memberships = data.myMemberships().compactMap { membership -> (String, Date, Bool)? in
            guard let circolo = membership.circolo else { return nil }
            return (circolo.displayName,
                    membership.lastActivity,
                    circolo.memberCount < rules.emberMinimumMembers)
        }
        notifications.reschedule(memberships: memberships)
    }

    // MARK: Derivati

    var me: Person? { data.me() }
    var friendCount: Int { data.friendCount() }
    var myMemberships: [Membership] { data.myMemberships() }

    func membership(of circolo: Circolo) -> Membership? { data.membership(of: circolo) }

    /// Il post appartiene al mio feed? (solo amici e circoli abitati)
    func isInMyFeed(_ post: Post) -> Bool {
        if let circolo = post.circolo {
            return data.membership(of: circolo) != nil
        }
        return post.author?.isMe == true || post.author.map(data.isFriend) == true
    }

    // MARK: Salotto

    func publish(text: String, category: PostCategory, in circolo: Circolo?) {
        show(notices: data.publish(text: text, category: category, in: circolo))
        refreshEmberReminders()
        let circleID = circolo?.serverID
        remote { try await self.api.publish(text: text, category: category.rawValue, circleID: circleID) }
    }

    func toggleNutre(on post: Post) {
        data.toggleNutre(on: post)
        if let id = post.serverID {
            remote { try await self.api.react(postID: id, action: "nutre") }
        }
    }

    func addComment(to post: Post, text: String) {
        show(notices: data.addComment(to: post, text: text))
        refreshEmberReminders()
        if let id = post.serverID {
            remote { try await self.api.react(postID: id, action: "comment", text: text) }
        }
    }

    // MARK: Tavola

    func invite(_ person: Person) {
        switch data.invite(person) {
        case .seated:
            pendingInvitee = nil
            show(message: String(format: String(localized: "toast.seated", bundle: L10n.bundle), person.name))
        case .tableFull:
            pendingInvitee = person
        }
    }

    func freeChair(_ friendship: Friendship) {
        let serverID = friendship.person?.serverID
        show(notices: data.freeChair(friendship))
        pendingInvitee = data.pendingInvitee()
        if let serverID {
            remote { try await self.api.removeFriend(serverID: serverID) }
        }
    }

    // MARK: Inviti reali alla tavola

    /// Genera un codice d'invito da condividere (share sheet).
    func createInviteCode() async -> String? {
        try? await api.createInvite()
    }

    /// Riscatta un codice ricevuto: ci si siede alla stessa tavola.
    func redeemInvite(code: String) {
        let clean = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        Task {
            do {
                let result = try await api.redeemInvite(code: clean)
                if result.pending == true {
                    show(message: String(localized: "toast.invito.sospeso", bundle: L10n.bundle))
                } else {
                    show(message: String(localized: "toast.invito.seduti", bundle: L10n.bundle))
                }
                await performSync()
            } catch {
                show(message: String(localized: "toast.invito.errore", bundle: L10n.bundle))
            }
        }
    }

    func cancelPendingInvite() {
        data.cancelPendingInvite()
        pendingInvitee = nil
    }

    // MARK: Circoli

    @discardableResult
    func joinCircle(_ circolo: Circolo) -> Bool {
        let joined = data.joinCircle(circolo)
        if joined {
            notifications.requestAuthorizationIfNeeded()
            refreshEmberReminders()
            if let id = circolo.serverID {
                remote { try await self.api.circleAction("join", circleID: id) }
            }
        }
        return joined
    }

    /// Fonda un nuovo circolo: chi lo crea ne è l'animatore.
    func createCircle(name: String, theme: String, category: PostCategory) {
        show(notices: data.createCircle(name: name, theme: theme, category: category))
        notifications.requestAuthorizationIfNeeded()
        refreshEmberReminders()
        remote { try await self.api.createCircle(name: name, theme: theme,
                                                 category: category.rawValue, isOpen: true) }
    }

    func leaveCircle(_ circolo: Circolo) {
        let serverID = circolo.serverID
        data.leaveCircle(circolo)
        refreshEmberReminders()
        if let serverID {
            remote { try await self.api.circleAction("leave", circleID: serverID) }
        }
    }

    func retakeWord(in circolo: Circolo) {
        show(notices: data.retakeWord(in: circolo))
        refreshEmberReminders()
        if let id = circolo.serverID {
            remote { try await self.api.circleAction("retake", circleID: id) }
        }
    }

    func accept(_ request: JoinRequest) {
        let serverID = request.serverID
        show(notices: data.accept(request))
        if let serverID {
            remote { try await self.api.decideRequest(id: serverID, accept: true) }
        }
    }

    func decline(_ request: JoinRequest) {
        let serverID = request.serverID
        data.decline(request)
        if let serverID {
            remote { try await self.api.decideRequest(id: serverID, accept: false) }
        }
    }

    #if DEBUG
    /// Solo build DEBUG: simula N giorni di silenzio spostando indietro le date reali.
    func simulateSilence(days: Int) {
        show(notices: data.simulateSilence(days: days))
        refreshEmberReminders()
    }

    /// Solo build DEBUG: popola il mondo demo dall'onboarding, per sviluppo.
    func seedDemoWorld() {
        data.seedDemoData()
        needsOnboarding = !data.hasProfile()
        if !needsOnboarding {
            pendingInvitee = data.pendingInvitee()
            refreshEmberReminders()
        }
    }
    #endif

    // MARK: Profilo

    /// Cancella tutto (profilo compreso) e torna all'accesso.
    /// La cancellazione è anche remota: l'account sparisce dal server
    /// (Apple 5.1.1(v)), poi il dispositivo torna com'era il primo giorno.
    func resetAllData() {
        if let token = SessionStore.token {
            let client = api
            Task.detached { try? await client.deleteAccount(token: token) }
        }
        SessionStore.clear()
        data.resetAllData()
        notifications.reschedule(memberships: [])
        toastTask?.cancel()
        toast = nil
        pendingInvitee = nil
        withAnimation { needsOnboarding = true }
    }

    // MARK: Toast

    private func show(notices: [AppNotice]) {
        guard let first = notices.first else { return }
        // Se arrivano più notifiche insieme, le uniamo in un solo banner leggibile.
        let message = notices.count == 1
            ? first.message
            : notices.map(\.message).joined(separator: "\n")
        show(message: message, sticky: notices.contains(where: \.sticky))
    }

    private func show(message: String, sticky: Bool = false) {
        toastTask?.cancel()
        withAnimation { toast = AppNotice(message: message, sticky: sticky) }
        // La spec lo chiede esplicitamente: i toast sono annunciati a VoiceOver.
        AccessibilityNotification.Announcement(message).post()
        // Gli eventi gravi (penalità, espulsione) restano finché non li chiudi.
        guard !sticky else { return }
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            withAnimation { self?.toast = nil }
        }
    }

    /// Chiusura esplicita del banner (bottone ✕, sempre presente).
    func dismissToast() {
        toastTask?.cancel()
        withAnimation { toast = nil }
    }
}

// MARK: - Risoluzione delle chiavi di localizzazione dei contenuti seed

extension String {
    /// Risolve la stringa come chiave del String Catalog.
    /// Usata per i contenuti demo, che memorizzano chiavi e non testo.
    var loc: String {
        String(localized: String.LocalizationValue(self), bundle: L10n.bundle)
    }
}
