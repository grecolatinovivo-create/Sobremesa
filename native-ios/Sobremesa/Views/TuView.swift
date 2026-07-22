//
//  TuView.swift
//  Sobremesa
//
//  Lo specchio: nome, bio, punteggio con fascia, il manifesto del prodotto,
//  la lingua dell'app (segue il sistema) e l'azzeramento dei dati demo.
//

import SwiftUI
import SwiftData
import UIKit

struct TuView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.openURL) private var openURL
    @Query(filter: #Predicate<Person> { $0.isMe }) private var meQuery: [Person]

    @State private var confirmReset = false

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
                resetButton
            }
            .padding(16)
        }
        .background(Color.ink)
        .confirmationDialog(Text("tu.reset.confirm.title"),
                            isPresented: $confirmReset,
                            titleVisibility: .visible) {
            Button("tu.reset.confirm.action", role: .destructive) {
                store.resetDemoData()
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
                    Text(verbatim: me.name)
                        .font(AppFont.title(22, relativeTo: .title2))
                        .foregroundStyle(Color.ink)
                    ScoreBadge(score: me.score, band: store.engine.band(for: me.score))
                }
            }
            if let bioKey = me.bioKey {
                Text(verbatim: bioKey.loc)
                    .font(AppFont.bodySerif(15, relativeTo: .subheadline))
                    .foregroundStyle(Color.felt)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(verbatim: me.interestKeys.map(\.loc).joined(separator: ", "))
                .font(AppFont.caption())
                .foregroundStyle(Color.felt)
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

    /// La lingua dell'app segue quella del dispositivo (String Catalog):
    /// da qui si apre la scheda dell'app nelle Impostazioni di sistema.
    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("tu.lingua.label")
                .font(AppFont.ui(15, relativeTo: .subheadline))
                .foregroundStyle(Color.ink)
            Text("tu.lingua.hint")
                .font(AppFont.caption())
                .foregroundStyle(Color.felt)
                .fixedSize(horizontal: false, vertical: true)
            Button("tu.lingua.apri") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(QuietPillButtonStyle(tint: .felt))
        }
        .sobreCard(.paperDim)
    }

    private var resetButton: some View {
        Button("tu.reset") { confirmReset = true }
            .buttonStyle(QuietPillButtonStyle(tint: .errorTone))
            .frame(maxWidth: .infinity)
    }
}
