//
//  Models.swift
//  Sobremesa
//
//  Modelli SwiftData del modello v2 "solo tavoli" (DECISIONI #36):
//  un Tavolo è una conversazione a tema con al massimo 12 sedie;
//  se ne abitano al massimo 5; dentro si parla a Messaggi, come a cena.
//  Il server è la fonte di verità; questo store ne è la fotografia.
//

import Foundation
import SwiftData

// MARK: - Categorie dei tavoli

/// Le sei categorie culturali di Sobremesa (una per tavolo).
enum PostCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case libro, film, musica, arte, teatro, idea

    var id: String { rawValue }

    /// Chiave di localizzazione della label.
    var labelKey: String { "category.\(rawValue)" }

    /// SF Symbol associato.
    var symbolName: String {
        switch self {
        case .libro:  return "book.closed.fill"
        case .film:   return "film"
        case .musica: return "music.note"
        case .arte:   return "paintpalette.fill"
        case .teatro: return "theatermasks.fill"
        case .idea:   return "lightbulb.fill"
        }
    }
}

// MARK: - Person

/// Una persona: l'utente (isMe) o chi siede ai suoi tavoli.
@Model
final class Person {
    /// Nome proprio: non localizzato (DECISIONI.md #10).
    var name: String
    /// Punteggio di partecipazione corrente (0–100, gestito dall'engine).
    var score: Int
    /// È l'utente dell'app?
    var isMe: Bool
    /// Identificatore stabile di Sign in with Apple (solo per l'utente).
    var appleUserID: String?
    /// Id lato server.
    var serverID: String?

    init(name: String, score: Int, isMe: Bool = false, appleUserID: String? = nil) {
        self.name = name
        self.score = score
        self.isMe = isMe
        self.appleUserID = appleUserID
    }

    /// Iniziali per gli avatar e le sedie.
    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)) }.joined()
    }
}

// MARK: - Tavolo

/// Un tavolo tematico: IL luogo di Sobremesa. Massimo 12 sedie,
/// una conversazione, una brace da tenere viva.
@Model
final class Tavolo {
    var name: String
    /// Il tema: di cosa si parla a questo tavolo.
    var theme: String
    var categoryRaw: String
    /// Aperto: ci si può sedere dal catalogo senza chiedere.
    var isOpen: Bool
    /// L'utente ha fondato questo tavolo? (l'animatore non viene mai espulso)
    var animatedByMe: Bool
    /// Sedie occupate (contatore dal server).
    var memberCount: Int
    /// Id lato server.
    var serverID: String?
    /// Id server dell'animatore (chi ha fondato il tavolo).
    var animatorServerID: String?

    init(name: String,
         theme: String,
         category: PostCategory,
         isOpen: Bool = true,
         animatedByMe: Bool = false,
         memberCount: Int) {
        self.name = name
        self.theme = theme
        self.categoryRaw = category.rawValue
        self.isOpen = isOpen
        self.animatedByMe = animatedByMe
        self.memberCount = memberCount
    }

    var category: PostCategory { PostCategory(rawValue: categoryRaw) ?? .idea }
}

// MARK: - Membership (una sedia occupata)

/// Il sedere a un tavolo: lega una persona a un tavolo e porta
/// lo stato temporale della brace (per l'utente).
@Model
final class Membership {
    var person: Person?
    var tavolo: Tavolo?
    var joinedAt: Date
    /// Ultima attività registrata al tavolo (messaggio, ripresa di parola).
    var lastActivity: Date
    /// La penalità per il periodo di silenzio corrente è già stata applicata?
    var silencePenaltyApplied: Bool
    /// Fin dove ho letto la conversazione (solo per le MIE sedie):
    /// alimenta i "nuovi interventi" del Salotto. Mai sovrascritto dal sync.
    var lastReadAt: Date

    init(person: Person, tavolo: Tavolo, joinedAt: Date = .now, lastActivity: Date = .now) {
        self.person = person
        self.tavolo = tavolo
        self.joinedAt = joinedAt
        self.lastActivity = lastActivity
        self.silencePenaltyApplied = false
        self.lastReadAt = .distantPast
    }
}

// MARK: - Messaggio

/// Un intervento nella conversazione di un tavolo.
@Model
final class Messaggio {
    var author: Person?
    var tavolo: Tavolo?
    var text: String
    var createdAt: Date
    /// "Nutre" ricevuti da altri — il mio è un flag a parte (mai doppio conteggio).
    var nutreCount: Int
    var nutritoDaMe: Bool
    /// Id lato server; nil per messaggi in attesa di conferma.
    var serverID: String?

    init(author: Person, tavolo: Tavolo, text: String,
         createdAt: Date = .now, nutreCount: Int = 0) {
        self.author = author
        self.tavolo = tavolo
        self.text = text
        self.createdAt = createdAt
        self.nutreCount = nutreCount
        self.nutritoDaMe = false
    }
}

// MARK: - JoinRequest

/// Richiesta di sedersi a un tavolo chiuso che l'utente anima.
@Model
final class JoinRequest {
    var tavolo: Tavolo?
    var person: Person?
    var createdAt: Date
    /// Id lato server.
    var serverID: String?

    init(tavolo: Tavolo, person: Person, createdAt: Date = .now) {
        self.tavolo = tavolo
        self.person = person
        self.createdAt = createdAt
    }
}

// MARK: - ParticipationEvent

/// Registro degli eventi che hanno mosso il punteggio (audit trail).
@Model
final class ParticipationEvent {
    var person: Person?
    var tavolo: Tavolo?
    var actionRaw: String
    /// Punti applicati (già col segno, dai pesi di ProductRules al momento dell'evento).
    var points: Int
    var date: Date

    init(person: Person, tavolo: Tavolo? = nil, action: ParticipationAction, points: Int, date: Date = .now) {
        self.person = person
        self.tavolo = tavolo
        self.actionRaw = action.rawValue
        self.points = points
        self.date = date
    }

    var action: ParticipationAction? { ParticipationAction(rawValue: actionRaw) }
}
