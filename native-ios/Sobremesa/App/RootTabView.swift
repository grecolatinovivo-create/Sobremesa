//
//  RootTabView.swift
//  Sobremesa
//
//  Le 3 stanze dell'app (v3 "Ultima luce"): Salotto · Tavoli · Tu.
//  Qui vivono anche la rivalutazione al ritorno in foreground e i toast.
//

import SwiftUI

struct RootTabView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.stanzaCorrente) {
            SalottoView()
                .tabItem { Label("tab.salotto", systemImage: "sofa") }
                .tag(AppStore.Stanza.salotto)
            TavoliView()
                .tabItem { Label("tab.tavoli", systemImage: "table.furniture") }
                .tag(AppStore.Stanza.tavoli)
            TuView()
                .tabItem { Label("tab.tu", systemImage: "person") }
                .tag(AppStore.Stanza.tu)
        }
        .tint(.brass)
        .overlay(alignment: .bottom) { toastOverlay }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.35), value: store.toast)
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

// MARK: - Aspetto di sistema (tab bar e barre di navigazione)

enum SystemAppearance {
    /// Tab bar sobria e barre di navigazione col titolo in Young Serif.
    /// Chiamata una volta all'avvio.
    @MainActor
    static func configure() {
        let background = UIColor(named: "Background") ?? .black
        let muted = UIColor(named: "TextMuted") ?? .gray
        let primary = UIColor(named: "TextPrimary") ?? .white
        let brass = UIColor(named: "Brass") ?? .orange
        let divider = UIColor(named: "Divider") ?? .darkGray

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(named: "FeltEdge") ?? background
        tab.shadowColor = divider
        let item = UITabBarItemAppearance()
        item.normal.iconColor = muted
        item.normal.titleTextAttributes = [.foregroundColor: muted]
        item.selected.iconColor = brass
        item.selected.titleTextAttributes = [.foregroundColor: brass]
        tab.stackedLayoutAppearance = item
        tab.inlineLayoutAppearance = item
        tab.compactInlineLayoutAppearance = item
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = background
        nav.shadowColor = .clear
        let titleFont = UIFont(name: "YoungSerif-Regular", size: 18) ?? .systemFont(ofSize: 17, weight: .semibold)
        nav.titleTextAttributes = [.foregroundColor: primary, .font: titleFont]
        nav.largeTitleTextAttributes = [.foregroundColor: primary]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = brass
    }
}
