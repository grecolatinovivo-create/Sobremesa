//
//  ProductRules.swift
//  Sobremesa
//
//  Tutti i numeri di prodotto vivono QUI e solo qui.
//  Nessun 12, 5, 4, 7, +2, −5… sparso nel codice: chi ha bisogno
//  di un parametro lo legge da ProductRules.
//

import Foundation

/// Parametri di prodotto centralizzati di Sobremesa.
/// Una sola fonte di verità, iniettabile nei test con valori diversi.
struct ProductRules: Equatable, Sendable {

    // MARK: Tavola
    /// Le sedie della tavola: massimo numero di amici reciproci.
    var maxFriends: Int = 12

    // MARK: Circoli
    /// Massimo numero di circoli abitati contemporaneamente.
    var maxCircles: Int = 5

    // MARK: La regola della brace (giorni di silenzio per circolo)
    /// Da questo numero di giorni la brace "si affievolisce".
    var emberDimAfterDays: Int = 2
    /// Da questo numero di giorni scatta l'avviso rosso.
    var emberWarningAfterDays: Int = 4
    /// Da questo numero di giorni il posto si libera automaticamente.
    var emberExpulsionAfterDays: Int = 7
    /// La brace si valuta solo se il circolo ha almeno questi membri:
    /// da soli non c'è conversazione da tenere viva.
    var emberMinimumMembers: Int = 2

    // MARK: Punteggio di partecipazione
    /// Punti per una pubblicazione.
    var pointsPost: Int = 2
    /// Punti per un commento.
    var pointsComment: Int = 1
    /// Punti per "riprendi la parola".
    var pointsRetake: Int = 1
    /// Penalità per un periodo di silenzio in un circolo (valore negativo).
    var pointsSilencePenalty: Int = -2
    /// Penalità per un'espulsione da un circolo (valore negativo).
    var pointsExpulsionPenalty: Int = -5

    /// Estremi del punteggio (clamp).
    var scoreMin: Int = 0
    var scoreMax: Int = 100
    /// Punteggio di partenza di una nuova persona (v. DECISIONI.md #2).
    var initialScore: Int = 50

    // MARK: Fasce del punteggio
    /// Soglia "Voce viva" (inclusa).
    var bandVoceVivaThreshold: Int = 75
    /// Soglia "Presenza discreta" (inclusa).
    var bandPresenzaDiscretaThreshold: Int = 45

    /// Le regole standard di prodotto.
    static let standard = ProductRules()
}
