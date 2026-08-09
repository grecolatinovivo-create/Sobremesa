//
//  TavoloRoomView.swift
//  Sobremesa
//
//  Il tavolo: LA stanza di Sobremesa. Si parla come a cena — il filo
//  del discorso scorre dall'alto in basso, si scrive in fondo, sul
//  messaggio degli altri si può fare "Nutre". La testata (sedie, brace)
//  è FISSA in alto: la conversazione scorre, il contesto resta.
//

import SwiftUI
import SwiftData

struct TavoloRoomView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let tavolo: Tavolo

    @Query(sort: \Messaggio.createdAt) private var allMessages: [Messaggio]
    @Query private var allMemberships: [Membership]
    @Query private var allTables: [Tavolo]

    @State private var draft = ""
    @State private var inviteCode: String?
    @State private var showInvite = false
    @State private var showMembers = false
    @State private var confirmLeave = false

    /// Il tavolo esiste ancora? (l'animatore può averlo chiuso durante un sync)
    private var isAlive: Bool {
        allTables.contains { $0 === tavolo }
    }

    /// La conversazione di QUESTO tavolo, in ordine di discorso.
    private var messaggi: [Messaggio] {
        allMessages.filter { $0.tavolo === tavolo }
    }

    private var membership: Membership? {
        store.membership(of: tavolo)
    }

    /// Chi siede al tavolo (me compreso), per l'anello e la lista.
    private var commensali: [Person] {
        allMemberships
            .filter { $0.tavolo === tavolo }
            .sorted { $0.joinedAt < $1.joinedAt }
            .compactMap(\.person)
    }

    private var soloAlTavolo: Bool {
        tavolo.memberCount < store.rules.emberMinimumMembers
    }

    var body: some View {
        Group {
            if isAlive {
                conversazione
            } else {
                // Il tavolo si è chiuso mentre eravamo qui: nessun crash, una spiegazione.
                VStack(spacing: 10) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 30))
                        .foregroundStyle(Color.brassSoft)
                        .accessibilityHidden(true)
                    Text("stanza.chiusa")
                        .font(AppFont.ui())
                        .foregroundStyle(Color.brassSoft)
                        .multilineTextAlignment(.center)
                    Button("stanza.chiusa.torna") { dismiss() }
                        .buttonStyle(PillButtonStyle())
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.ink)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.ink, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var conversazione: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if soloAlTavolo {
                        invitaCard
                    }
                    if messaggi.isEmpty {
                        emptyState
                    } else {
                        ForEach(messaggi, id: \.persistentModelID) { messaggio in
                            MessageBubble(messaggio: messaggio)
                                .id(messaggio.persistentModelID)
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.ink)
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .onChange(of: messaggi.count) {
                store.markRead(tavolo)
                if let last = messaggi.last {
                    withAnimation { proxy.scrollTo(last.persistentModelID, anchor: .bottom) }
                }
            }
        }
        .safeAreaInset(edge: .top) { topBar }
        .safeAreaInset(edge: .bottom) {
            if membership != nil {
                inputBar
            }
        }
        .navigationTitle(tavolo.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { tableMenu }
        }
        .sheet(isPresented: $showMembers) { membersSheet }
        .sheet(isPresented: $showInvite) { inviteSheet }
        .onAppear { store.markRead(tavolo) }
        .onDisappear { if isAlive { store.markRead(tavolo) } }
        .confirmationDialog(
            Text(tavolo.animatedByMe ? "conferma.chiudi.title" : "conferma.alzati.title"),
            isPresented: $confirmLeave, titleVisibility: .visible
        ) {
            Button(tavolo.animatedByMe ? "conferma.chiudi.azione" : "conferma.alzati.azione",
                   role: .destructive) {
                store.leaveTable(tavolo)
                dismiss()
            }
            Button("confirm.cancel", role: .cancel) { confirmLeave = false }
        } message: {
            Text(tavolo.animatedByMe ? "conferma.chiudi.message" : "conferma.alzati.message")
        }
    }

    // MARK: Testata fissa: il contesto non scorre via

    private var emberState: EmberState? {
        guard let membership, !soloAlTavolo else { return nil }
        return store.engine.emberState(lastActivity: membership.lastActivity, now: .now)
    }

    private var braceInAvviso: Bool {
        if case .avviso = emberState { return true }
        if case .espulsione = emberState { return true }
        return false
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !tavolo.theme.isEmpty {
                Text(verbatim: tavolo.theme)
                    .font(AppFont.bodySerif(14, relativeTo: .footnote))
                    .italic()
                    .foregroundStyle(Color.brassSoft)
                    .lineLimit(1)
            }
            HStack(spacing: 12) {
                Button {
                    showMembers = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2")
                            .font(AppFont.caption())
                            .accessibilityHidden(true)
                        Text(verbatim: "\(tavolo.memberCount)/\(store.rules.maxFriends)")
                            .font(AppFont.caption())
                    }
                    .foregroundStyle(Color.brassSoft)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel(Text("a11y.commensali"))

                if let membership {
                    if soloAlTavolo {
                        Text("brace.attesa")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.brassSoft)
                    } else {
                        EmberLine(state: store.engine.emberState(
                                    lastActivity: membership.lastActivity, now: .now),
                                  sinceDays: giorniAlTavolo)
                    }
                }
                Spacer()
                if braceInAvviso {
                    // La brace langue: due vie, riprendere la parola o portare
                    // una voce nuova (audit neuromarketing #12).
                    Button("azione.riprendi.breve") { store.retakeWord(at: tavolo) }
                        .buttonStyle(QuietPillButtonStyle(tint: .brassSoft))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ink.opacity(0.97))
        .overlay(alignment: .bottom) {
            Divider().overlay(Color.felt.opacity(0.4))
        }
    }

    private var giorniAlTavolo: Int? {
        guard let membership else { return nil }
        let giorni = Int(Date.now.timeIntervalSince(membership.joinedAt) / 86_400)
        return giorni >= 1 ? giorni : nil
    }

    // MARK: Da soli: la strada è invitare, non parlarsi addosso

    private var invitaCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("stanza.soli.title")
                .font(AppFont.ui(15, relativeTo: .subheadline))
                .foregroundStyle(Color.ink)
            Text("stanza.soli.testo")
                .font(AppFont.caption())
                .foregroundStyle(Color.felt)
                .fixedSize(horizontal: false, vertical: true)
            Button("stanza.invita") { openInvite() }
                .buttonStyle(PillButtonStyle())
        }
        .sobreCard(.paperDim)
    }

    // MARK: Menu del tavolo

    private var tableMenu: some View {
        Menu {
            Button {
                openInvite()
            } label: {
                Label("stanza.invita", systemImage: "person.badge.plus")
            }
            Button {
                store.retakeWord(at: tavolo)
            } label: {
                Label("azione.riprendi", systemImage: "flame")
            }
            Button(role: .destructive) {
                confirmLeave = true
            } label: {
                Label(tavolo.animatedByMe ? "stanza.chiudi" : "stanza.alzati",
                      systemImage: "figure.walk")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(Color.brass)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text("a11y.menu.tavolo"))
    }

    private func openInvite() {
        showInvite = true
        if inviteCode == nil {
            Task { inviteCode = await store.createInviteCode(for: tavolo) }
        }
    }

    // MARK: Lo sheet dell'invito (sempre visibile, mai fuori schermo)

    private var inviteSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("stanza.invita")
                .font(AppFont.title(20, relativeTo: .title3))
                .foregroundStyle(Color.paperDim)
            Text("invito.spiega")
                .font(AppFont.ui(14, relativeTo: .footnote))
                .foregroundStyle(Color.brassSoft)
                .fixedSize(horizontal: false, vertical: true)
            if let code = inviteCode {
                VStack(alignment: .leading, spacing: 10) {
                    Text(verbatim: code)
                        .font(AppFont.display(30, relativeTo: .title))
                        .foregroundStyle(Color.ink)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity)
                    ShareLink(item: String(format: String(localized: "invito.messaggio", bundle: L10n.bundle),
                                           tavolo.name, code)) {
                        Label("tavola.invito.condividi", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PillButtonStyle())
                }
                .sobreCard(.paperDim)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.ink)
        .presentationDetents([.medium])
    }

    // MARK: Conversazione vuota

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "flame")
                .font(.system(size: 30))
                .foregroundStyle(Color.brassSoft)
                .accessibilityHidden(true)
            Text(soloAlTavolo ? "stanza.vuota.soli" : "stanza.vuota")
                .font(AppFont.ui())
                .foregroundStyle(Color.brassSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: La barra per parlare

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("stanza.scrivi", text: $draft, axis: .vertical)
                .font(AppFont.bodySerif(16, relativeTo: .body))
                .foregroundStyle(Color.ink)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.paper, in: RoundedRectangle(cornerRadius: 14))
            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                     ? Color.felt : Color.brass)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel(Text("a11y.invia"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.ink.opacity(0.97))
    }

    private func send() {
        let clean = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        store.sendMessage(clean, at: tavolo)
        draft = ""
    }

    // MARK: Chi siede qui

    private var membersSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    TableRingView(friends: commensali,
                                  maxChairs: store.rules.maxFriends,
                                  height: 240)
                        .frame(maxWidth: .infinity)
                    ForEach(commensali, id: \.persistentModelID) { person in
                        HStack(spacing: 10) {
                            AvatarView(initials: person.initials, size: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: person.isMe
                                     ? String(localized: "salotto.tu", bundle: L10n.bundle)
                                     : person.name)
                                    .font(AppFont.ui(14, relativeTo: .footnote))
                                    .foregroundStyle(Color.ink)
                                ScoreBadge(score: person.score, band: store.engine.band(for: person.score))
                            }
                            Spacer()
                        }
                        .sobreCard()
                    }
                }
                .padding(16)
            }
            .background(Color.ink)
            .navigationTitle(Text("stanza.tavolo.section"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.ink, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Il messaggio (bolla della conversazione)

private struct MessageBubble: View {
    @Environment(AppStore.self) private var store
    let messaggio: Messaggio

    private var mio: Bool { messaggio.author?.isMe == true }
    private var totaleNutre: Int { messaggio.nutreCount + (messaggio.nutritoDaMe ? 1 : 0) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if mio { Spacer(minLength: 40) }
            if !mio {
                AvatarView(initials: messaggio.author?.initials ?? "?", size: 28)
            }
            VStack(alignment: .leading, spacing: 4) {
                if !mio {
                    Text(verbatim: messaggio.author?.name ?? "—")
                        .font(AppFont.caption(12, relativeTo: .caption2))
                        .foregroundStyle(Color.brassSoft)
                }
                Text(verbatim: messaggio.text)
                    .font(AppFont.bodySerif(16, relativeTo: .body))
                    .foregroundStyle(mio ? Color.ink : Color.paperDim)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Text(messaggio.createdAt, format: .dateTime.hour().minute())
                        .font(AppFont.caption(11, relativeTo: .caption2))
                        .foregroundStyle(mio ? Color.felt : Color.brassSoft.opacity(0.85))
                    if mio {
                        // Sui miei: solo il conteggio (il piatto proprio non si nutre).
                        if totaleNutre > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 11))
                                Text(verbatim: "\(totaleNutre)")
                                    .font(AppFont.caption(11, relativeTo: .caption2))
                            }
                            .foregroundStyle(Color.successTone)
                            .accessibilityLabel(Text("a11y.nutre.ricevuti"))
                            .accessibilityValue(Text(verbatim: "\(totaleNutre)"))
                        }
                    } else {
                        nutreButton
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(bubbleBackground)
            if !mio { Spacer(minLength: 40) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: Text(messaggio.nutritoDaMe ? "a11y.nutre.on" : "a11y.nutre.off")) {
            if !mio { store.toggleNutre(on: messaggio) }
        }
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if mio {
            RoundedRectangle(cornerRadius: 14).fill(Color.paperDim)
        } else {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.felt)
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.brassSoft.opacity(0.18)))
        }
    }

    /// "Nutre": toggle con contatore, mai doppio conteggio, solo sui piatti altrui.
    private var nutreButton: some View {
        Button {
            store.toggleNutre(on: messaggio)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: messaggio.nutritoDaMe ? "leaf.fill" : "leaf")
                    .font(.system(size: 13))
                if totaleNutre > 0 {
                    Text(verbatim: "\(totaleNutre)")
                        .font(AppFont.caption(11, relativeTo: .caption2))
                }
            }
            .foregroundStyle(messaggio.nutritoDaMe ? Color.successTone : Color.brassSoft.opacity(0.9))
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(messaggio.nutritoDaMe ? "a11y.nutre.on" : "a11y.nutre.off"))
        .accessibilityValue(Text(verbatim: "\(totaleNutre)"))
    }
}
