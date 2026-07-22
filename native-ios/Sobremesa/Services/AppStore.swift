//
//  AppStore.swift
//  Sobremesa
//
//  Lo store osservabile (MVVM, @Observable): le view leggono con @Query
//  e mutano SOLO attraverso questi metodi. Qui vivono anche i toast
//  (le notifiche in-app) e lo stato dell'invito in sospeso.
//

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppStore {

    /// Il backend (oggi locale, domani remoto): mai le view direttamente sui modelli.
    private let data: DataService

    /// Regole di prodotto correnti (unica fonte dei numeri di business).
    var rules: ProductRules { data.engine.rules }
    var engine: SobremesaEngine { data.engine }

    /// Toast corrente (notifica in-app).
    var toast: AppNotice?
    /// Persona con invito in sospeso (tavola piena): guida il pannello in Tavola.
    var pendingInvitee: Person?

    private var toastTask: Task<Void, Never>?

    init(data: DataService) {
        self.data = data
    }

    // MARK: Ciclo di vita

    func bootstrap() {
        data.bootstrapIfNeeded()
        pendingInvitee = data.pendingInvitee()
        show(notices: data.evaluateEmbers(now: .now))
    }

    /// A ogni ritorno in foreground il tempo reale viene rivalutato.
    func appBecameActive() {
        show(notices: data.evaluateEmbers(now: .now))
    }

    // MARK: Derivati

    var me: Person? { data.me() }
    var friendCount: Int { data.friendCount() }
    var myMemberships: [Membership] { data.myMemberships() }

    func membership(of circolo: Circolo) -> Membership? { data.membership(of: circolo) }

    /// Il post appartiene al mio feed? (solo amici e circoli abitati)
    func isInMyFeed(_ post: Post) -> Bool {
        if let circolo = post.circolo {
            return data.membership(of: circolo) != nil
        }
        return post.author?.isMe == true || post.author.map(data.isFriend) == true
    }

    // MARK: Salotto

    func publish(text: String, category: PostCategory, in circolo: Circolo?) {
        show(notices: data.publish(text: text, category: category, in: circolo))
    }

    func toggleNutre(on post: Post) {
        data.toggleNutre(on: post)
    }

    func addComment(to post: Post, text: String) {
        show(notices: data.addComment(to: post, text: text))
    }

    // MARK: Tavola

    func invite(_ person: Person) {
        switch data.invite(person) {
        case .seated:
            pendingInvitee = nil
            show(message: String(format: String(localized: "toast.seated"), person.name))
        case .tableFull:
            pendingInvitee = person
        }
    }

    func freeChair(_ friendship: Friendship) {
        show(notices: data.freeChair(friendship))
        pendingInvitee = data.pendingInvitee()
    }

    func cancelPendingInvite() {
        data.cancelPendingInvite()
        pendingInvitee = nil
    }

    // MARK: Circoli

    @discardableResult
    func joinCircle(_ circolo: Circolo) -> Bool {
        data.joinCircle(circolo)
    }

    func leaveCircle(_ circolo: Circolo) {
        data.leaveCircle(circolo)
    }

    func retakeWord(in circolo: Circolo) {
        show(notices: data.retakeWord(in: circolo))
    }

    func accept(_ request: JoinRequest) {
        show(notices: data.accept(request))
    }

    func decline(_ request: JoinRequest) {
        data.decline(request)
    }

    #if DEBUG
    /// Solo build DEBUG: simula N giorni di silenzio spostando indietro le date reali.
    func simulateSilence(days: Int) {
        show(notices: data.simulateSilence(days: days))
    }
    #endif

    // MARK: Profilo

    func resetDemoData() {
        data.resetDemoData()
        pendingInvitee = nil
        show(message: String(localized: "toast.reset"))
    }

    // MARK: Toast

    private func show(notices: [AppNotice]) {
        guard let first = notices.first else { return }
        // Se arrivano più notifiche insieme, le uniamo in un solo banner leggibile.
        let message = notices.count == 1
            ? first.message
            : notices.map(\.message).joined(separator: "\n")
        show(message: message)
    }

    private func show(message: String) {
        toastTask?.cancel()
        withAnimation { toast = AppNotice(message: message) }
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            withAnimation { self?.toast = nil }
        }
    }
}

// MARK: - Risoluzione delle chiavi di localizzazione dei contenuti seed

extension String {
    /// Risolve la stringa come chiave del String Catalog.
    /// Usata per i contenuti demo, che memorizzano chiavi e non testo.
    var loc: String {
        String(localized: String.LocalizationValue(self))
    }
}
