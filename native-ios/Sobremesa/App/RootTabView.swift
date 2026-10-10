//
//  RootTabView.swift
//  Sobremesa
//
//  Le 3 stanze dell'app (v3 "Ultima luce"): Salotto · Tavoli · Tu.
//  La barra in basso è solo tipografica: tre parole, niente icone
//  (feedback di Giampiero: le icone sembravano emoticon).
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
                .tabItem { Text("tab.salotto") }
                .tag(AppStore.Stanza.salotto)
            TavoliView()
                .tabItem { Text("tab.tavoli") }
                .tag(AppStore.Stanza.tavoli)
            TuView()
                .tabItem { Text("tab.tu") }
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
        // Solo parole, in Young Serif, centrate nella barra (senza icona il
        // titolo starebbe schiacciato in basso: lo si alza di 12 punti).
        let tabFont = UIFont(name: "YoungSerif-Regular", size: 17) ?? .systemFont(ofSize: 16, weight: .medium)
        item.normal.titleTextAttributes = [.foregroundColor: muted, .font: tabFont]
        item.selected.titleTextAttributes = [.foregroundColor: brass, .font: tabFont]
        item.normal.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: -12)
        item.selected.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: -12)
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
        // In cima allo scorrimento la barra è trasparente: la texture arriva
        // fino al bordo, senza la fascia piatta (feedback di Giampiero).
        let edge = UINavigationBarAppearance()
        edge.configureWithTransparentBackground()
        edge.titleTextAttributes = nav.titleTextAttributes
        UINavigationBar.appearance().scrollEdgeAppearance = edge
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = brass
    }
}
