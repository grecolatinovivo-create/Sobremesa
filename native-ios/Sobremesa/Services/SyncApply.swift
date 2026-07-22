//
//  SyncApply.swift
//  Sobremesa
//
//  Il riversamento del mondo server in SwiftData: il server è la fonte
//  di verità, il database locale è la sua fotografia (e la UI, che legge
//  con @Query, resta reattiva senza cambiare una riga).
//

import Foundation
import SwiftData

extension LocalDataService {

    /// Applica un intero SyncPayload: il mondo remoto sostituisce quello locale.
    /// Il profilo (isMe) si aggiorna in place; tutto il resto si ricostruisce.
    func applySync(_ payload: SyncPayload) {
        // 1. Via la fotografia precedente.
        try? context.delete(model: Friendship.self)
        try? context.delete(model: Membership.self)
        try? context.delete(model: JoinRequest.self)
        try? context.delete(model: Comment.self)
        try? context.delete(model: Post.self)
        try? context.delete(model: Circolo.self)
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

        // 3. Le persone.
        var people: [String: Person] = [:]
        if let meRow, let id = meRow.serverID { people[id] = meRow }
        func person(id: String, name: String, score: Int, pendingInvite: Bool = false) -> Person {
            if let existing = people[id] { return existing }
            let created = Person(name: name, score: score, hasPendingInvite: pendingInvite)
            created.serverID = id
            context.insert(created)
            people[id] = created
            return created
        }

        // 4. La tavola.
        for friend in payload.friends {
            let row = person(id: friend.id, name: friend.name, score: friend.score)
            context.insert(Friendship(person: row))
        }
        for invite in payload.pendingInvites {
            _ = person(id: invite.user_id, name: invite.name, score: invite.score, pendingInvite: true)
        }

        // 5. I circoli (abitati + catalogo).
        var circles: [String: Circolo] = [:]
        func circle(_ remote: RemoteCircle) -> Circolo {
            if let existing = circles[remote.id] { return existing }
            let created = Circolo(nameKey: remote.name,
                                  themeKey: remote.theme,
                                  category: PostCategory(rawValue: remote.category) ?? .idea,
                                  isOpen: remote.is_open,
                                  animatedByMe: remote.animator == payload.me.id,
                                  memberCount: remote.member_count,
                                  isSeedContent: false)
            created.serverID = remote.id
            context.insert(created)
            circles[remote.id] = created
            return created
        }
        for remote in payload.myCircles {
            let row = circle(remote)
            if let meRow {
                context.insert(Membership(person: meRow, circolo: row,
                                          joinedAt: remote.joined_at?.serverDate ?? .now,
                                          lastActivity: remote.last_activity?.serverDate ?? .now))
            }
        }
        for remote in payload.catalog { _ = circle(remote) }

        // 6. Le richieste d'ingresso (nei circoli che animo).
        for remote in payload.requests {
            guard let circleRow = circles[remote.circle_id] else { continue }
            let requester = person(id: remote.user_id, name: remote.name, score: remote.score)
            let request = JoinRequest(circolo: circleRow, person: requester)
            request.serverID = remote.id
            context.insert(request)
        }

        // 7. Il salotto: post e commenti.
        var posts: [String: Post] = [:]
        for remote in payload.posts {
            let author = person(id: remote.author, name: remote.author_name, score: remote.author_score)
            // Convenzione locale: nutreCount esclude il mio Nutre (che è un flag).
            let post = Post(author: author,
                            circolo: remote.circle_id.flatMap { circles[$0] },
                            category: PostCategory(rawValue: remote.category) ?? .idea,
                            text: remote.text,
                            isSeedContent: false,
                            createdAt: remote.created_at.serverDate,
                            nutreCount: max(0, remote.nutre_count - (remote.nutrito_da_me ? 1 : 0)))
            post.nutritoDaMe = remote.nutrito_da_me
            post.serverID = remote.id
            context.insert(post)
            posts[remote.id] = post
        }
        for remote in payload.comments {
            guard let post = posts[remote.post_id] else { continue }
            let author = people[remote.author_id]
                ?? person(id: remote.author_id, name: remote.author_name, score: 0)
            context.insert(Comment(post: post, author: author,
                                   text: remote.text,
                                   createdAt: remote.created_at.serverDate))
        }

        try? context.save()
    }
}
