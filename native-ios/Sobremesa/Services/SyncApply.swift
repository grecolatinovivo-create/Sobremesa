//
//  SyncApply.swift
//  Sobremesa
//
//  Il riversamento del mondo server in SwiftData — PER UPSERT, mai per
//  azzeramento: le view tengono riferimenti vivi ai modelli (la stanza
//  aperta, i NavigationLink), quindi gli oggetti esistenti si aggiornano
//  in place e si cancella SOLO ciò che il server non conosce più.
//  I record ottimistici (serverID nil) vengono adottati, non duplicati.
//

import Foundation
import SwiftData

extension LocalDataService {

    func applySync(_ payload: SyncPayload) {
        let everyone = (try? context.fetch(FetchDescriptor<Person>())) ?? []
        let meRow = everyone.first { $0.isMe }

        // 1. Il profilo.
        if let meRow {
            meRow.serverID = payload.me.id
            meRow.name = payload.me.name
            meRow.score = payload.me.score
        }

        // 2. Le persone: upsert per id server.
        var people: [String: Person] = [:]
        for person in everyone {
            if let id = person.serverID { people[id] = person }
        }
        func person(id: String, name: String, score: Int) -> Person {
            if let existing = people[id] {
                existing.name = name
                existing.score = score
                return existing
            }
            let created = Person(name: name, score: score)
            created.serverID = id
            context.insert(created)
            people[id] = created
            return created
        }

        // 3. I tavoli: upsert per id server; i tavoli ottimistici (serverID
        // nil) vengono ADOTTATI per nome, così la fondazione non duplica.
        let localTables = (try? context.fetch(FetchDescriptor<Tavolo>())) ?? []
        var tables: [String: Tavolo] = [:]
        for tavolo in localTables {
            if let id = tavolo.serverID { tables[id] = tavolo }
        }
        var serverTableIDs = Set<String>()
        func table(_ remote: RemoteTable) -> Tavolo {
            serverTableIDs.insert(remote.id)
            if let existing = tables[remote.id] {
                existing.name = remote.name
                existing.theme = remote.theme
                existing.categoryRaw = remote.category
                existing.isOpen = remote.is_open
                existing.animatedByMe = remote.animator == payload.me.id
                existing.memberCount = remote.member_count
                existing.animatorServerID = remote.animator
                return existing
            }
            // Adozione dell'ottimistico: stesso nome, ancora senza id server.
            if let pending = localTables.first(where: { $0.serverID == nil && $0.name == remote.name }) {
                pending.serverID = remote.id
                pending.theme = remote.theme
                pending.categoryRaw = remote.category
                pending.isOpen = remote.is_open
                pending.animatedByMe = remote.animator == payload.me.id
                pending.memberCount = remote.member_count
                pending.animatorServerID = remote.animator
                tables[remote.id] = pending
                return pending
            }
            let created = Tavolo(name: remote.name,
                                 theme: remote.theme,
                                 category: PostCategory(rawValue: remote.category) ?? .idea,
                                 isOpen: remote.is_open,
                                 animatedByMe: remote.animator == payload.me.id,
                                 memberCount: remote.member_count)
            created.serverID = remote.id
            created.animatorServerID = remote.animator
            context.insert(created)
            tables[remote.id] = created
            return created
        }

        // 4. Le mie sedie: upsert per tavolo (lastReadAt NON si tocca).
        let allMemberships = (try? context.fetch(FetchDescriptor<Membership>())) ?? []
        var myTableIDs = Set<String>()
        for remote in payload.myTables {
            let row = table(remote)
            myTableIDs.insert(remote.id)
            if let mine = allMemberships.first(where: { $0.person?.isMe == true && $0.tavolo === row }) {
                mine.joinedAt = remote.joined_at?.serverDate ?? mine.joinedAt
                mine.lastActivity = remote.last_activity?.serverDate ?? mine.lastActivity
                mine.silencePenaltyApplied = remote.penalty_applied ?? false
            } else if let meRow {
                let created = Membership(person: meRow, tavolo: row,
                                         joinedAt: remote.joined_at?.serverDate ?? .now,
                                         lastActivity: remote.last_activity?.serverDate ?? .now)
                created.silencePenaltyApplied = remote.penalty_applied ?? false
                context.insert(created)
            }
        }
        for remote in payload.catalog { _ = table(remote) }

        // 5. Le sedie degli altri: transitorie, si ricostruiscono.
        for membership in allMemberships where membership.person?.isMe != true {
            context.delete(membership)
        }
        for seat in payload.seats {
            guard let row = tables[seat.circle_id], seat.user_id != payload.me.id else { continue }
            let member = person(id: seat.user_id, name: seat.name, score: seat.score)
            context.insert(Membership(person: member, tavolo: row,
                                      joinedAt: seat.joined_at?.serverDate ?? .now))
        }

        // 6. Le mie sedie che il server non conosce più (espulso/alzato altrove).
        for membership in allMemberships where membership.person?.isMe == true {
            guard let id = membership.tavolo?.serverID else { continue }
            if !myTableIDs.contains(id) { context.delete(membership) }
        }

        // 7. I tavoli spariti dal server (chiusi): via, con tutto il loro mondo.
        let currentMessages = (try? context.fetch(FetchDescriptor<Messaggio>())) ?? []
        let currentMemberships = (try? context.fetch(FetchDescriptor<Membership>())) ?? []
        for tavolo in localTables where !tavolo.isDeleted {
            if let id = tavolo.serverID {
                guard !serverTableIDs.contains(id) else { continue }
            } else {
                // Ottimistico mai adottato e senza fondazione in volo: è un
                // fantasma (il server non l'ha mai creato). Via, con tutto ciò
                // che gli è appeso — altrimenti resta "In attesa" per sempre.
                guard !pendingTableNames.contains(tavolo.name) else { continue }
            }
            for messaggio in currentMessages where messaggio.tavolo === tavolo && !messaggio.isDeleted {
                context.delete(messaggio)
            }
            for membership in currentMemberships where membership.tavolo === tavolo && !membership.isDeleted {
                context.delete(membership)
            }
            context.delete(tavolo)
        }

        // 8. Le richieste: transitorie, si ricostruiscono.
        try? context.delete(model: JoinRequest.self)
        for remote in payload.requests {
            guard let row = tables[remote.circle_id] else { continue }
            let requester = person(id: remote.user_id, name: remote.name, score: remote.score)
            let request = JoinRequest(tavolo: row, person: requester)
            request.serverID = remote.id
            context.insert(request)
        }

        // 9. I messaggi: upsert per id server; gli ottimistici (serverID nil)
        // vengono adottati per testo+tavolo. Mai cancellati per assenza
        // (il sync porta gli ultimi 300: i più vecchi restano come memoria).
        var byServerID: [String: Messaggio] = [:]
        for messaggio in currentMessages {
            if let id = messaggio.serverID { byServerID[id] = messaggio }
        }
        for remote in payload.messages {
            guard let row = tables[remote.circle_id] else { continue }
            let author = person(id: remote.author, name: remote.author_name, score: remote.author_score)
            let othersCount = max(0, remote.nutre_count - (remote.nutrito_da_me ? 1 : 0))
            if let existing = byServerID[remote.id] {
                existing.nutreCount = othersCount
                existing.nutritoDaMe = remote.nutrito_da_me
                continue
            }
            if remote.author == payload.me.id,
               let pending = currentMessages.first(where: {
                   $0.serverID == nil && $0.tavolo === row && $0.text == remote.text
               }) {
                pending.serverID = remote.id
                pending.createdAt = remote.created_at.serverDate
                pending.nutreCount = othersCount
                pending.nutritoDaMe = remote.nutrito_da_me
                byServerID[remote.id] = pending
                continue
            }
            let messaggio = Messaggio(author: author,
                                      tavolo: row,
                                      text: remote.text,
                                      createdAt: remote.created_at.serverDate,
                                      nutreCount: othersCount)
            messaggio.nutritoDaMe = remote.nutrito_da_me
            messaggio.serverID = remote.id
            context.insert(messaggio)
            byServerID[remote.id] = messaggio
        }

        // 10. Sicurezza (v3): ciò che non devo più vedere sparisce anche
        // dalla memoria locale — interventi nascosti o segnalati da me,
        // e tutto ciò che ha scritto chi ho bloccato.
        let hiddenIDs = Set(payload.hidden ?? [])
        let blockedIDs = Set((payload.blocked ?? []).map(\.id))
        if !hiddenIDs.isEmpty || !blockedIDs.isEmpty {
            for messaggio in byServerID.values where !messaggio.isDeleted {
                let hidden = messaggio.serverID.map { hiddenIDs.contains($0) } ?? false
                let blocked = messaggio.author?.serverID.map { blockedIDs.contains($0) } ?? false
                if hidden || blocked { context.delete(messaggio) }
            }
        }

        try? context.save()
    }
}
