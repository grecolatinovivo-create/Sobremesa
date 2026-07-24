//
//  RootTabView.swift
//  Sobremesa
//
//  Le 4 stanze dell'app: Salotto, Circoli, Tavola, Tu.
//  Qui vivono anche il bootstrap (seed + prima valutazione della brace),
//  la rivalutazione al ritorno in foreground e l'overlay dei toast.
//

import SwiftUI

struct RootTabView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var store = store
        // L'ordine racconta il flusso: dal salotto ai circoli (dove si
        // conosce gente), poi alla tavola (dove la si porta). DECISIONI #34.
        TabView(selection: $store.stanzaCorrente) {
            SalottoView()
                .tabItem { Label("tab.salotto", systemImage: "cup.and.saucer.fill") }
                .tag(AppStore.Stanza.salotto)
            CircoliView()
                .tabItem { Label("tab.circoli", systemImage: "flame") }
                .tag(AppStore.Stanza.circoli)
            TavolaView()
                .tabItem { Label("tab.tavola", systemImage: "table.furniture") }
                .tag(AppStore.Stanza.tavola)
            TuView()
                .tabItem { Label("tab.tu", systemImage: "person.crop.circle") }
                .tag(AppStore.Stanza.tu)
        }
        .tint(.brass)
        .overlay(alignment: .bottom) { toastOverlay }
        .onChange(of: scenePhase) { _, newPhase in
            // Il tempo è reale: a ogni ritorno in foreground la brace va rivalutata.
            if newPhase == .active {
                store.appBecameActive()
            }
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let toast = store.toast {
            ToastView(notice: toast) { store.dismissToast() }
                .padding(.bottom, 64)
                .transition(reduceMotion
                            ? .opacity
                            : .move(edge: .bottom).combined(with: .opacity))
        }
    }
}
