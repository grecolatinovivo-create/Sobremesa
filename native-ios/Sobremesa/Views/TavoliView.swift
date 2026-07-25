//
//  TavoliView.swift
//  Sobremesa
//
//  Trovare un tavolo: il catalogo dei tavoli aperti (con ricerca),
//  il riscatto di un invito ricevuto, e la fondazione di un tavolo nuovo.
//  Le conversazioni vivono nel Salotto: qui ci si siede.
//

import SwiftUI
import SwiftData

struct TavoliView: View {
    @Environment(AppStore.self) private var store
    @Query private var allTables: [Tavolo]

    @State private var searchText = ""
    @State private var redeemCode = ""
    @State private var showCreate = false

    /// Il catalogo: i tavoli dove NON siedo già.
    private var catalogo: [Tavolo] {
        let miei = Set(store.myMemberships.compactMap { $0.tavolo?.persistentModelID })
        return allTables
            .filter { !miei.contains($0.persistentModelID) }
            .sorted { $0.name < $1.name }
    }

    private var puoSedersi: Bool {
        store.engine.canJoinCircle(currentCircleCount: store.myMemberships.count)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Text("tavoli.title")
                    .font(AppFont.display())
                    .foregroundStyle(Color.paperDim)
                    .accessibilityAddTraits(.isHeader)

                Text("tavoli.motto")
                    .font(AppFont.bodySerif(15, relativeTo: .subheadline))
                    .italic()
                    .foregroundStyle(Color.brassSoft)

                fondaCard
                invitoCard
                catalogoSection
            }
            .padding(16)
        }
        .background(Color.ink)
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showCreate) {
            CreateTableSheet()
        }
    }

    // MARK: Fondare un tavolo

    private var fondaCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("tavoli.fonda.title")
                .font(AppFont.ui(15, relativeTo: .subheadline))
                .foregroundStyle(Color.ink)
            Text(verbatim: String.localizedStringWithFormat(
                String(localized: "tavoli.fonda.hint", bundle: L10n.bundle),
                store.rules.maxFriends, store.rules.maxCircles))
                .font(AppFont.caption())
                .foregroundStyle(Color.felt)
                .fixedSize(horizontal: false, vertical: true)
            Button("tavoli.fonda.cta") { showCreate = true }
                .buttonStyle(PillButtonStyle())
                .disabled(!puoSedersi)
            if !puoSedersi {
                Text(verbatim: String.localizedStringWithFormat(
                    String(localized: "tavoli.pieni", bundle: L10n.bundle), store.rules.maxCircles))
                    .font(AppFont.caption())
                    .foregroundStyle(Color.errorTone)
            }
        }
        .sobreCard(.paperDim)
    }

    // MARK: Un invito ricevuto

    private var invitoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("tavoli.invito.title")
                .font(AppFont.ui(15, relativeTo: .subheadline))
                .foregroundStyle(Color.ink)
            HStack(spacing: 8) {
                TextField("invito.codice.campo", text: $redeemCode)
                    .font(AppFont.ui())
                    .foregroundStyle(Color.ink)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Button("invito.usa") {
                    store.redeemInvite(code: redeemCode)
                    redeemCode = ""
                }
                .buttonStyle(QuietPillButtonStyle(tint: .felt))
                .disabled(redeemCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .sobreCard(.paperDim)
    }

    // MARK: Catalogo dei tavoli aperti

    private var catalogoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(textKey: "tavoli.catalogo.section")

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.felt)
                    .accessibilityHidden(true)
                TextField("tavoli.cerca", text: $searchText)
                    .font(AppFont.ui())
                    .foregroundStyle(Color.ink)
                    .submitLabel(.search)
                    .onSubmit { store.syncNow(query: searchText) }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Color.paperDim, in: RoundedRectangle(cornerRadius: 12))

            if catalogo.isEmpty {
                Text("tavoli.catalogo.vuoto")
                    .font(AppFont.ui())
                    .foregroundStyle(Color.brassSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 12)
            }

            ForEach(catalogo, id: \.persistentModelID) { tavolo in
                rigaCatalogo(tavolo)
            }
        }
    }

    private func rigaCatalogo(_ tavolo: Tavolo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: tavolo.category.symbolName)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.brass)
                    .frame(width: 32, height: 32)
                    .background(Color.felt.opacity(0.15), in: SwiftUI.Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: tavolo.name)
                        .font(AppFont.ui(15, relativeTo: .subheadline))
                        .foregroundStyle(Color.ink)
                    if !tavolo.theme.isEmpty {
                        Text(verbatim: tavolo.theme)
                            .font(AppFont.caption())
                            .foregroundStyle(Color.felt)
                            .lineLimit(2)
                    }
                    Text(verbatim: "\(tavolo.memberCount)/\(store.rules.maxFriends)")
                        .font(AppFont.caption(12, relativeTo: .caption2))
                        .foregroundStyle(Color.felt.opacity(0.8))
                }
                Spacer()
            }
            HStack {
                Spacer()
                if tavolo.memberCount >= store.rules.maxFriends {
                    Text("tavoli.completo")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.felt)
                } else if tavolo.isOpen {
                    Button("tavoli.siediti") { store.joinTable(tavolo) }
                        .buttonStyle(PillButtonStyle())
                        .disabled(!puoSedersi)
                        .accessibilityLabel(Text(verbatim: String(
                            format: String(localized: "a11y.siediti", bundle: L10n.bundle), tavolo.name)))
                } else {
                    Button("tavoli.chiedi") { store.requestSeat(at: tavolo) }
                        .buttonStyle(QuietPillButtonStyle(tint: .felt))
                        .disabled(!puoSedersi)
                }
            }
        }
        .sobreCard()
    }
}

// MARK: - Fondazione di un tavolo

private struct CreateTableSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var theme = ""
    @State private var category: PostCategory = .libro
    @State private var showEmptyError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("fonda.spiega")
                        .font(AppFont.ui(14, relativeTo: .footnote))
                        .foregroundStyle(Color.brassSoft)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 10) {
                        TextField("fonda.nome", text: $name)
                            .font(AppFont.bodySerif())
                            .foregroundStyle(Color.ink)
                        if showEmptyError {
                            Text("fonda.nome.errore")
                                .font(AppFont.caption())
                                .foregroundStyle(Color.errorTone)
                        }
                        Divider().overlay(Color.felt.opacity(0.2))
                        TextField("fonda.tema", text: $theme, axis: .vertical)
                            .font(AppFont.bodySerif(15, relativeTo: .subheadline))
                            .foregroundStyle(Color.ink)
                            .lineLimit(1...3)
                    }
                    .sobreCard()

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

                    Button("fonda.conferma") { create() }
                        .buttonStyle(PillButtonStyle())
                }
                .padding(16)
            }
            .background(Color.ink)
            .navigationTitle(Text("fonda.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.ink, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("confirm.cancel") { dismiss() }
                }
            }
        }
    }

    private func create() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            showEmptyError = true
            return
        }
        store.createTable(name: cleanName,
                          theme: theme.trimmingCharacters(in: .whitespacesAndNewlines),
                          category: category)
        dismiss()
    }
}
