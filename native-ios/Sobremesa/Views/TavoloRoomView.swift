//
//  TavoloRoomView.swift
//  Sobremesa
//
//  La stanza del tavolo (v3 "Ultima luce"): stanze che fanno pensare
//  insieme. Non una chat — una conversazione editoriale: gli interventi
//  altrui vivono direttamente sul fondo, i miei su una superficie appena
//  più chiara; nomi e ore li identificano, "Nutre" è un gesto secondario.
//  In cima il tavolo (glifo 88 pt, toccabile → commensali) e la brace;
//  scorrendo, il nome del tavolo passa nella barra (continuità del titolo).
//

import SwiftUI
import SwiftData
import UIKit

struct TavoloRoomView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tavolo: Tavolo

    @Query(sort: \Messaggio.createdAt) private var allMessages: [Messaggio]
    @Query(sort: \Membership.joinedAt) private var allMemberships: [Membership]
    @Query private var allTables: [Tavolo]

    @State private var draft = ""
    @State private var inviteCode: String?
    @State private var showInvite = false
    @State private var showMembers = false
    @State private var confirmLeave = false
    @State private var headerVisible = true
    @FocusState private var composerFocused: Bool

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

    /// Chi siede al tavolo (me compreso), in ordine d'arrivo.
    private var sedie: [Membership] {
        allMemberships.filter { $0.tavolo === tavolo }
    }

    private var mySeat: Int? {
        sedie.firstIndex { $0.person?.isMe == true }
    }

    private var warmth: TableWarmth {
        store.warmth(of: tavolo, lastMessageAt: messaggi.last?.createdAt)
    }

    var body: some View {
        Group {
            if isAlive {
                conversazione
            } else {
                chiuso
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: Il tavolo si è chiuso mentre eravamo qui

    private var chiuso: some View {
        VStack(spacing: Space.l) {
            TableGlyph(occupied: 0, maxSeats: store.rules.maxFriends, warmth: .inAttesa, size: 96)
            Text("stanza.chiusa")
                .font(AppFont.bodySerif(17))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
            Button("stanza.chiusa.torna") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
    }

    // MARK: La conversazione

    private var conversazione: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    header
                        .onAppear { headerVisible = true }
                        .onDisappear { headerVisible = false }
                        .padding(.bottom, Space.xl)

                    if tavolo.memberCount < store.rules.emberMinimumMembers {
                        attesaPanel
                            .padding(.bottom, Space.xl)
                    }

                    if messaggi.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(messaggi.enumerated()), id: \.element.persistentModelID) { index, messaggio in
                            let previous = index > 0 ? messaggi[index - 1] : nil
                            if let label = daySeparator(for: messaggio, previous: previous) {
                                DaySeparator(label: label)
                            }
                            ConversationEntry(messaggio: messaggio,
                                              continued: isContinuation(messaggio, of: previous))
                                .id(messaggio.persistentModelID)
                                .transition(reduceMotion ? .opacity
                                            : .opacity.combined(with: .offset(y: 8)))
                        }
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.s)
                .padding(.bottom, Space.l)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: messaggi.count)
            }
            .screenBackground()
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .onChange(of: messaggi.count) {
                store.markRead(tavolo)
                if let last = messaggi.last {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                        proxy.scrollTo(last.persistentModelID, anchor: .bottom)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if membership != nil {
                composer
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(verbatim: tavolo.name)
                    .font(AppFont.title(18, relativeTo: .headline))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .opacity(headerVisible ? 0 : 1)
                    .animation(.easeInOut(duration: 0.2), value: headerVisible)
                    .accessibilityHidden(headerVisible)
            }
            ToolbarItem(placement: .topBarTrailing) { tableMenu }
        }
        .sheet(isPresented: $showMembers) {
            CommensaliSheet(tavolo: tavolo, sedie: sedie, warmth: warmth)
        }
        .sheet(isPresented: $showInvite) {
            InviteSheet(tavolo: tavolo, code: inviteCode)
        }
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

    // MARK: In cima: il tavolo

    private var header: some View {
        VStack(spacing: Space.s) {
            Button {
                showMembers = true
            } label: {
                TableGlyph(occupied: tavolo.memberCount, maxSeats: store.rules.maxFriends,
                           warmth: warmth, mySeat: mySeat, size: 88, breathing: true)
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("a11y.commensali"))
            .padding(.bottom, Space.xs)

            Text(verbatim: tavolo.name)
                .font(AppFont.title(28, relativeTo: .title))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            if !tavolo.theme.isEmpty {
                Text(verbatim: tavolo.theme)
                    .font(AppFont.ui(14, relativeTo: .subheadline))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                Button {
                    showMembers = true
                } label: {
                    Text(verbatim: String.localizedStringWithFormat(
                        String(localized: "stanza.commensali", bundle: L10n.bundle), tavolo.memberCount))
                        .font(AppFont.caption(13).weight(.medium))
                        .foregroundStyle(Color.textSecondary)
                        .underline(false)
                }
                .buttonStyle(.plain)
                Text(verbatim: "·").foregroundStyle(Color.textMuted)
                WarmthLabel(warmth: warmth)
            }
            .frame(minHeight: 28)

            personalLine
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.s)
    }

    /// La MIA sedia: una riga discreta, mai una sirena.
    @ViewBuilder
    private var personalLine: some View {
        if let membership {
            if let giorni = store.engine.personalSilenceNotice(lastActivity: membership.lastActivity,
                                                                now: .now, isAnimator: tavolo.animatedByMe) {
                VStack(spacing: 2) {
                    Text(verbatim: String.localizedStringWithFormat(
                        String(localized: "sedia.ti.aspetta", bundle: L10n.bundle), giorni))
                        .font(AppFont.caption(13))
                        .foregroundStyle(Color.warning)
                    Button("azione.riprendi") { store.retakeWord(at: tavolo) }
                        .buttonStyle(TextActionStyle())
                }
            } else if let ultimo = messaggi.last(where: { $0.author?.isMe == true }) {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                        .imageScale(.small)
                        .accessibilityHidden(true)
                    Text(verbatim: String(format: String(localized: "stanza.hai.parlato", bundle: L10n.bundle),
                                          ultimo.createdAt.formatted(.relative(presentation: .named))))
                }
                .font(AppFont.caption(12, relativeTo: .caption2))
                .foregroundStyle(Color.textMuted)
            }
        }
    }

    // MARK: Da soli: si aspetta (e si invita)

    private var attesaPanel: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("stanza.soli.title")
                .font(AppFont.title(19, relativeTo: .title3))
                .foregroundStyle(Color.textPrimary)
            Text("stanza.soli.testo")
                .font(AppFont.bodySerif(15, relativeTo: .subheadline))
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                openInvite()
            } label: {
                Label("stanza.invita", systemImage: "paperplane")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, Space.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
    }

    // MARK: Conversazione vuota

    private var emptyState: some View {
        VStack(spacing: Space.s) {
            Text(tavolo.memberCount < store.rules.emberMinimumMembers ? "stanza.vuota.soli" : "stanza.vuota")
                .font(AppFont.bodySerif(16, relativeTo: .callout))
                .italic()
                .foregroundStyle(Color.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xl)
    }

    // MARK: Separatori e raggruppamenti

    private func daySeparator(for messaggio: Messaggio, previous: Messaggio?) -> String? {
        let calendar = Calendar.current
        if let previous, calendar.isDate(previous.createdAt, inSameDayAs: messaggio.createdAt) { return nil }
        if calendar.isDateInToday(messaggio.createdAt) { return String(localized: "giorno.oggi", bundle: L10n.bundle) }
        if calendar.isDateInYesterday(messaggio.createdAt) { return String(localized: "giorno.ieri", bundle: L10n.bundle) }
        return messaggio.createdAt.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    /// Stesso autore entro 10 minuti: l'intervento prosegue senza ripetere nome e volto.
    private func isContinuation(_ messaggio: Messaggio, of previous: Messaggio?) -> Bool {
        guard let previous, previous.author === messaggio.author else { return false }
        return messaggio.createdAt.timeIntervalSince(previous.createdAt) < 600
            && Calendar.current.isDate(previous.createdAt, inSameDayAs: messaggio.createdAt)
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
                showMembers = true
            } label: {
                Label("stanza.tavolo.section", systemImage: "person.2")
            }
            Button {
                store.retakeWord(at: tavolo)
            } label: {
                Label("azione.riprendi", systemImage: "flame")
            }
            Divider()
            Button(role: .destructive) {
                confirmLeave = true
            } label: {
                Label(tavolo.animatedByMe ? "stanza.chiudi" : "stanza.alzati",
                      systemImage: "figure.walk")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
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

    // MARK: Il composer

    private var composer: some View {
        let empty = draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return HStack(alignment: .bottom, spacing: Space.s) {
            TextField("stanza.scrivi", text: $draft, axis: .vertical)
                .font(AppFont.bodySerif(17, relativeTo: .body))
                .foregroundStyle(Color.textPrimary)
                .tint(.brass)
                .lineLimit(1...5)
                .focused($composerFocused)
                .padding(.horizontal, Space.l)
                .padding(.vertical, 14)
                .frame(minHeight: 52)
                .background(Color.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(composerFocused ? Color.outline : Color.divider, lineWidth: 1))
            Button {
                send()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.body.weight(.bold))
                    .foregroundStyle(empty ? Color.textMuted : Color.brassInk)
                    .frame(width: 44, height: 44)
                    .background(SwiftUI.Circle().fill(empty ? Color.surface : Color.brass))
            }
            .disabled(empty)
            .padding(.bottom, 4)
            .accessibilityLabel(Text("a11y.invia"))
            .animation(.easeOut(duration: 0.15), value: empty)
        }
        .padding(.horizontal, Space.l)
        .padding(.top, Space.s)
        .padding(.bottom, Space.s)
        .background(Color.background.opacity(0.98).ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Hairline() }
    }

    private func send() {
        let clean = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        store.sendMessage(clean, at: tavolo)
        draft = ""
    }
}

// MARK: - Separatore di giorno

private struct DaySeparator: View {
    let label: String
    var body: some View {
        HStack(spacing: Space.m) {
            Hairline()
            Text(verbatim: label)
                .font(AppFont.label(11).weight(.semibold))
                .textCase(.uppercase)
                .kerning(1)
                .foregroundStyle(Color.textMuted)
                .layoutPriority(1)
            Hairline()
        }
        .padding(.vertical, Space.l)
    }
}

// MARK: - Un intervento (conversazione editoriale)

private struct ConversationEntry: View {
    @Environment(AppStore.self) private var store
    let messaggio: Messaggio
    /// Prosegue l'intervento precedente dello stesso autore.
    var continued = false

    private var mio: Bool { messaggio.author?.isMe == true }
    private var totaleNutre: Int { messaggio.nutreCount + (messaggio.nutritoDaMe ? 1 : 0) }

    var body: some View {
        HStack(alignment: .top, spacing: Space.m) {
            Group {
                if continued {
                    Color.clear
                } else {
                    AvatarView(initials: messaggio.author?.initials ?? "?", size: 30, highlighted: mio)
                }
            }
            .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                if !continued {
                    HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                        Text(verbatim: mio ? String(localized: "salotto.tu", bundle: L10n.bundle)
                                           : (messaggio.author?.name ?? "—"))
                            .font(AppFont.ui(14, relativeTo: .subheadline).weight(.semibold))
                            .foregroundStyle(mio ? Color.brass : Color.textPrimary)
                        Text(messaggio.createdAt, format: .dateTime.hour().minute())
                            .font(AppFont.caption(12, relativeTo: .caption2))
                            .foregroundStyle(Color.textMuted)
                        Spacer(minLength: 0)
                        nutre
                    }
                }
                Text(verbatim: messaggio.text)
                    .font(AppFont.bodySerif(17, relativeTo: .body))
                    .foregroundStyle(Color.textPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                if continued {
                    HStack { Spacer(minLength: 0); nutre }
                }
            }
        }
        .padding(.vertical, mio ? Space.m : Space.s)
        .padding(.horizontal, mio ? Space.m : 0)
        .background {
            if mio {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.elevated)
            }
        }
        .padding(.top, continued ? 0 : Space.s)
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: Text(messaggio.nutritoDaMe ? "a11y.nutre.on" : "a11y.nutre.off")) {
            if !mio { store.toggleNutre(on: messaggio) }
        }
    }

    /// "Nutre": gesto secondario. Sui miei solo il conteggio (il proprio piatto non si nutre).
    @ViewBuilder
    private var nutre: some View {
        if mio {
            if totaleNutre > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill").imageScale(.small)
                    Text(verbatim: "\(totaleNutre)")
                        .font(AppFont.caption(12, relativeTo: .caption2).monospacedDigit())
                }
                .foregroundStyle(Color.emberAlive)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("a11y.nutre.ricevuti"))
                .accessibilityValue(Text(verbatim: "\(totaleNutre)"))
            }
        } else {
            Button {
                store.toggleNutre(on: messaggio)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: messaggio.nutritoDaMe ? "leaf.fill" : "leaf")
                        .imageScale(.small)
                        .symbolEffect(.bounce, value: messaggio.nutritoDaMe)
                    Text(verbatim: totaleNutre > 0
                         ? "\(String(localized: "post.nutre", bundle: L10n.bundle)) \(totaleNutre)"
                         : String(localized: "post.nutre", bundle: L10n.bundle))
                        .font(AppFont.caption(12, relativeTo: .caption2).weight(.medium))
                }
                .foregroundStyle(messaggio.nutritoDaMe ? Color.emberAlive : Color.textMuted)
                .frame(minWidth: 44, minHeight: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: messaggio.nutritoDaMe)
            .accessibilityLabel(Text(messaggio.nutritoDaMe ? "a11y.nutre.on" : "a11y.nutre.off"))
            .accessibilityValue(Text(verbatim: "\(totaleNutre)"))
        }
    }
}

// MARK: - Foglio dei commensali

private struct CommensaliSheet: View {
    @Environment(AppStore.self) private var store
    let tavolo: Tavolo
    let sedie: [Membership]
    let warmth: TableWarmth

    private func isAnimator(_ person: Person) -> Bool {
        if person.isMe { return tavolo.animatedByMe }
        return person.serverID != nil && person.serverID == tavolo.animatorServerID
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.xl) {
                    VStack(spacing: Space.m) {
                        SeatRing(people: sedie.compactMap(\.person),
                                 maxSeats: store.rules.maxFriends,
                                 warmth: warmth)
                        Text(verbatim: String.localizedStringWithFormat(
                            String(localized: "tavola.sedie.libere", bundle: L10n.bundle),
                            max(0, store.rules.maxFriends - tavolo.memberCount)))
                            .font(AppFont.caption(13))
                            .foregroundStyle(Color.textMuted)
                        WarmthLabel(warmth: warmth)
                    }
                    .padding(.top, Space.l)

                    VStack(spacing: 0) {
                        ForEach(Array(sedie.enumerated()), id: \.element.persistentModelID) { index, sedia in
                            if let person = sedia.person {
                                HStack(spacing: Space.m) {
                                    Text(verbatim: "\(index + 1)")
                                        .font(AppFont.caption(12).monospacedDigit())
                                        .foregroundStyle(Color.textMuted)
                                        .frame(width: 20, alignment: .trailing)
                                    AvatarView(initials: person.initials, size: 36, highlighted: person.isMe)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(verbatim: person.name)
                                            .font(AppFont.ui(15).weight(.medium))
                                            .foregroundStyle(Color.textPrimary)
                                        if person.isMe || isAnimator(person) {
                                            Text(person.isMe ? "stanza.tuo.posto" : "stanza.animatore")
                                                .font(AppFont.caption(12, relativeTo: .caption2))
                                                .foregroundStyle(person.isMe ? Color.brass : Color.textMuted)
                                        }
                                    }
                                    Spacer()
                                    BandLabel(band: store.engine.band(for: person.score))
                                }
                                .padding(.vertical, Space.m)
                                .padding(.horizontal, person.isMe ? Space.s : 0)
                                .background {
                                    if person.isMe {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(Color.brass.opacity(0.6), lineWidth: 1)
                                    }
                                }
                                .accessibilityElement(children: .combine)
                                if index < sedie.count - 1 { Hairline(inset: 20 + 36 + Space.m * 2) }
                            }
                        }
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.xl)
            }
            .screenBackground()
            .navigationTitle(Text("stanza.tavolo.section"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.background)
    }
}

// MARK: - Foglio dell'invito

private struct InviteSheet: View {
    let tavolo: Tavolo
    let code: String?
    @State private var copied = false

    var body: some View {
        VStack(spacing: Space.l) {
            Text("stanza.invita")
                .font(AppFont.title(24, relativeTo: .title2))
                .foregroundStyle(Color.textPrimary)
            Text("invito.titoletto")
                .font(AppFont.title(19, relativeTo: .title3))
                .foregroundStyle(Color.textPrimary)
            Text("invito.spiega")
                .font(AppFont.bodySerif(16, relativeTo: .callout))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Group {
                if let code {
                    Text(verbatim: spaced(code))
                        .font(.system(size: 34, weight: .medium, design: .monospaced))
                        .kerning(1)
                        .foregroundStyle(Color.textPrimary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .textSelection(.enabled)
                        .accessibilityLabel(Text(verbatim: code.map(String.init).joined(separator: " ")))
                } else {
                    ProgressView().tint(.brass)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(Color.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.divider, lineWidth: 1))

            if let code {
                VStack(spacing: Space.s) {
                    ShareLink(item: String(format: String(localized: "invito.messaggio", bundle: L10n.bundle),
                                           tavolo.name, code)) {
                        Label("tavola.invito.condividi", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                    Button {
                        UIPasteboard.general.string = code
                        copied = true
                    } label: {
                        Label(copied ? "invito.copiato" : "invito.copia",
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .sensoryFeedback(.success, trigger: copied)
                }
            }
            Spacer(minLength: 0)
            Text("invito.chiosa")
                .font(AppFont.bodySerif(15, relativeTo: .footnote))
                .italic()
                .foregroundStyle(Color.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(Space.xl)
        .presentationDetents([.medium])
        .presentationBackground(Color.background)
    }

    /// "Q7WX K2MP": il codice si legge a blocchi di quattro.
    private func spaced(_ code: String) -> String {
        guard code.count == 8 else { return code }
        return String(code.prefix(4)) + "-" + String(code.suffix(4))
    }
}
