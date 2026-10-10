//
//  AppStore.swift
//  Sobremesa
//
//  Lo store osservabile (MVVM, @Observable): le view leggono con @Query
//  e mutano SOLO attraverso questi metodi. Qui vivono anche i toast
//  (le notifiche in-app), la lingua e la sincronizzazione col server.
//

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppStore {

    /// Le operazioni locali (SwiftData): mai le view direttamente sui modelli.
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

    /// Le tre stanze; serve a saltare di stanza dai richiami del Salotto.
    enum Stanza: Hashable { case salotto, tavoli, tu }
    var stanzaCorrente: Stanza = .salotto
    /// Il percorso di navigazione del Salotto (le stanze aperte).
    var salottoPath: [Tavolo] = []

    /// Apre la stanza di un tavolo dal Salotto (dopo fondazione o ingresso).
    func open(_ tavolo: Tavolo) {
        stanzaCorrente = .salotto
        salottoPath = [tavolo]
    }

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

    /// Ricerca corrente nel catalogo dei tavoli aperti.
    var catalogQuery = ""

    func syncNow(query: String? = nil) {
        if let query { catalogQuery = query }
        Task { await performSync() }
    }

    /// L'ultimo errore di sincronizzazione (nil = l'ultimo sync è andato bene).
    var lastSyncError: String?

    private func performSync() async {
        guard SessionStore.token != nil else { return }
        do {
            let nutrePrima = data.myReceivedNutre()
            let payload = try await api.sync(catalogQuery: catalogQuery)
            data.applySync(payload)
            // Una stanza aperta su un tavolo che il sync ha tolto (fantasma) si chiude.
            salottoPath.removeAll { $0.modelContext == nil || $0.isDeleted }
            if let fromServer = payload.blocked { blocked = fromServer }
            refreshEmberReminders()
            // Il gesto più caldo dell'app non deve restare invisibile:
            // se le mie parole hanno nutrito qualcuno, lo dico (aggregato).
            let nutreDopo = data.myReceivedNutre()
            if nutreDopo > nutrePrima {
                show(message: String.localizedStringWithFormat(
                    String(localized: "toast.nutre.ricevuti", bundle: L10n.bundle),
                    nutreDopo - nutrePrima))
            }
            lastSyncError = nil
        } catch {
            // Offline: si resta sulla fotografia locale, senza drammi —
            // ma l'errore resta annotato per la diagnostica.
            lastSyncError = String(describing: error).prefix(160).description
        }
    }

    /// Mutazione remota: prova, riallinea; se la rete manca, lo dice.
    /// Se il server RIFIUTA (409 e simili), l'effetto ottimistico locale
    /// va fatto rientrare: si risincronizza comunque.
    private func remote(_ operation: @escaping () async throws -> Void) {
        Task {
            do {
                try await operation()
                await performSync()
            } catch APIError.notAuthenticated {
                // Nessuna sessione: si resta in locale.
            } catch APIError.http {
                show(message: String(localized: "toast.rifiutato", bundle: L10n.bundle))
                await performSync()
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
        let memberships = data.myMemberships().compactMap { membership -> (String, Date, Bool, Bool)? in
            guard let tavolo = membership.tavolo else { return nil }
            return (tavolo.name,
                    membership.lastActivity,
                    tavolo.memberCount < rules.emberMinimumMembers,
                    tavolo.animatedByMe)
        }
        notifications.reschedule(memberships: memberships)
        refreshRitual()
    }

    // MARK: Derivati

    var me: Person? { data.me() }
    var myMemberships: [Membership] { data.myMemberships() }

    func membership(of tavolo: Tavolo) -> Membership? { data.membership(of: tavolo) }

    // MARK: Tavoli

    /// Fonda un nuovo tavolo: chi lo fonda ne è l'animatore.
    func createTable(name: String, theme: String, category: PostCategory, isOpen: Bool = true) {
        show(notices: data.createTable(name: name, theme: theme, category: category, isOpen: isOpen))
        notifications.requestAuthorizationIfNeeded()
        refreshEmberReminders()
        // Appena apparecchiato, ci si siede: la stanza nuova si apre da sola.
        let nuovo = data.myMemberships().last?.tavolo
        if let nuovo { open(nuovo) }
        // Se il server rifiuta la fondazione, il tavolo locale NON deve restare
        // come fantasma (prima restava per sempre, e l'invito non poteva funzionare).
        Task {
            do {
                try await api.createTable(name: name, theme: theme,
                                          category: category.rawValue, isOpen: isOpen)
                data.tableCreationFinished(name: name)
                await performSync()
            } catch APIError.notAuthenticated {
                data.tableCreationFinished(name: name)
            } catch {
                data.tableCreationFinished(name: name)
                let refused: Bool
                if let apiError = error as? APIError, case .http = apiError { refused = true } else { refused = false }
                show(message: refused
                     ? String(localized: "toast.rifiutato", bundle: L10n.bundle)
                     : String(localized: "toast.offline", bundle: L10n.bundle))
                if let nuovo, nuovo.serverID == nil {
                    salottoPath.removeAll { $0 === nuovo }
                    data.discardUnsyncedTable(nuovo)
                }
                await performSync()
            }
        }
    }

    /// Siediti a un tavolo aperto (dal catalogo).
    @discardableResult
    func joinTable(_ tavolo: Tavolo) -> Bool {
        let joined = data.joinTable(tavolo)
        if joined {
            notifications.requestAuthorizationIfNeeded()
            refreshEmberReminders()
            show(message: String(format: String(localized: "toast.seduto", bundle: L10n.bundle), tavolo.name))
            open(tavolo)
            if let id = tavolo.serverID {
                remote { try await self.api.tableAction("join", tableID: id) }
            }
        }
        return joined
    }

    /// Chiedi di sederti a un tavolo chiuso.
    func requestSeat(at tavolo: Tavolo) {
        guard let id = tavolo.serverID else { return }
        show(message: String(localized: "toast.richiesta.inviata", bundle: L10n.bundle))
        remote { try await self.api.tableAction("join", tableID: id) }
    }

    /// Alzati da un tavolo (l'animatore, alzandosi, lo chiude).
    func leaveTable(_ tavolo: Tavolo) {
        let serverID = tavolo.serverID
        data.leaveTable(tavolo)
        refreshEmberReminders()
        if let serverID {
            remote { try await self.api.tableAction("leave", tableID: serverID) }
        }
    }

    /// "Riprendi la parola": ravviva la brace senza scrivere.
    func retakeWord(at tavolo: Tavolo) {
        show(notices: data.retakeWord(at: tavolo))
        refreshEmberReminders()
        if let id = tavolo.serverID {
            remote { try await self.api.tableAction("retake", tableID: id) }
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

    // MARK: Conversazione

    func sendMessage(_ text: String, at tavolo: Tavolo) {
        show(notices: data.sendMessage(text, at: tavolo))
        refreshEmberReminders()
        if let id = tavolo.serverID {
            remote { try await self.api.sendMessage(text, tableID: id) }
        }
    }

    func toggleNutre(on messaggio: Messaggio) {
        data.toggleNutre(on: messaggio)
        if let id = messaggio.serverID {
            remote { try await self.api.toggleNutre(messageID: id) }
        }
    }

    // MARK: Sicurezza dei tavoli (Apple Guideline 1.2)

    /// Le persone che ho bloccato (fotografia del server a ogni sync).
    var blocked: [RemoteBlocked] = []

    func isBlocked(_ person: Person) -> Bool {
        guard let id = person.serverID else { return false }
        return blocked.contains { $0.id == id }
    }

    /// Segnala un intervento: sparisce subito dalla mia stanza; il server
    /// lo nasconde a tutti se lo segnalano più persone, e lo mette in coda
    /// per la revisione.
    func report(_ messaggio: Messaggio, reason: ReportReason) {
        guard let id = messaggio.serverID, messaggio.author?.isMe != true else { return }
        data.removeMessage(messaggio)
        show(message: String(localized: "toast.segnalato", bundle: L10n.bundle))
        remote { try await self.api.report(messageID: id, reason: reason) }
    }

    /// Blocca una persona: i suoi interventi spariscono subito, e non potrà
    /// più chiedere di sedersi ai tavoli che animo.
    func block(_ person: Person) {
        guard let id = person.serverID, !person.isMe else { return }
        if !blocked.contains(where: { $0.id == id }) {
            blocked.append(RemoteBlocked(id: id, name: person.name))
        }
        data.removeMessages(fromAuthorServerID: id)
        show(message: String(format: String(localized: "toast.bloccato", bundle: L10n.bundle), person.name))
        remote { try await self.api.setBlocked(true, userID: id) }
    }

    /// Sblocca: i suoi interventi tornano col prossimo sync.
    func unblock(_ person: RemoteBlocked) {
        blocked.removeAll { $0.id == person.id }
        show(message: String(format: String(localized: "toast.sbloccato", bundle: L10n.bundle), person.name))
        remote { try await self.api.setBlocked(false, userID: person.id) }
    }

    /// La stanza è stata letta fino ad adesso (alimenta i "nuovi interventi").
    func markRead(_ tavolo: Tavolo) {
        data.markRead(tavolo)
    }

    // MARK: Il rituale della sera (notifica locale opt-in, Tu → Il tuo momento)

    var ritualEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "sobremesa.rituale.on") }
        set {
            UserDefaults.standard.set(newValue, forKey: "sobremesa.rituale.on")
            if newValue { notifications.requestAuthorizationIfNeeded() }
            refreshRitual()
        }
    }

    /// Minuti dalla mezzanotte (default 21:30): un campanile, non una slot.
    var ritualMinutes: Int {
        get {
            let saved = UserDefaults.standard.integer(forKey: "sobremesa.rituale.minuti")
            return saved == 0 ? 21 * 60 + 30 : saved
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "sobremesa.rituale.minuti")
            refreshRitual()
        }
    }

    private func refreshRitual() {
        notifications.scheduleRitual(enabled: ritualEnabled && !myMemberships.isEmpty,
                                     minutesFromMidnight: ritualMinutes)
    }

    // MARK: Inviti al tavolo

    /// Genera un codice d'invito per un tavolo (share sheet).
    /// Robusto: un tavolo appena fondato non ha ancora l'id del server (la
    /// fondazione è ottimistica) e la sedia dell'animatore può non essere
    /// ancora registrata. Si risincronizza e si riprova qualche volta,
    /// invece di arrendersi al primo colpo (era il bug della rotellina).
    func createInviteCode(for tavolo: Tavolo) async -> String? {
        await inviteCode(for: tavolo).code
    }

    /// Come sopra, ma dice anche PERCHÉ non è arrivato (il foglio lo mostra
    /// in piccolo: serve a capire subito dove si rompe, senza indovinare).
    func inviteCode(for tavolo: Tavolo) async -> (code: String?, detail: String?) {
        guard SessionStore.token != nil else { return (nil, "sessione assente: l'app non ha ancora un accesso al server") }
        var detail: String?
        for attempt in 0..<4 {
            if tavolo.serverID == nil { await performSync() }
            if tavolo.modelContext == nil || tavolo.isDeleted {
                return (nil, "il tavolo non esiste sul server: rifondalo")
            }
            if let id = tavolo.serverID {
                do {
                    return (try await api.createInvite(tableID: id), nil)
                } catch APIError.http(let status, let body) {
                    detail = "HTTP \(status) · \(body.prefix(120))"
                    // 4xx: il server ha risposto e ha detto no; riprovare non serve.
                    if (400..<500).contains(status) { return (nil, detail) }
                } catch APIError.notAuthenticated {
                    return (nil, "sessione assente")
                } catch {
                    detail = "rete · \(error.localizedDescription)"
                }
            } else {
                detail = lastSyncError.map { "sync · \($0)" } ?? "tavolo non ancora sul server"
            }
            try? await Task.sleep(for: .seconds(attempt == 0 ? 1 : 2))
            await performSync()
        }
        return (nil, detail)
    }

    /// Riscatta un codice ricevuto: ci si siede a quel tavolo.
    func redeemInvite(code: String) {
        // Il codice si mostra "Q7M4-K2LP": trattini e spazi non contano.
        let clean = code.uppercased().filter { $0.isLetter || $0.isNumber }
        guard !clean.isEmpty else { return }
        Task {
            do {
                let tableID = try await api.redeemInvite(code: clean)
                show(message: String(localized: "toast.invito.seduti", bundle: L10n.bundle))
                await performSync()
                // Seduti: la stanza si apre da sola.
                if let tableID,
                   let tavolo = data.myMemberships().compactMap(\.tavolo).first(where: { $0.serverID == tableID }) {
                    open(tavolo)
                }
            } catch {
                show(message: String(localized: "toast.invito.errore", bundle: L10n.bundle))
            }
        }
    }

    #if DEBUG
    /// Solo build DEBUG: simula N giorni di silenzio spostando indietro le date reali.
    func simulateSilence(days: Int) {
        show(notices: data.simulateSilence(days: days))
        refreshEmberReminders()
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
        blocked = []
        data.resetAllData()
        notifications.reschedule(memberships: [])
        toastTask?.cancel()
        toast = nil
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

// MARK: - Risoluzione delle chiavi di localizzazione

extension String {
    /// Risolve la stringa come chiave del String Catalog (bundle della lingua scelta).
    var loc: String {
        String(localized: String.LocalizationValue(self), bundle: L10n.bundle)
    }
}
