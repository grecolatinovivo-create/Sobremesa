//
//  Models.swift
//  Sobremesa
//
//  Modelli SwiftData. Il "backend" è simulato in locale (LocalDataService):
//  i contenuti demo memorizzano CHIAVI di localizzazione (isSeedContent = true)
//  che le view risolvono a runtime, così cambiando lingua anche i dati demo
//  risultano tradotti. I contenuti creati dall'utente sono testo puro.
//

import Foundation
import SwiftData

// MARK: - Categorie dei post

/// Le sei categorie culturali di Sobremesa.
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

/// Una persona: l'utente (isMe), un amico, un candidato o un membro di circolo.
@Model
final class Person {
    /// Nome proprio: non localizzato (DECISIONI.md #10).
    var name: String
    /// Chiave di localizzazione della bio (solo profili seed).
    var bioKey: String?
    /// Chiavi di localizzazione degli interessi (es. "interest.poesia").
    var interestKeys: [String]
    /// Punteggio di partecipazione corrente (0–100, gestito dall'engine).
    var score: Int
    /// È l'utente dell'app?
    var isMe: Bool
    /// È un candidato all'invito (compare in "Persone che potresti invitare")?
    var isCandidate: Bool
    /// Ha un invito in sospeso (tavola piena al momento dell'invito)?
    var hasPendingInvite: Bool
    /// Identificatore stabile di Sign in with Apple (solo per l'utente).
    var appleUserID: String?
    /// Id lato server (backend Sobremesa); nil per righe puramente locali.
    var serverID: String?

    init(name: String,
         bioKey: String? = nil,
         interestKeys: [String] = [],
         score: Int,
         isMe: Bool = false,
         isCandidate: Bool = false,
         hasPendingInvite: Bool = false,
         appleUserID: String? = nil) {
        self.name = name
        self.bioKey = bioKey
        self.interestKeys = interestKeys
        self.score = score
        self.isMe = isMe
        self.isCandidate = isCandidate
        self.hasPendingInvite = hasPendingInvite
        self.appleUserID = appleUserID
    }

    /// Iniziali per gli avatar e le sedie della tavola.
    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)) }.joined()
    }
}

// MARK: - Friendship

/// Amicizia reciproca: una sedia occupata alla tavola dell'utente.
@Model
final class Friendship {
    var person: Person?
    var since: Date

    init(person: Person, since: Date = .now) {
        self.person = person
        self.since = since
    }
}

// MARK: - Circolo

/// Un circolo tematico. (Il nome evita la collisione con SwiftUI.Circle,
/// v. DECISIONI.md #1.)
@Model
final class Circolo {
    /// Chiave di localizzazione del nome (i circoli demo sono localizzati).
    var nameKey: String
    /// Chiave di localizzazione del tema/descrizione.
    var themeKey: String
    /// Categoria prevalente del circolo.
    var categoryRaw: String
    /// Aperto all'ingresso diretto dal catalogo?
    var isOpen: Bool
    /// L'utente è l'animatore di questo circolo?
    var animatedByMe: Bool
    /// Numero membri complessivo, membri "di sfondo" inclusi (DECISIONI.md #7).
    var memberCount: Int
    /// true = contenuto demo (nome/tema sono chiavi del String Catalog);
    /// false = circolo creato dall'utente (nome/tema sono testo puro).
    var isSeedContent: Bool
    /// Id lato server; nil per circoli puramente locali (demo).
    var serverID: String?

    init(nameKey: String,
         themeKey: String,
         category: PostCategory,
         isOpen: Bool = true,
         animatedByMe: Bool = false,
         memberCount: Int,
         isSeedContent: Bool = false) {
        self.nameKey = nameKey
        self.themeKey = themeKey
        self.categoryRaw = category.rawValue
        self.isOpen = isOpen
        self.animatedByMe = animatedByMe
        self.memberCount = memberCount
        self.isSeedContent = isSeedContent
    }

    var category: PostCategory { PostCategory(rawValue: categoryRaw) ?? .idea }

    /// Nome visualizzabile (risolve la chiave solo per i contenuti demo).
    var displayName: String { isSeedContent ? nameKey.loc : nameKey }
    /// Tema visualizzabile.
    var displayTheme: String { isSeedContent ? themeKey.loc : themeKey }
}

// MARK: - Membership

/// L'abitare un circolo: lega una persona a un circolo e porta
/// lo stato temporale della brace.
@Model
final class Membership {
    var person: Person?
    var circolo: Circolo?
    var joinedAt: Date
    /// Ultima attività registrata nel circolo (pubblicazione, commento, ripresa).
    var lastActivity: Date
    /// La penalità −2 per il periodo di silenzio corrente è già stata applicata?
    var silencePenaltyApplied: Bool

    init(person: Person, circolo: Circolo, joinedAt: Date = .now, lastActivity: Date = .now) {
        self.person = person
        self.circolo = circolo
        self.joinedAt = joinedAt
        self.lastActivity = lastActivity
        self.silencePenaltyApplied = false
    }
}

// MARK: - Post

/// Un post del feed: da un amico (circolo nil) o da un circolo abitato.
@Model
final class Post {
    var author: Person?
    var circolo: Circolo?
    var categoryRaw: String
    /// Testo (chiave di localizzazione se isSeedContent).
    var text: String
    var isSeedContent: Bool
    var createdAt: Date
    /// "Nutre" ricevuti da altri — il mio è tracciato a parte.
    var nutreCount: Int
    /// Id lato server; nil per post puramente locali.
    var serverID: String?
    /// L'utente ha nutrito questo post? (toggle, mai doppio conteggio)
    var nutritoDaMe: Bool

    @Relationship(deleteRule: .cascade, inverse: \Comment.post)
    var comments: [Comment]

    init(author: Person,
         circolo: Circolo? = nil,
         category: PostCategory,
         text: String,
         isSeedContent: Bool = false,
         createdAt: Date = .now,
         nutreCount: Int = 0) {
        self.author = author
        self.circolo = circolo
        self.categoryRaw = category.rawValue
        self.text = text
        self.isSeedContent = isSeedContent
        self.createdAt = createdAt
        self.nutreCount = nutreCount
        self.nutritoDaMe = false
        self.comments = []
    }

    var category: PostCategory { PostCategory(rawValue: categoryRaw) ?? .idea }
}

// MARK: - Comment

/// Un commento a un post.
@Model
final class Comment {
    var post: Post?
    var author: Person?
    /// Testo (chiave di localizzazione se isSeedContent).
    var text: String
    var isSeedContent: Bool
    var createdAt: Date

    init(post: Post? = nil,
         author: Person?,
         text: String,
         isSeedContent: Bool = false,
         createdAt: Date = .now) {
        self.post = post
        self.author = author
        self.text = text
        self.isSeedContent = isSeedContent
        self.createdAt = createdAt
    }
}

// MARK: - JoinRequest

/// Richiesta d'ingresso in un circolo animato dall'utente.
@Model
final class JoinRequest {
    var circolo: Circolo?
    var person: Person?
    var createdAt: Date
    /// Id lato server.
    var serverID: String?

    init(circolo: Circolo, person: Person, createdAt: Date = .now) {
        self.circolo = circolo
        self.person = person
        self.createdAt = createdAt
    }
}

// MARK: - ParticipationEvent

/// Registro degli eventi che hanno mosso il punteggio (audit trail).
@Model
final class ParticipationEvent {
    var person: Person?
    var circolo: Circolo?
    var actionRaw: String
    /// Punti applicati (già col segno, dai pesi di ProductRules al momento dell'evento).
    var points: Int
    var date: Date

    init(person: Person, circolo: Circolo? = nil, action: ParticipationAction, points: Int, date: Date = .now) {
        self.person = person
        self.circolo = circolo
        self.actionRaw = action.rawValue
        self.points = points
        self.date = date
    }

    var action: ParticipationAction? { ParticipationAction(rawValue: actionRaw) }
}
