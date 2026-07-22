//
//  TuView.swift
//  Sobremesa
//
//  Lo specchio: nome, bio, punteggio con fascia, il manifesto del prodotto,
//  la lingua dell'app (segue il sistema) e l'azzeramento dei dati demo.
//

import SwiftUI
import SwiftData

struct TuView: View {
    @Environment(AppStore.self) private var store
    @Query(filter: #Predicate<Person> { $0.isMe }) private var meQuery: [Person]

    @State private var confirmReset = false
    @State private var draftName = ""

    private var me: Person? { meQuery.first }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Text("tu.title")
                    .font(AppFont.display())
                    .foregroundStyle(Color.paperDim)
                    .accessibilityAddTraits(.isHeader)

                if let me {
                    profileCard(me)
                }

                manifestoCard
                languageCard
                creditsCard
                resetButton
            }
            .padding(16)
        }
        .background(Color.ink)
        .confirmationDialog(Text("tu.reset.confirm.title"),
                            isPresented: $confirmReset,
                            titleVisibility: .visible) {
            Button("tu.reset.confirm.action", role: .destructive) {
                store.resetAllData()
            }
            Button("confirm.cancel", role: .cancel) { confirmReset = false }
        } message: {
            Text("tu.reset.confirm.message")
        }
    }

    private func profileCard(_ me: Person) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                AvatarView(initials: me.initials, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    // Il nome è tuo: si corregge quando vuoi (Apple lo dà solo
                    // alla prima autorizzazione, e a volte nemmeno).
                    TextField("tu.nome.placeholder", text: $draftName)
                        .font(AppFont.title(22, relativeTo: .title2))
                        .foregroundStyle(Color.ink)
                        .submitLabel(.done)
                        .onAppear { draftName = me.name }
                        .onSubmit { store.updateName(draftName) }
                        .accessibilityLabel(Text("tu.nome.placeholder"))
                    ScoreBadge(score: me.score, band: store.engine.band(for: me.score))
                }
            }
            if let bioKey = me.bioKey {
                Text(verbatim: bioKey.loc)
                    .font(AppFont.bodySerif(15, relativeTo: .subheadline))
                    .foregroundStyle(Color.felt)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !me.interestKeys.isEmpty {
                Text(verbatim: me.interestKeys.map(\.loc).joined(separator: ", "))
                    .font(AppFont.caption())
                    .foregroundStyle(Color.felt)
            }
        }
        .sobreCard()
    }

    /// Il manifesto: perché la scarsità è la feature.
    private var manifestoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("tu.manifesto.title")
                .font(AppFont.title(19, relativeTo: .title3))
                .foregroundStyle(Color.ink)
            Text("tu.manifesto.text")
                .font(AppFont.bodySerif(15, relativeTo: .subheadline))
                .foregroundStyle(Color.felt)
                .fixedSize(horizontal: false, vertical: true)
        }
        .sobreCard()
    }

    /// Il multilingua interno: di serie l'app segue il telefono, ma da qui
    /// la lingua si sceglie a mano e cambia subito, senza riavviare.
    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("tu.lingua.label")
                .font(AppFont.ui(15, relativeTo: .subheadline))
                .foregroundStyle(Color.ink)
            Text("tu.lingua.hint")
                .font(AppFont.caption())
                .foregroundStyle(Color.felt)
                .fixedSize(horizontal: false, vertical: true)
            Menu {
                Picker("tu.lingua.label", selection: Binding(
                    get: { store.language },
                    set: { store.language = $0 }
                )) {
                    Text("tu.lingua.sistema").tag(AppLanguage.system)
                    // Gli endonimi non si traducono: ognuno riconosce la sua.
                    ForEach(AppLanguage.choices, id: \.self) { lingua in
                        Text(verbatim: lingua.endonym).tag(lingua)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    if store.language == .system {
                        Text("tu.lingua.sistema")
                    } else {
                        Text(verbatim: store.language.endonym)
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .font(AppFont.ui(14, relativeTo: .subheadline))
            }
            .buttonStyle(QuietPillButtonStyle(tint: .felt))
            .accessibilityLabel(Text("tu.lingua.label"))
            .accessibilityValue(store.language == .system
                ? Text("tu.lingua.sistema")
                : Text(verbatim: store.language.endonym))
        }
        .sobreCard(.paperDim)
    }

    /// Riconoscimenti: i caratteri OFL viaggiano con la loro licenza (nel bundle).
    private var creditsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("tu.riconoscimenti.title")
                .font(AppFont.ui(15, relativeTo: .subheadline))
                .foregroundStyle(Color.ink)
            Text("tu.riconoscimenti.text")
                .font(AppFont.caption())
                .foregroundStyle(Color.felt)
                .fixedSize(horizontal: false, vertical: true)
        }
        .sobreCard(.paperDim)
    }

    private var resetButton: some View {
        Button("tu.reset") { confirmReset = true }
            .buttonStyle(QuietPillButtonStyle(tint: .errorTone))
            .frame(maxWidth: .infinity)
    }
}
