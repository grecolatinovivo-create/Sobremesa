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
        container = Self.makeContainer()
        let service = LocalDataService(context: container.mainContext)
        _store = State(initialValue: AppStore(data: service))
    }

    /// Crea il container; se lo store non si apre (es. schema delle vecchie
    /// build demo che non migra), lo cancella e riparte da zero: quei dati
    /// erano comunque finti e destinati alla purge. MAI un crash-loop.
    private static func makeContainer() -> ModelContainer {
        do {
            return try makeContainerOnce()
        } catch {
            destroyStore()
            UserDefaults.standard.set(false, forKey: "sobremesa.didSeed")
            do {
                return try makeContainerOnce()
            } catch {
                fatalError("Sobremesa: impossibile creare il ModelContainer (\(error))")
            }
        }
    }

    private static func makeContainerOnce() throws -> ModelContainer {
        try ModelContainer(
            for: Person.self, Friendship.self, Circolo.self, Membership.self,
            Post.self, Comment.self, JoinRequest.self, ParticipationEvent.self
        )
    }

    private static func destroyStore() {
        let support = URL.applicationSupportDirectory
        for name in ["default.store", "default.store-wal", "default.store-shm"] {
            try? FileManager.default.removeItem(at: support.appending(path: name))
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(store)
                // Dark-first: il tema scuro è l'identità del prodotto, non un'opzione.
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}

// MARK: - Radice: accesso o le quattro stanze

/// Decide se mostrare l'onboarding (nessun profilo) o l'app vera e propria.
struct AppRootView: View {
    @Environment(AppStore.self) private var store
    @State private var didBootstrap = false

    var body: some View {
        Group {
            if store.needsOnboarding {
                OnboardingView()
            } else {
                RootTabView()
            }
        }
        // Il multilingua interno: le Text si localizzano dal locale
        // d'ambiente, che qui segue la scelta fatta in Tu -> Lingua.
        .environment(\.locale, store.appLocale)
        .onAppear {
            guard !didBootstrap else { return }
            didBootstrap = true
            store.bootstrap()
        }
    }
}
