//
//  SyncApply.swift
//  Sobremesa
//
//  Il riversamento del mondo server in SwiftData (modello v2 "solo tavoli"):
//  il server è la fonte di verità, il database locale è la sua fotografia
//  (e la UI, che legge con @Query, resta reattiva senza cambiare una riga).
//

import Foundation
import SwiftData

extension LocalDataService {

    /// Applica un intero SyncPayload: il mondo remoto sostituisce quello locale.
    /// Il profilo (isMe) si aggiorna in place; tutto il resto si ricostruisce.
    func applySync(_ payload: SyncPayload) {
        // 1. Via la fotografia precedente.
        try? context.delete(model: Membership.self)
        try? context.delete(model: JoinRequest.self)
        try? context.delete(model: Messaggio.self)
        try? context.delete(model: Tavolo.self)
        let everyone = (try? context.fetch(FetchDescriptor<Person>())) ?? []
        var meRow: Person?
        for person in everyone {
            if person.isMe { meRow = person } else { context.delete(person) }
        }

        // 2. Il profilo.
        if let meRow {
            meRow.serverID = payload.me.id
            meRow.name = payload.me.name
            meRow.score = payload.me.score
        }

        // 3. Le persone (dedup per id server).
        var people: [String: Person] = [:]
        if let meRow, let id = meRow.serverID { people[id] = meRow }
        func person(id: String, name: String, score: Int) -> Person {
            if let existing = people[id] { return existing }
            let created = Person(name: name, score: score)
            created.serverID = id
            context.insert(created)
            people[id] = created
            return created
        }

        // 4. I tavoli (miei + catalogo).
        var tables: [String: Tavolo] = [:]
        func table(_ remote: RemoteTable) -> Tavolo {
            if let existing = tables[remote.id] { return existing }
            let created = Tavolo(name: remote.name,
                                 theme: remote.theme,
                                 category: PostCategory(rawValue: remote.category) ?? .idea,
                                 isOpen: remote.is_open,
                                 animatedByMe: remote.animator == payload.me.id,
                                 memberCount: remote.member_count)
            created.serverID = remote.id
            context.insert(created)
            tables[remote.id] = created
            return created
        }
        for remote in payload.myTables {
            let row = table(remote)
            if let meRow {
                context.insert(Membership(person: meRow, tavolo: row,
                                          joinedAt: remote.joined_at?.serverDate ?? .now,
                                          lastActivity: remote.last_activity?.serverDate ?? .now))
            }
        }
        for remote in payload.catalog { _ = table(remote) }

        // 5. Le sedie: chi siede ai miei tavoli (myMemberships filtra su isMe,
        // quindi brace e regole non ne risentono).
        for seat in payload.seats {
            guard let row = tables[seat.circle_id], seat.user_id != payload.me.id else { continue }
            let member = person(id: seat.user_id, name: seat.name, score: seat.score)
            context.insert(Membership(person: member, tavolo: row))
        }

        // 6. Le richieste di sedersi (ai tavoli che animo).
        for remote in payload.requests {
            guard let row = tables[remote.circle_id] else { continue }
            let requester = person(id: remote.user_id, name: remote.name, score: remote.score)
            let request = JoinRequest(tavolo: row, person: requester)
            request.serverID = remote.id
            context.insert(request)
        }

        // 7. Le conversazioni.
        for remote in payload.messages {
            guard let row = tables[remote.circle_id] else { continue }
            let author = person(id: remote.author, name: remote.author_name, score: remote.author_score)
            // Convenzione locale: nutreCount esclude il mio Nutre (che è un flag).
            let messaggio = Messaggio(author: author,
                                      tavolo: row,
                                      text: remote.text,
                                      createdAt: remote.created_at.serverDate,
                                      nutreCount: max(0, remote.nutre_count - (remote.nutrito_da_me ? 1 : 0)))
            messaggio.nutritoDaMe = remote.nutrito_da_me
            messaggio.serverID = remote.id
            context.insert(messaggio)
        }

        try? context.save()
    }
}
