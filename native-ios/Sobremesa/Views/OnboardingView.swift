//
//  OnboardingView.swift
//  Sobremesa
//
//  Il primo accesso: Sign in with Apple, il nome vero, la tavola vuota.
//  Nessun dato finto: da qui in poi tutto quello che c'è l'hai messo tu.
//

import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @State private var showError = false
    /// Apple fornisce il nome solo alla prima autorizzazione: se manca
    /// (reinstallazioni, reset), lo chiediamo — niente profili chiamati "Tu".
    @State private var awaitingName = false
    @State private var pendingAppleID: String?
    @State private var pendingIdentityToken: String?
    @State private var draftName = ""
    @State private var showNameError = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Text("onboarding.tagline")
                .font(AppFont.bodySerif(16, relativeTo: .subheadline))
                .italic()
                .foregroundStyle(Color.brassSoft)
                .multilineTextAlignment(.center)

            Text(verbatim: "Sobremesa")
                .font(AppFont.display(44, relativeTo: .largeTitle))
                .foregroundStyle(Color.paper)
                .accessibilityAddTraits(.isHeader)

            // La tavola, ancora tutta da apparecchiare.
            TableRingView(friends: [], maxChairs: store.rules.maxFriends, height: 230)

            Text("onboarding.intro")
                .font(AppFont.ui())
                .foregroundStyle(Color.paperDim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            if awaitingName {
                nameStep
            } else {
                signInStep
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ink.ignoresSafeArea())
    }

    // MARK: Passo 1 — Sign in with Apple

    @ViewBuilder
    private var signInStep: some View {
        if showError || store.authError {
            // Errore inline, mai alert — e mai per un annullamento volontario.
            Text("onboarding.error")
                .font(AppFont.caption())
                .foregroundStyle(Color.errorSoft)
        }

        SignInWithAppleButton(.signIn) { request in
            // Solo il nome: niente email, niente tracciamento.
            request.requestedScopes = [.fullName]
        } onCompletion: { result in
            handle(result)
        }
        .signInWithAppleButtonStyle(.white)
        .frame(height: 50)

        Text("onboarding.privacy")
            .font(AppFont.caption(12, relativeTo: .caption2))
            .foregroundStyle(Color.brassSoft)
            .multilineTextAlignment(.center)

        #if DEBUG
        // Solo sviluppo: il vecchio mondo demo, per esercitare le meccaniche.
        Button("debug.seed") { store.seedDemoWorld() }
            .buttonStyle(QuietPillButtonStyle())
        #endif
    }

    // MARK: Passo 2 — il nome, se Apple non l'ha condiviso

    @ViewBuilder
    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("onboarding.nome.hint")
                .font(AppFont.caption())
                .foregroundStyle(Color.felt)
            TextField("onboarding.nome.placeholder", text: $draftName)
                .font(AppFont.bodySerif())
                .foregroundStyle(Color.ink)
                .submitLabel(.done)
                .onSubmit { confirmName() }
            if showNameError {
                Text("onboarding.nome.errore")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.errorTone)
            }
        }
        .sobreCard()

        Button("onboarding.nome.conferma") { confirmName() }
            .buttonStyle(PillButtonStyle())
    }

    // MARK: Logica

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                showError = true
                return
            }
            showError = false
            // Il token di identità va al server, che verifica la firma di Apple.
            let identityToken = credential.identityToken.flatMap { String(data: $0, encoding: .utf8) }
            let name = credential.fullName.map {
                PersonNameComponentsFormatter.localizedString(from: $0, style: .medium)
            } ?? ""
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Login successivo: Apple non ridà il nome. Lo chiediamo noi.
                pendingAppleID = credential.user
                pendingIdentityToken = identityToken
                withAnimation { awaitingName = true }
            } else {
                store.completeOnboarding(name: name, appleUserID: credential.user,
                                         identityToken: identityToken)
            }
        case .failure(let error):
            // Annullare non è un errore: nessun rimprovero per una scelta.
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                showError = false
            } else {
                showError = true
            }
        }
    }

    private func confirmName() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showNameError = true
            return
        }
        store.completeOnboarding(name: trimmed, appleUserID: pendingAppleID,
                                 identityToken: pendingIdentityToken)
    }
}
