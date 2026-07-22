//
//  SobremesaEngine.swift
//  Sobremesa
//
//  Il cuore puro delle regole di prodotto: tavola, circoli, brace, punteggio.
//  Zero UI, zero persistenza, zero singleton: solo funzioni deterministiche
//  su tipi valore, testabili al 100% (anche su Linux).
//

import Foundation

// MARK: - Azioni di partecipazione

/// Le azioni che muovono il punteggio di partecipazione.
enum ParticipationAction: String, Codable, CaseIterable, Sendable {
    case pubblicazione      // +2
    case commento           // +1
    case ripresaParola      // +1 ("Riprendi la parola")
    case silenzio           // −2 (per periodo di silenzio per circolo)
    case espulsione         // −5
}

// MARK: - Fasce del punteggio

/// Le tre fasce del punteggio di partecipazione.
enum ScoreBand: String, Sendable, CaseIterable {
    case voceViva           // ≥ 75 — verde
    case presenzaDiscreta   // ≥ 45 — ottone
    case ombraAlTavolo      // < 45 — rosso
}

// MARK: - Stato della brace

/// Lo stato della brace di una membership in un circolo,
/// in funzione dei giorni di silenzio.
enum EmberState: Equatable, Sendable {
    case viva
    case affievolita(giorniDiSilenzio: Int)   // ≥ emberDimAfterDays
    case avviso(giorniDiSilenzio: Int)        // ≥ emberWarningAfterDays
    case espulsione(giorniDiSilenzio: Int)    // ≥ emberExpulsionAfterDays
}

/// Esito della valutazione periodica della brace per una membership.
struct EmberEvaluation: Equatable, Sendable {
    let state: EmberState
    /// Va applicata ORA la penalità −2 per questo periodo di silenzio?
    let applySilencePenalty: Bool
    /// Il posto va liberato (espulsione automatica)?
    let expel: Bool
}

// MARK: - Engine

/// Motore delle regole di Sobremesa. Stateless: riceve i dati, restituisce decisioni.
struct SobremesaEngine: Sendable {

    let rules: ProductRules

    init(rules: ProductRules = .standard) {
        self.rules = rules
    }

    // MARK: Tavola (12 sedie)

    /// C'è una sedia libera per un nuovo amico?
    func canSeatNewFriend(currentFriendCount: Int) -> Bool {
        currentFriendCount < rules.maxFriends
    }

    /// Numero di sedie libere.
    func freeChairs(currentFriendCount: Int) -> Int {
        max(0, rules.maxFriends - currentFriendCount)
    }

    /// Con un invito in sospeso e una sedia appena liberata,
    /// l'invitato si siede automaticamente?
    func shouldAutoSeat(hasPendingInvite: Bool, currentFriendCount: Int) -> Bool {
        hasPendingInvite && canSeatNewFriend(currentFriendCount: currentFriendCount)
    }

    // MARK: Circoli (5 slot)

    /// C'è uno slot libero per abitare un altro circolo?
    func canJoinCircle(currentCircleCount: Int) -> Bool {
        currentCircleCount < rules.maxCircles
    }

    /// L'animatore può accogliere una richiesta? Il vincolo è del richiedente:
    /// anche lui abita al massimo `maxCircles` circoli.
    func canAcceptJoinRequest(requesterCircleCount: Int) -> Bool {
        canJoinCircle(currentCircleCount: requesterCircleCount)
    }

    // MARK: La regola della brace

    /// Giorni interi di silenzio trascorsi dall'ultima attività.
    /// floor(secondi / 86_400) — v. DECISIONI.md #4.
    func daysOfSilence(since lastActivity: Date, now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(lastActivity) / 86_400))
    }

    /// Stato della brace dati gli estremi temporali.
    func emberState(lastActivity: Date, now: Date) -> EmberState {
        let days = daysOfSilence(since: lastActivity, now: now)
        if days >= rules.emberExpulsionAfterDays { return .espulsione(giorniDiSilenzio: days) }
        if days >= rules.emberWarningAfterDays   { return .avviso(giorniDiSilenzio: days) }
        if days >= rules.emberDimAfterDays       { return .affievolita(giorniDiSilenzio: days) }
        return .viva
    }

    /// Valutazione completa di una membership: stato, eventuale penalità
    /// (una sola per periodo di silenzio: `penaltyAlreadyApplied` la traccia),
    /// eventuale espulsione.
    func evaluateEmber(lastActivity: Date,
                       now: Date,
                       penaltyAlreadyApplied: Bool) -> EmberEvaluation {
        let state = emberState(lastActivity: lastActivity, now: now)
        switch state {
        case .viva, .affievolita:
            return EmberEvaluation(state: state, applySilencePenalty: false, expel: false)
        case .avviso:
            return EmberEvaluation(state: state,
                                   applySilencePenalty: !penaltyAlreadyApplied,
                                   expel: false)
        case .espulsione:
            // Alla soglia di espulsione conta l'espulsione (−5); se la penalità
            // del periodo non era ancora stata applicata (es. app mai aperta
            // tra il giorno 4 e il 7), si applica anche quella.
            return EmberEvaluation(state: state,
                                   applySilencePenalty: !penaltyAlreadyApplied,
                                   expel: true)
        }
    }

    // MARK: Punteggio di partecipazione

    /// Punti mossi da un'azione (dai pesi di ProductRules).
    func points(for action: ParticipationAction) -> Int {
        switch action {
        case .pubblicazione: return rules.pointsPost
        case .commento:      return rules.pointsComment
        case .ripresaParola: return rules.pointsRetake
        case .silenzio:      return rules.pointsSilencePenalty
        case .espulsione:    return rules.pointsExpulsionPenalty
        }
    }

    /// Clamp del punteggio nell'intervallo consentito.
    func clamp(_ score: Int) -> Int {
        min(rules.scoreMax, max(rules.scoreMin, score))
    }

    /// Applica un'azione a un punteggio, con clamp immediato (DECISIONI.md #3).
    func apply(_ action: ParticipationAction, to score: Int) -> Int {
        clamp(score + points(for: action))
    }

    /// Applica una sequenza di azioni, clamp dopo ogni passo.
    func score(from initial: Int, applying actions: [ParticipationAction]) -> Int {
        actions.reduce(clamp(initial)) { partial, action in
            apply(action, to: partial)
        }
    }

    /// Fascia di un punteggio.
    func band(for score: Int) -> ScoreBand {
        if score >= rules.bandVoceVivaThreshold { return .voceViva }
        if score >= rules.bandPresenzaDiscretaThreshold { return .presenzaDiscreta }
        return .ombraAlTavolo
    }
}
