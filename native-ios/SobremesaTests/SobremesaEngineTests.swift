//
//  SobremesaEngineTests.swift
//  SobremesaTests
//
//  Unit test del motore puro delle regole di prodotto.
//  Tutti i numeri vengono da ProductRules: se un parametro cambia lì,
//  i test seguono automaticamente.
//

import XCTest
@testable import Sobremesa

final class SobremesaEngineTests: XCTestCase {

    private let rules = ProductRules.standard
    private var engine: SobremesaEngine { SobremesaEngine(rules: rules) }

    private func date(daysAgo days: Double, from now: Date) -> Date {
        now.addingTimeInterval(-days * 86_400)
    }

    // MARK: - Tavola: 13° invito bloccato e auto-seduta

    func testThirteenthInviteIsBlocked() {
        // A tavola piena (12/12) non ci si può sedere.
        XCTAssertFalse(engine.canSeatNewFriend(currentFriendCount: rules.maxFriends))
        // Con una sedia libera sì.
        XCTAssertTrue(engine.canSeatNewFriend(currentFriendCount: rules.maxFriends - 1))
        // Le sedie libere non vanno mai sotto zero.
        XCTAssertEqual(engine.freeChairs(currentFriendCount: rules.maxFriends), 0)
        XCTAssertEqual(engine.freeChairs(currentFriendCount: rules.maxFriends - 3), 3)
    }

    func testAutoSeatAfterChairIsFreed() {
        // Tavola piena + invito in sospeso: nessuna auto-seduta.
        XCTAssertFalse(engine.shouldAutoSeat(hasPendingInvite: true,
                                             currentFriendCount: rules.maxFriends))
        // Una sedia si libera (12 → 11): l'invitato in sospeso si siede da solo.
        XCTAssertTrue(engine.shouldAutoSeat(hasPendingInvite: true,
                                            currentFriendCount: rules.maxFriends - 1))
        // Senza invito in sospeso la sedia resta semplicemente libera.
        XCTAssertFalse(engine.shouldAutoSeat(hasPendingInvite: false,
                                             currentFriendCount: rules.maxFriends - 1))
    }

    // MARK: - Circoli: 6° circolo bloccato

    func testSixthCircleIsBlocked() {
        XCTAssertFalse(engine.canJoinCircle(currentCircleCount: rules.maxCircles))
        XCTAssertTrue(engine.canJoinCircle(currentCircleCount: rules.maxCircles - 1))
        // Lo stesso vincolo vale per chi chiede di entrare (lato animatore).
        XCTAssertFalse(engine.canAcceptJoinRequest(requesterCircleCount: rules.maxCircles))
        XCTAssertTrue(engine.canAcceptJoinRequest(requesterCircleCount: 0))
    }

    // MARK: - La brace: 0 → 2 → 4 → 7

    func testEmberProgression() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        // Giorno 0-1: viva.
        XCTAssertEqual(engine.emberState(lastActivity: date(daysAgo: 0, from: now), now: now), .viva)
        XCTAssertEqual(engine.emberState(lastActivity: date(daysAgo: 1.9, from: now), now: now), .viva)

        // Giorno 2-3: si affievolisce.
        XCTAssertEqual(engine.emberState(lastActivity: date(daysAgo: 2, from: now), now: now),
                       .affievolita(giorniDiSilenzio: 2))
        XCTAssertEqual(engine.emberState(lastActivity: date(daysAgo: 3.5, from: now), now: now),
                       .affievolita(giorniDiSilenzio: 3))

        // Giorno 4-6: avviso.
        XCTAssertEqual(engine.emberState(lastActivity: date(daysAgo: 4, from: now), now: now),
                       .avviso(giorniDiSilenzio: 4))
        XCTAssertEqual(engine.emberState(lastActivity: date(daysAgo: 6.9, from: now), now: now),
                       .avviso(giorniDiSilenzio: 6))

        // Giorno 7+: il posto si libera.
        XCTAssertEqual(engine.emberState(lastActivity: date(daysAgo: 7, from: now), now: now),
                       .espulsione(giorniDiSilenzio: 7))
    }

    func testEmberWarningAppliesPenaltyExactlyOncePerSilencePeriod() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let fiveDaysAgo = date(daysAgo: 5, from: now)

        // Prima valutazione in stato avviso: penalità da applicare.
        let first = engine.evaluateEmber(lastActivity: fiveDaysAgo, now: now,
                                         penaltyAlreadyApplied: false)
        XCTAssertEqual(first.state, .avviso(giorniDiSilenzio: 5))
        XCTAssertTrue(first.applySilencePenalty)
        XCTAssertFalse(first.expel)

        // Valutazioni successive nello stesso periodo: MAI due volte.
        let second = engine.evaluateEmber(lastActivity: fiveDaysAgo, now: now,
                                          penaltyAlreadyApplied: true)
        XCTAssertFalse(second.applySilencePenalty)
        XCTAssertFalse(second.expel)
    }

    func testEmberExpulsionAtSevenDays() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let eightDaysAgo = date(daysAgo: 8, from: now)

        let evaluation = engine.evaluateEmber(lastActivity: eightDaysAgo, now: now,
                                              penaltyAlreadyApplied: true)
        XCTAssertTrue(evaluation.expel)
        XCTAssertFalse(evaluation.applySilencePenalty) // già applicata nel periodo

        // App mai aperta tra giorno 4 e giorno 7: penalità arretrata + espulsione.
        let neverEvaluated = engine.evaluateEmber(lastActivity: eightDaysAgo, now: now,
                                                  penaltyAlreadyApplied: false)
        XCTAssertTrue(neverEvaluated.expel)
        XCTAssertTrue(neverEvaluated.applySilencePenalty)
    }

    func testCommentResetsSilence() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        // Ero in avviso (5 giorni di silenzio)…
        XCTAssertEqual(engine.emberState(lastActivity: date(daysAgo: 5, from: now), now: now),
                       .avviso(giorniDiSilenzio: 5))
        // …commento: l'ultima attività diventa ADESSO e la brace torna viva.
        // (Nel servizio: touchActivity → lastActivity = now, penaltyApplied = false.)
        XCTAssertEqual(engine.emberState(lastActivity: now, now: now), .viva)
        XCTAssertEqual(engine.daysOfSilence(since: now, now: now), 0)
    }

    // MARK: - Punteggio: aritmetica esatta e clamp 0–100

    func testScorePointsMatchProductRules() {
        XCTAssertEqual(engine.points(for: .pubblicazione), rules.pointsPost)      // +2
        XCTAssertEqual(engine.points(for: .commento), rules.pointsComment)        // +1
        XCTAssertEqual(engine.points(for: .ripresaParola), rules.pointsRetake)    // +1
        XCTAssertEqual(engine.points(for: .silenzio), rules.pointsSilencePenalty) // −2
        XCTAssertEqual(engine.points(for: .espulsione), rules.pointsExpulsionPenalty) // −5
    }

    func testScoreArithmetic() {
        var score = rules.initialScore // 50
        score = engine.apply(.pubblicazione, to: score) // 52
        XCTAssertEqual(score, 52)
        score = engine.apply(.commento, to: score)      // 53
        XCTAssertEqual(score, 53)
        score = engine.apply(.ripresaParola, to: score) // 54
        XCTAssertEqual(score, 54)
        score = engine.apply(.silenzio, to: score)      // 52
        XCTAssertEqual(score, 52)
        score = engine.apply(.espulsione, to: score)    // 47
        XCTAssertEqual(score, 47)

        // Sequenza equivalente in un colpo solo.
        let sequenced = engine.score(from: rules.initialScore,
                                     applying: [.pubblicazione, .commento, .ripresaParola,
                                                .silenzio, .espulsione])
        XCTAssertEqual(sequenced, 47)
    }

    func testScoreClampAtBounds() {
        // Non si supera mai il massimo…
        XCTAssertEqual(engine.apply(.pubblicazione, to: rules.scoreMax - 1), rules.scoreMax)
        XCTAssertEqual(engine.apply(.pubblicazione, to: rules.scoreMax), rules.scoreMax)
        // …né si scende sotto il minimo.
        XCTAssertEqual(engine.apply(.espulsione, to: rules.scoreMin + 1), rules.scoreMin)
        XCTAssertEqual(engine.apply(.espulsione, to: rules.scoreMin), rules.scoreMin)
        // Il clamp vale a ogni passo: 1 → espulsione (0) → pubblicazione (2), non (−4 → −2).
        XCTAssertEqual(engine.score(from: 1, applying: [.espulsione, .pubblicazione]), 2)
        // Anche un punteggio iniziale fuori intervallo viene normalizzato.
        XCTAssertEqual(engine.score(from: 300, applying: []), rules.scoreMax)
    }

    // MARK: - Fasce

    func testScoreBands() {
        XCTAssertEqual(engine.band(for: rules.bandVoceVivaThreshold), .voceViva)          // 75
        XCTAssertEqual(engine.band(for: rules.scoreMax), .voceViva)                        // 100
        XCTAssertEqual(engine.band(for: rules.bandVoceVivaThreshold - 1), .presenzaDiscreta) // 74
        XCTAssertEqual(engine.band(for: rules.bandPresenzaDiscretaThreshold), .presenzaDiscreta) // 45
        XCTAssertEqual(engine.band(for: rules.bandPresenzaDiscretaThreshold - 1), .ombraAlTavolo) // 44
        XCTAssertEqual(engine.band(for: rules.scoreMin), .ombraAlTavolo)                   // 0
    }

    // MARK: - Richieste d'ingresso (accoglienza/declino)

    func testJoinRequestAcceptance() {
        // L'animatore può accogliere chi ha ancora slot…
        XCTAssertTrue(engine.canAcceptJoinRequest(requesterCircleCount: rules.maxCircles - 1))
        // …ma non chi già abita il massimo dei circoli.
        XCTAssertFalse(engine.canAcceptJoinRequest(requesterCircleCount: rules.maxCircles))
    }
}
