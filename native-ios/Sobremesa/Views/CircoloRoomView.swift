//
//  CircoloRoomView.swift
//  Sobremesa
//
//  La stanza del circolo: il luogo dove si sta. "Un circolo non si segue:
//  si abita" — e abitare vuol dire avere una conversazione tutta sua,
//  non post mescolati in un feed. Composer preimpostato sul circolo,
//  brace in testata, cronologia dei soli post di questo luogo.
//

import SwiftUI
import SwiftData

struct CircoloRoomView: View {
    @Environment(AppStore.self) private var store
    let circolo: Circolo

    @Query(sort: \Post.createdAt, order: .reverse) private var allPosts: [Post]
    @State private var text = ""
    @State private var category: PostCategory = .libro
    @State private var showEmptyError = false

    private var posts: [Post] {
        allPosts.filter { $0.circolo === circolo }
    }

    private var membership: Membership? {
        store.membership(of: circolo)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                header

                if membership != nil {
                    composer
                }

                if posts.isEmpty {
                    emptyState
                } else {
                    ForEach(posts) { post in
                        PostCard(post: post)
                    }
                }
            }
            .padding(16)
        }
        .background(Color.ink)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(circolo.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.ink, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    // MARK: Testata: chi siamo e come sta la brace

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: circolo.displayName)
                        .font(AppFont.title(24, relativeTo: .title2))
                        .foregroundStyle(Color.paperDim)
                        .accessibilityAddTraits(.isHeader)
                    Text(verbatim: circolo.displayTheme)
                        .font(AppFont.bodySerif(15, relativeTo: .subheadline))
                        .italic()
                        .foregroundStyle(Color.brassSoft)
                }
                Spacer()
                CategoryChip(category: circolo.category, onDark: true)
            }
            Text(verbatim: String.localizedStringWithFormat(
                String(localized: "circolo.membri.count", bundle: L10n.bundle), circolo.memberCount))
                .font(AppFont.caption())
                .foregroundStyle(Color.brassSoft)

            if let membership {
                if circolo.memberCount < store.rules.emberMinimumMembers {
                    // Da soli la brace non si valuta: lo diciamo, non lo nascondiamo.
                    Text("brace.attesa")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.brassSoft)
                } else {
                    RoomEmberLine(state: store.engine.emberState(
                        lastActivity: membership.lastActivity, now: .now))
                }
            }
        }
    }

    // MARK: Composer della stanza (destinazione già decisa: qui)

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("composer.placeholder", text: $text, axis: .vertical)
                .font(AppFont.bodySerif())
                .foregroundStyle(Color.ink)
                .lineLimit(1...5)
                .onChange(of: text) { _, newValue in
                    if !newValue.isEmpty { showEmptyError = false }
                }
            if showEmptyError {
                Text("composer.error.empty")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.errorTone)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(PostCategory.allCases) { cat in
                        Button {
                            category = cat
                        } label: {
                            CategoryChip(category: cat, isSelected: cat == category)
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: cat.labelKey.loc))
                        .accessibilityAddTraits(cat == category ? [.isSelected] : [])
                    }
                }
            }
            HStack {
                Spacer()
                Button("composer.publish") { publish() }
                    .buttonStyle(PillButtonStyle())
            }
        }
        .sobreCard()
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "flame")
                .font(.system(size: 30))
                .foregroundStyle(Color.brassSoft)
                .accessibilityHidden(true)
            Text("circolo.conversazione.empty")
                .font(AppFont.ui())
                .foregroundStyle(Color.brassSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func publish() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showEmptyError = true
            return
        }
        store.publish(text: trimmed, category: category, in: circolo)
        text = ""
        showEmptyError = false
    }
}

/// Riga di stato della brace, versione compatta per la testata della stanza.
private struct RoomEmberLine: View {
    let state: EmberState

    var body: some View {
        HStack(spacing: 6) {
            SwiftUI.Circle().fill(color).frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(verbatim: label)
                .font(AppFont.caption())
                .foregroundStyle(color)
        }
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch state {
        case .viva: return .successTone
        case .affievolita: return .brassSoft
        case .avviso, .espulsione: return .errorSoft
        }
    }

    private var label: String {
        switch state {
        case .viva:
            return String(localized: "brace.viva", bundle: L10n.bundle)
        case .affievolita(let giorni):
            return String.localizedStringWithFormat(String(localized: "brace.affievolita", bundle: L10n.bundle), giorni)
        case .avviso(let giorni), .espulsione(let giorni):
            return String.localizedStringWithFormat(String(localized: "brace.avviso", bundle: L10n.bundle), giorni)
        }
    }
}
