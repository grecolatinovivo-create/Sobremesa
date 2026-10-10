//
//  OnboardingView.swift
//  Sobremesa
//
//  La soglia (v3 "Ultima luce"): il wordmark, la promessa in una riga,
//  il tavolo vuoto con la brace che respira, l'accesso con Apple.
//  Chi la vede deve capire in pochi secondi cos'è un tavolo.
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
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: Space.xl)

            VStack(spacing: Space.s) {
                Text(verbatim: "Sobremesa")
                    .font(AppFont.display(44, relativeTo: .largeTitle))
                    .foregroundStyle(Color.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("onboarding.tagline")
                    .font(AppFont.bodySerif(18, relativeTo: .title3))
                    .italic()
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: Space.xl)

            // Il tavolo apparecchiato: dodici posti vuoti, la brace accesa.
            TableGlyph(occupied: 0,
                       maxSeats: store.rules.maxFriends,
                       warmth: .viva,
                       size: 220,
                       breathing: true)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared || reduceMotion ? 1 : 0.96)

            Spacer(minLength: Space.xl)

            Text("onboarding.intro")
                .font(AppFont.bodySerif(17, relativeTo: .body))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Space.s)

            Spacer(minLength: Space.xl)

            if awaitingName {
                nameStep
            } else {
                signInStep
            }
        }
        .padding(.horizontal, Space.gutter)
        .padding(.bottom, Space.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
        .onAppear {
            withAnimation(reduceMotion ? .easeIn(duration: 0.2) : .easeOut(duration: 0.8)) {
                appeared = true
            }
        }
    }

    // MARK: Passo 1 — Sign in with Apple

    @ViewBuilder
    private var signInStep: some View {
        VStack(spacing: Space.m) {
            if showError || store.authError {
                // Errore inline, mai alert — e mai per un annullamento volontario.
                Text("onboarding.error")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.warning)
                    .multilineTextAlignment(.center)
            }

            SignInWithAppleButton(.continue) { request in
                // Solo il nome: niente email, niente tracciamento.
                request.requestedScopes = [.fullName]
            } onCompletion: { result in
                handle(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 52)
            .clipShape(Capsule())

            Text("onboarding.promesse")
                .font(AppFont.caption(12, relativeTo: .caption2))
                .foregroundStyle(Color.textMuted)
                .multilineTextAlignment(.center)

            Text("onboarding.privacy")
                .font(AppFont.caption(12, relativeTo: .caption2))
                .foregroundStyle(Color.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Apple 1.2: si entra accettando condizioni con tolleranza zero
            // verso i contenuti offensivi. I link (markdown) aprono il sito.
            Text("onboarding.termini")
                .font(AppFont.caption(12, relativeTo: .caption2))
                .foregroundStyle(Color.textMuted)
                .tint(.brass)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Passo 2 — il nome, se Apple non l'ha condiviso

    @ViewBuilder
    private var nameStep: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("onboarding.nome.hint")
                .font(AppFont.ui(15))
                .foregroundStyle(Color.textSecondary)
            TextField("onboarding.nome.placeholder", text: $draftName)
                .font(AppFont.bodySerif(18))
                .foregroundStyle(Color.textPrimary)
                .submitLabel(.done)
                .onSubmit { confirmName() }
                .padding(.horizontal, Space.l)
                .frame(minHeight: 52)
                .background(Color.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            if showNameError {
                Text("onboarding.nome.errore")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.warning)
            }
            Button("onboarding.nome.conferma") { confirmName() }
                .buttonStyle(PrimaryButtonStyle(fullWidth: true))
        }
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
