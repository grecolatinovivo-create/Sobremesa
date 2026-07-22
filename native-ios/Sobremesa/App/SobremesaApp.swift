//
//  SobremesaApp.swift
//  Sobremesa
//
//  Entry point: crea il ModelContainer SwiftData, il backend locale
//  e lo store osservabile, e impone il tema scuro (dark-first: è identità).
//

import SwiftUI
import SwiftData

@main
struct SobremesaApp: App {

    private let container: ModelContainer
    @State private var store: AppStore

    init() {
        do {
            container = try ModelContainer(
                for: Person.self, Friendship.self, Circolo.self, Membership.self,
                Post.self, Comment.self, JoinRequest.self, ParticipationEvent.self
            )
        } catch {
            fatalError("Sobremesa: impossibile creare il ModelContainer (\(error))")
        }
        let service = LocalDataService(context: container.mainContext)
        _store = State(initialValue: AppStore(data: service))
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(store)
                // Dark-first: il tema scuro è l'identità del prodotto, non un'opzione.
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}
