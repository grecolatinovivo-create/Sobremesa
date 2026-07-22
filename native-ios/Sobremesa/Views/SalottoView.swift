//
//  SalottoView.swift
//  Sobremesa
//
//  Il feed: composer in alto, poi i post — SOLO amici e circoli abitati,
//  in ordine cronologico. Niente algoritmo, niente vanity metrics.
//

import SwiftUI
import SwiftData

struct SalottoView: View {
    @Environment(AppStore.self) private var store
    @Query(sort: \Post.createdAt, order: .reverse) private var allPosts: [Post]

    /// Solo il mio salotto: amici e circoli abitati, cronologico.
    private var feed: [Post] {
        allPosts.filter { store.isInMyFeed($0) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Text("salotto.title")
                    .font(AppFont.display())
                    .foregroundStyle(Color.paperDim)
                    .accessibilityAddTraits(.isHeader)

                ComposerCard()

                if showFirstSteps {
                    firstSteps
                }

                if feed.isEmpty {
                    emptyState
                } else {
                    ForEach(feed) { post in
                        PostCard(post: post)
                    }
                }
            }
            .padding(16)
        }
        .background(Color.ink)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Primi passi (cold start): un percorso, non tre stanze vuote

    private var hasMyPost: Bool {
        allPosts.contains { $0.author?.isMe == true }
    }

    private var showFirstSteps: Bool {
        !hasMyPost || store.myMemberships.isEmpty
    }

    private var firstSteps: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("passi.title")
                .font(AppFont.title(17, relativeTo: .headline))
                .foregroundStyle(Color.ink)
            stepRow(done: hasMyPost, key: "passi.post")
            stepRow(done: !store.myMemberships.isEmpty, key: "passi.circolo")
            stepRow(done: false, key: "passi.brace")
        }
        .sobreCard(.paperDim)
    }

    private func stepRow(done: Bool, key: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Color.successTone : Color.felt)
                .accessibilityLabel(Text(done ? "a11y.passo.fatto" : "a11y.passo.dafare"))
            Text(key)
                .font(AppFont.ui(14, relativeTo: .footnote))
                .foregroundStyle(Color.ink)
        }
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "cup.and.saucer")
                .font(.system(size: 34))
                .foregroundStyle(Color.brassSoft)
                .accessibilityHidden(true)
            Text("feed.empty.title")
                .font(AppFont.title(20, relativeTo: .title3))
                .foregroundStyle(Color.paperDim)
            Text("feed.empty.subtitle")
                .font(AppFont.ui())
                .foregroundStyle(Color.brassSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - Composer

/// "Cosa ti ha nutrito oggi?" — testo, categoria a chip, destinazione, pubblica.
/// L'errore per testo vuoto è INLINE, mai un alert.
private struct ComposerCard: View {
    @Environment(AppStore.self) private var store
    @State private var text = ""
    @State private var category: PostCategory = .libro
    @State private var destination: Circolo?
    @State private var showEmptyError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("composer.placeholder", text: $text, axis: .vertical)
                .font(AppFont.bodySerif())
                .foregroundStyle(Color.ink)
                .lineLimit(1...5)
                .onChange(of: text) { _, newValue in
                    if !newValue.isEmpty { showEmptyError = false }
                }

            if showEmptyError {
                // Errore inline, mai alert.
                Text("composer.error.empty")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.errorTone)
                    .accessibilityAddTraits(.updatesFrequently)
            }

            categoryPicker
            HStack {
                destinationMenu
                Spacer()
                Button("composer.publish") { publish() }
                    .buttonStyle(PillButtonStyle())
                    .accessibilityHint(Text("a11y.publish.hint"))
            }
        }
        .sobreCard()
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(PostCategory.allCases) { cat in
                    Button {
                        category = cat
                    } label: {
                        CategoryChip(category: cat, isSelected: cat == category)
                            .frame(minHeight: 44) // tap target
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: cat.labelKey.loc))
                    .accessibilityAddTraits(cat == category ? [.isSelected] : [])
                }
            }
        }
    }

    /// Dove pubblicare: alla tavola (amici) o in uno dei circoli abitati.
    private var destinationMenu: some View {
        Menu {
            Button {
                destination = nil
            } label: {
                Label("composer.dest.tavola", systemImage: "table.furniture")
            }
            ForEach(store.myMemberships, id: \.persistentModelID) { membership in
                if let circolo = membership.circolo {
                    Button {
                        destination = circolo
                    } label: {
                        Label { Text(verbatim: circolo.displayName) } icon: {
                            Image(systemName: circolo.category.symbolName)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: destination?.category.symbolName ?? "table.furniture")
                    .font(.system(size: 12))
                Text(verbatim: destination.map { $0.displayName }
                     ?? String(localized: "composer.dest.tavola", bundle: L10n.bundle))
                    .font(AppFont.caption())
                Image(systemName: "chevron.down")
                    .font(.system(size: 9))
            }
            .foregroundStyle(Color.felt)
            .frame(minHeight: 44)
        }
        .accessibilityLabel(Text("a11y.destination"))
        .accessibilityValue(Text(verbatim: destination.map { $0.displayName }
                                 ?? String(localized: "composer.dest.tavola", bundle: L10n.bundle)))
    }

    private func publish() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showEmptyError = true
            return
        }
        // Se nel frattempo il circolo scelto non è più abitato, si pubblica alla tavola.
        let target = destination.flatMap { store.membership(of: $0) != nil ? $0 : nil }
        store.publish(text: trimmed, category: category, in: target)
        text = ""
        showEmptyError = false
        destination = nil
    }
}

// MARK: - Card di un post

struct PostCard: View {
    @Environment(AppStore.self) private var store
    let post: Post
    @State private var commentsExpanded = false
    @State private var commentText = ""

    private var sortedComments: [Comment] {
        post.comments.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Text(verbatim: post.isSeedContent ? post.text.loc : post.text)
                .font(AppFont.bodySerif())
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            actions
            if commentsExpanded {
                commentsSection
            }
        }
        .sobreCard()
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(initials: post.author?.initials ?? "?")
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: post.author?.name ?? "—")
                    .font(AppFont.ui(15, relativeTo: .subheadline))
                    .foregroundStyle(Color.ink)
                HStack(spacing: 4) {
                    Text(verbatim: provenance)
                    Text(verbatim: "·")
                    Text(post.createdAt, format: .relative(presentation: .named))
                }
                .font(AppFont.caption(12, relativeTo: .caption2))
                .foregroundStyle(Color.felt.opacity(0.8))
            }
            Spacer()
            CategoryChip(category: post.category)
        }
    }

    private var provenance: String {
        if let circolo = post.circolo {
            return String(format: String(localized: "post.provenance.circolo", bundle: L10n.bundle), circolo.displayName)
        }
        return String(localized: "post.provenance.tavola", bundle: L10n.bundle)
    }

    private var actions: some View {
        HStack(spacing: 18) {
            nutreButton
            commentsToggle
            Spacer()
        }
    }

    /// "Nutre": toggle con contatore, mai doppio conteggio.
    private var nutreButton: some View {
        Button {
            store.toggleNutre(on: post)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: post.nutritoDaMe ? "leaf.fill" : "leaf")
                Text("post.nutre")
                    .font(AppFont.caption())
                Text(verbatim: "\(post.nutreCount + (post.nutritoDaMe ? 1 : 0))")
                    .font(AppFont.caption())
            }
            .foregroundStyle(post.nutritoDaMe ? Color.successTone : Color.felt)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(post.nutritoDaMe ? "a11y.nutre.on" : "a11y.nutre.off"))
        .accessibilityValue(Text(verbatim: "\(post.nutreCount + (post.nutritoDaMe ? 1 : 0))"))
    }

    private var commentsToggle: some View {
        Button {
            withAnimation { commentsExpanded.toggle() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "bubble.left")
                Text(verbatim: String.localizedStringWithFormat(
                    String(localized: "post.comments.count", bundle: L10n.bundle), post.comments.count))
                    .font(AppFont.caption())
                Image(systemName: commentsExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9))
            }
            .foregroundStyle(Color.felt)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("a11y.comments.toggle"))
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().overlay(Color.felt.opacity(0.2))
            ForEach(sortedComments, id: \.persistentModelID) { comment in
                HStack(alignment: .top, spacing: 8) {
                    AvatarView(initials: comment.author?.initials ?? "?", size: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: comment.author?.name ?? "—")
                            .font(AppFont.caption(12, relativeTo: .caption2))
                            .foregroundStyle(Color.felt)
                        Text(verbatim: comment.isSeedContent ? comment.text.loc : comment.text)
                            .font(AppFont.bodySerif(15, relativeTo: .subheadline))
                            .foregroundStyle(Color.ink)
                    }
                }
            }
            commentForm
        }
    }

    /// Form inline per commentare. Commentare in un circolo azzera il silenzio.
    private var commentForm: some View {
        HStack(spacing: 8) {
            TextField("post.comment.placeholder", text: $commentText)
                .font(AppFont.bodySerif(15, relativeTo: .subheadline))
                .foregroundStyle(Color.ink)
            Button("post.comment.send") { sendComment() }
                .buttonStyle(QuietPillButtonStyle(tint: .felt))
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func sendComment() {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.addComment(to: post, text: trimmed)
        commentText = ""
    }
}
