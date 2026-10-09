//
//  TavoliView.swift
//  Sobremesa
//
//  Tavoli (v3 "Ultima luce"): dove ci si siede. In cima il codice
//  ricevuto (la strada più corta), poi la ricerca e il catalogo come un
//  indice editoriale — ogni voce col suo piccolo tavolo e le sedie
//  contate — e, sempre a portata di pollice, "Fonda un tavolo".
//

import SwiftUI
import SwiftData

struct TavoliView: View {
    @Environment(AppStore.self) private var store
    @Query private var allTables: [Tavolo]
    @Query(sort: \Messaggio.createdAt, order: .reverse) private var allMessages: [Messaggio]

    @State private var searchText = ""
    @State private var redeemCode = ""
    @State private var showCreate = false
    @FocusState private var codeFocused: Bool

    /// Il catalogo: i tavoli dove NON siedo già, filtrati LIVE dalla ricerca
    /// (il server filtra a sua volta al submit, ma il campo risponde subito).
    private var catalogo: [Tavolo] {
        let miei = Set(store.myMemberships.compactMap { $0.tavolo?.persistentModelID })
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return allTables
            .filter { !miei.contains($0.persistentModelID) }
            .filter { query.isEmpty
                || $0.name.localizedStandardContains(query)
                || $0.theme.localizedStandardContains(query) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var puoSedersi: Bool {
        store.engine.canJoinCircle(currentCircleCount: store.myMemberships.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    ScreenTitle(titleKey: "tavoli.title", subtitleKey: "tavoli.motto")
                    codicePanel
                    ricerca
                    catalogoSection
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.l)
                .padding(.bottom, Space.xxl)
            }
            .screenBackground()
            .scrollDismissesKeyboard(.interactively)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { fondaBar }
            .sheet(isPresented: $showCreate) {
                CreateTableSheet()
            }
        }
    }

    // MARK: Hai un codice?

    private var codicePanel: some View {
        let empty = redeemCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return VStack(alignment: .leading, spacing: Space.m) {
            Text("tavoli.invito.title")
                .font(AppFont.title(20, relativeTo: .title3))
                .foregroundStyle(Color.textPrimary)
            HStack(spacing: Space.s) {
                TextField("invito.codice.campo", text: $redeemCode)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(Color.textPrimary)
                    .tint(.brass)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($codeFocused)
                    .submitLabel(.join)
                    .onSubmit(redeem)
                    .padding(.horizontal, Space.m)
                    .frame(minHeight: 48)
                    .background(Color.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(codeFocused ? Color.outline : Color.divider, lineWidth: 1))
                Button("invito.usa", action: redeem)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(empty)
            }
        }
        .panel()
    }

    private func redeem() {
        store.redeemInvite(code: redeemCode)
        redeemCode = ""
        codeFocused = false
    }

    // MARK: Ricerca

    private var ricerca: some View {
        HStack(spacing: Space.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textMuted)
                .accessibilityHidden(true)
            TextField("tavoli.cerca", text: $searchText)
                .font(AppFont.ui(16, relativeTo: .body))
                .foregroundStyle(Color.textPrimary)
                .tint(.brass)
                .submitLabel(.search)
                .onSubmit { store.syncNow(query: searchText) }
                .onChange(of: searchText) { _, newValue in
                    // Campo svuotato: il filtro server non deve restare appiccicato.
                    if newValue.isEmpty { store.syncNow(query: "") }
                }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textMuted)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel(Text("a11y.cerca.cancella"))
            }
        }
        .padding(.leading, Space.m)
        .frame(minHeight: 48)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: Il catalogo (indice editoriale)

    private var catalogoSection: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("tavoli.catalogo.section")
                .font(AppFont.title(20, relativeTo: .title3))
                .foregroundStyle(Color.textPrimary)
                .accessibilityAddTraits(.isHeader)

            if !puoSedersi {
                Text(verbatim: String.localizedStringWithFormat(
                    String(localized: "tavoli.pieni", bundle: L10n.bundle), store.rules.maxCircles))
                    .font(AppFont.caption(13))
                    .foregroundStyle(Color.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if catalogo.isEmpty {
                Text(searchText.isEmpty ? "tavoli.catalogo.vuoto" : "tavoli.catalogo.nessuno")
                    .font(AppFont.bodySerif(16, relativeTo: .callout))
                    .italic()
                    .foregroundStyle(Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, Space.m)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(catalogo.enumerated()), id: \.element.persistentModelID) { index, tavolo in
                        rigaCatalogo(tavolo)
                        if index < catalogo.count - 1 {
                            Hairline(inset: 44 + Space.l)
                        }
                    }
                }
            }
        }
    }

    private func rigaCatalogo(_ tavolo: Tavolo) -> some View {
        let ultimo = allMessages.first(where: { $0.tavolo === tavolo })?.createdAt
        let warmth = store.warmth(of: tavolo, lastMessageAt: ultimo)
        let pieno = tavolo.memberCount >= store.rules.maxFriends
        return HStack(alignment: .center, spacing: Space.l) {
            TableGlyph(occupied: tavolo.memberCount, maxSeats: store.rules.maxFriends,
                       warmth: warmth, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(verbatim: tavolo.name)
                        .font(AppFont.title(18, relativeTo: .headline))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(2)
                    if !tavolo.isOpen {
                        Image(systemName: "lock")
                            .imageScale(.small)
                            .foregroundStyle(Color.textMuted)
                            .accessibilityLabel(Text("a11y.tavolo.chiuso"))
                    }
                }
                Text(verbatim: tavolo.theme.isEmpty ? tavolo.category.labelKey.loc : tavolo.theme)
                    .font(AppFont.caption(13))
                    .foregroundStyle(Color.textMuted)
                    .lineLimit(2)
                Text(verbatim: "\(tavolo.category.labelKey.loc) · \(tavolo.memberCount)/\(store.rules.maxFriends)")
                    .font(AppFont.caption(12, relativeTo: .caption2).monospacedDigit())
                    .foregroundStyle(Color.textMuted)
            }
            Spacer(minLength: Space.s)
            Group {
                if pieno {
                    Text("tavoli.completo")
                        .font(AppFont.caption(13))
                        .foregroundStyle(Color.textMuted)
                } else if tavolo.isOpen {
                    Button("tavoli.siediti") { store.joinTable(tavolo) }
                        .buttonStyle(CompactPrimaryStyle())
                        .disabled(!puoSedersi)
                        .accessibilityLabel(Text(verbatim: String(
                            format: String(localized: "a11y.siediti", bundle: L10n.bundle), tavolo.name)))
                } else {
                    Button("tavoli.chiedi") { store.requestSeat(at: tavolo) }
                        .buttonStyle(CompactSecondaryStyle())
                        .disabled(!puoSedersi)
                }
            }
        }
        .padding(.vertical, Space.m)
        .frame(minHeight: 80)
    }

    // MARK: Fonda un tavolo (sempre a portata di pollice)

    private var fondaBar: some View {
        Button {
            showCreate = true
        } label: {
            Label("tavoli.fonda.title", systemImage: "plus")
        }
        .buttonStyle(PrimaryButtonStyle(fullWidth: true))
        .disabled(!puoSedersi)
        .padding(.horizontal, Space.gutter)
        .padding(.vertical, Space.s)
        .background(Color.background.opacity(0.97))
        .overlay(alignment: .top) { Hairline() }
    }
}

// MARK: - Bottoni compatti per le righe

struct CompactPrimaryStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.ui(14, relativeTo: .subheadline).weight(.semibold))
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.brass))
            .foregroundStyle(Color.brassInk)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.8 : (isEnabled ? 1 : 0.4))
    }
}

struct CompactSecondaryStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.ui(14, relativeTo: .subheadline).weight(.medium))
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.outline, lineWidth: 1))
            .foregroundStyle(Color.textSecondary)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : (isEnabled ? 1 : 0.4))
    }
}

// MARK: - Fonda un tavolo

private struct CreateTableSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var theme = ""
    @State private var category: PostCategory = .libro
    @State private var isOpen = true
    @State private var showEmptyError = false
    @FocusState private var nameFocused: Bool

    private let columns = [GridItem(.flexible(), spacing: Space.s), GridItem(.flexible(), spacing: Space.s)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    campo(label: "fonda.nome.label") {
                        TextField("fonda.nome", text: $name)
                            .font(AppFont.bodySerif(18, relativeTo: .body))
                            .focused($nameFocused)
                            .submitLabel(.next)
                    }
                    if showEmptyError {
                        Text("fonda.nome.errore")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.warning)
                            .padding(.top, -Space.l)
                    }

                    campo(label: "fonda.tema.label") {
                        TextField("fonda.tema", text: $theme, axis: .vertical)
                            .font(AppFont.bodySerif(16, relativeTo: .callout))
                            .lineLimit(1...3)
                    }

                    VStack(alignment: .leading, spacing: Space.s) {
                        SectionLabel(textKey: "fonda.categoria.label")
                        LazyVGrid(columns: columns, spacing: Space.s) {
                            ForEach(PostCategory.allCases) { cat in
                                Button {
                                    category = cat
                                } label: {
                                    CategoryChip(category: cat, isSelected: cat == category)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Text(verbatim: cat.labelKey.loc))
                                .accessibilityAddTraits(cat == category ? [.isSelected] : [])
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: Space.s) {
                        SectionLabel(textKey: "fonda.accesso.label")
                        Picker("fonda.accesso.label", selection: $isOpen) {
                            Text("fonda.aperto").tag(true)
                            Text("fonda.chiuso").tag(false)
                        }
                        .pickerStyle(.segmented)
                        Text(isOpen ? "fonda.aperto.hint" : "fonda.chiuso.hint")
                            .font(AppFont.caption(13))
                            .foregroundStyle(Color.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: Space.m) {
                        Button("fonda.conferma", action: create)
                            .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                        Text("fonda.chiosa")
                            .font(AppFont.bodySerif(15, relativeTo: .footnote))
                            .italic()
                            .foregroundStyle(Color.textMuted)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(Space.gutter)
            }
            .screenBackground()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text("fonda.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.textSecondary)
                    }
                    .accessibilityLabel(Text("confirm.cancel"))
                }
            }
            .onAppear { nameFocused = true }
        }
        .presentationBackground(Color.background)
    }

    private func campo<Content: View>(label: LocalizedStringKey,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel(textKey: label)
            content()
                .foregroundStyle(Color.textPrimary)
                .tint(.brass)
                .padding(.horizontal, Space.m)
                .padding(.vertical, 12)
                .frame(minHeight: 48)
                .background(Color.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                          category: category,
                          isOpen: isOpen)
        dismiss()
    }
}
