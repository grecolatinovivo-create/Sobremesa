//
//  TavoloRoomView.swift
//  Sobremesa
//
//  Il tavolo: LA stanza di Sobremesa. Si parla come a cena — il filo
//  del discorso scorre dall'alto in basso, si scrive in fondo, sul
//  messaggio degli altri si può fare "Nutre". In testata: chi siede,
//  come sta la brace, e il menu del tavolo (invita, riprendi, alzati).
//

import SwiftUI
import SwiftData

struct TavoloRoomView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let tavolo: Tavolo

    @Query(sort: \Messaggio.createdAt) private var allMessages: [Messaggio]
    @Query private var allMemberships: [Membership]

    @State private var draft = ""
    @State private var inviteCode: String?
    @State private var showMembers = false
    @State private var confirmLeave = false

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

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    header

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
                if let last = messaggi.last {
                    withAnimation { proxy.scrollTo(last.persistentModelID, anchor: .bottom) }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if membership != nil {
                inputBar
            }
        }
        .navigationTitle(tavolo.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.ink, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { tableMenu }
        }
        .sheet(isPresented: $showMembers) { membersSheet }
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

    // MARK: Testata

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !tavolo.theme.isEmpty {
                Text(verbatim: tavolo.theme)
                    .font(AppFont.bodySerif(15, relativeTo: .subheadline))
                    .italic()
                    .foregroundStyle(Color.brassSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                Button {
                    showMembers = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2")
                            .font(.system(size: 12))
                            .accessibilityHidden(true)
                        Text(verbatim: "\(tavolo.memberCount)/\(store.rules.maxFriends)")
                            .font(AppFont.caption())
                    }
                    .foregroundStyle(Color.brassSoft)
                    .frame(minHeight: 44)
                }
                .accessibilityLabel(Text("a11y.commensali"))

                if let membership {
                    if tavolo.memberCount < store.rules.emberMinimumMembers {
                        // Da soli la brace non si valuta: lo diciamo, non lo nascondiamo.
                        Text("brace.attesa")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.brassSoft)
                    } else {
                        EmberLine(state: store.engine.emberState(
                            lastActivity: membership.lastActivity, now: .now))
                    }
                }
                Spacer()
            }

            if let code = inviteCode {
                HStack(spacing: 10) {
                    Text(verbatim: code)
                        .font(AppFont.title(18, relativeTo: .title3))
                        .foregroundStyle(Color.ink)
                        .textSelection(.enabled)
                    Spacer()
                    ShareLink(item: String(format: String(localized: "invito.messaggio", bundle: L10n.bundle),
                                           tavolo.name, code)) {
                        Label("tavola.invito.condividi", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PillButtonStyle())
                }
                .sobreCard(.paperDim)
            }
        }
    }

    // MARK: Menu del tavolo

    private var tableMenu: some View {
        Menu {
            Button {
                Task { inviteCode = await store.createInviteCode(for: tavolo) }
            } label: {
                Label("stanza.invita", systemImage: "envelope")
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
        }
        .accessibilityLabel(Text("a11y.menu.tavolo"))
    }

    // MARK: Conversazione vuota

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "cup.and.saucer")
                .font(.system(size: 30))
                .foregroundStyle(Color.brassSoft)
                .accessibilityHidden(true)
            Text("stanza.vuota")
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
                .background(Color.paper, in: RoundedRectangle(cornerRadius: 18))
            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                     ? Color.felt : Color.brass)
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
                        .foregroundStyle(mio ? Color.felt : Color.brassSoft.opacity(0.7))
                    nutreButton
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(mio ? Color.paperDim : Color.felt.opacity(0.55),
                        in: RoundedRectangle(cornerRadius: 14))
            if !mio { Spacer(minLength: 40) }
        }
        .accessibilityElement(children: .combine)
    }

    /// "Nutre": toggle con contatore, mai doppio conteggio.
    private var nutreButton: some View {
        Button {
            store.toggleNutre(on: messaggio)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: messaggio.nutritoDaMe ? "leaf.fill" : "leaf")
                    .font(.system(size: 12))
                let totale = messaggio.nutreCount + (messaggio.nutritoDaMe ? 1 : 0)
                if totale > 0 {
                    Text(verbatim: "\(totale)")
                        .font(AppFont.caption(11, relativeTo: .caption2))
                }
            }
            .foregroundStyle(messaggio.nutritoDaMe ? Color.successTone
                             : (mio ? Color.felt : Color.brassSoft.opacity(0.8)))
            .frame(minWidth: 34, minHeight: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(messaggio.nutritoDaMe ? "a11y.nutre.on" : "a11y.nutre.off"))
        .accessibilityValue(Text(verbatim: "\(messaggio.nutreCount + (messaggio.nutritoDaMe ? 1 : 0))"))
    }
}
