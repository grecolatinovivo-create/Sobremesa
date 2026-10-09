//
//  SalottoView.swift
//  Sobremesa
//
//  Il salotto (v3 "Ultima luce"): i tuoi tavoli, oggi. Niente card per
//  ogni conversazione — righe ariose separate da filetti, ognuna col
//  suo piccolo tavolo (TableGlyph 44) e la sua brace. Sopra, solo se
//  serve, "Da decidere". Da vuoto, una strada, non un deserto.
//

import SwiftUI
import SwiftData

struct SalottoView: View {
    @Environment(AppStore.self) private var store
    @Query(sort: \Messaggio.createdAt, order: .reverse) private var allMessages: [Messaggio]
    @Query(sort: \JoinRequest.createdAt) private var joinRequests: [JoinRequest]
    // @Query e non store.myMemberships: la fondazione del primo tavolo deve
    // aggiornare il Salotto da sola (Observation non traccia le fetch).
    @Query(filter: #Predicate<Membership> { $0.person?.isMe == true },
           sort: \Membership.joinedAt) private var mieSedie: [Membership]
    @Query(sort: \Membership.joinedAt) private var tutteLeSedie: [Membership]

    var body: some View {
        @Bindable var store = store
        NavigationStack(path: $store.salottoPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    ScreenTitle(titleKey: "salotto.title", subtitleKey: "salotto.sottotitolo")

                    if !joinRequests.isEmpty {
                        daDecidere
                    }

                    if mieSedie.isEmpty {
                        vuoto
                    } else {
                        tavoli
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.l)
                .padding(.bottom, Space.xxl)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Tavolo.self) { tavolo in
                TavoloRoomView(tavolo: tavolo)
            }
            .animation(.easeInOut(duration: 0.25), value: mieSedie.count)
            .animation(.easeInOut(duration: 0.25), value: joinRequests.count)
        }
    }

    // MARK: I tuoi tavoli

    private var tavoli: some View {
        VStack(spacing: 0) {
            ForEach(Array(mieSedie.enumerated()), id: \.element.persistentModelID) { index, membership in
                if let tavolo = membership.tavolo {
                    NavigationLink(value: tavolo) {
                        TableRow(tavolo: tavolo,
                                 membership: membership,
                                 ultimo: ultimoMessaggio(di: tavolo),
                                 nuovi: nuoviInterventi(tavolo: tavolo, membership: membership),
                                 mySeat: mySeatIndex(tavolo: tavolo))
                    }
                    .buttonStyle(RowPressStyle())
                    if index < mieSedie.count - 1 {
                        Hairline(inset: 44 + Space.l)
                    }
                }
            }
        }
    }

    private func ultimoMessaggio(di tavolo: Tavolo) -> Messaggio? {
        allMessages.first { $0.tavolo === tavolo }
    }

    /// Interventi altrui successivi all'ultima lettura.
    private func nuoviInterventi(tavolo: Tavolo, membership: Membership) -> Int {
        allMessages.filter {
            $0.tavolo === tavolo && $0.author?.isMe != true && $0.createdAt > membership.lastReadAt
        }.count
    }

    /// Il mio posto nell'ordine d'arrivo al tavolo.
    private func mySeatIndex(tavolo: Tavolo) -> Int? {
        tutteLeSedie.filter { $0.tavolo === tavolo }.firstIndex { $0.person?.isMe == true }
    }

    // MARK: Da decidere (richieste ai tavoli che animo)

    private var daDecidere: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("decidere.section")
                .font(AppFont.title(20, relativeTo: .title3))
                .foregroundStyle(Color.textPrimary)
                .accessibilityAddTraits(.isHeader)
            ForEach(joinRequests, id: \.persistentModelID) { request in
                if let person = request.person, let tavolo = request.tavolo {
                    VStack(alignment: .leading, spacing: Space.m) {
                        HStack(alignment: .top, spacing: Space.m) {
                            AvatarView(initials: person.initials, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: String(format: String(localized: "richiesta.riga", bundle: L10n.bundle),
                                                      person.name, tavolo.name))
                                    .font(AppFont.ui(15))
                                    .foregroundStyle(Color.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                BandLabel(band: store.engine.band(for: person.score))
                            }
                        }
                        HStack(spacing: Space.s) {
                            Button("sedia.accetta") { store.accept(request) }
                                .buttonStyle(PrimaryButtonStyle())
                            Button("sedia.declina") { store.decline(request) }
                                .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                    .panel()
                    .transition(.opacity)
                }
            }
        }
    }

    // MARK: Da zero

    private var vuoto: some View {
        VStack(spacing: Space.l) {
            TableGlyph(occupied: 0, maxSeats: store.rules.maxFriends,
                       warmth: .viva, size: 168, breathing: true)
                .padding(.top, Space.l)
            Text("salotto.vuoto.title")
                .font(AppFont.title(24, relativeTo: .title2))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
            Text("salotto.vuoto.testo")
                .font(AppFont.bodySerif(16, relativeTo: .callout))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: Space.s) {
                Button {
                    store.stanzaCorrente = .tavoli
                } label: {
                    Label("salotto.vuoto.cta", systemImage: "magnifyingglass")
                }
                .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                Button {
                    store.stanzaCorrente = .tavoli
                } label: {
                    Label("salotto.vuoto.codice", systemImage: "ticket")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.top, Space.s)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - La riga di un tavolo

private struct TableRow: View {
    @Environment(AppStore.self) private var store
    let tavolo: Tavolo
    let membership: Membership
    let ultimo: Messaggio?
    let nuovi: Int
    let mySeat: Int?

    private var warmth: TableWarmth {
        store.warmth(of: tavolo, lastMessageAt: ultimo?.createdAt)
    }

    private var silenzioPersonale: Int? {
        store.engine.personalSilenceNotice(lastActivity: membership.lastActivity,
                                           now: .now, isAnimator: tavolo.animatedByMe)
    }

    var body: some View {
        HStack(alignment: .top, spacing: Space.l) {
            TableGlyph(occupied: tavolo.memberCount, maxSeats: store.rules.maxFriends,
                       warmth: warmth, mySeat: mySeat, size: 44)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: tavolo.name)
                        .font(AppFont.title(20, relativeTo: .title3))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(2)
                    Spacer(minLength: Space.s)
                    if let ultimo {
                        Text(ultimo.createdAt, format: .relative(presentation: .named))
                            .font(AppFont.caption(12, relativeTo: .caption2))
                            .foregroundStyle(nuovi > 0 ? Color.brass : Color.textMuted)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "person")
                        .imageScale(.small)
                        .foregroundStyle(Color.textMuted)
                        .accessibilityHidden(true)
                    Text(verbatim: "\(tavolo.memberCount)/\(store.rules.maxFriends)")
                        .font(AppFont.caption(13).monospacedDigit())
                        .foregroundStyle(Color.textMuted)
                    Text(verbatim: "·").foregroundStyle(Color.textMuted)
                    WarmthLabel(warmth: warmth)
                }

                preview
            }
        }
        .padding(.vertical, Space.l)
        .frame(minHeight: 88)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("a11y.tavolo.apri"))
    }

    @ViewBuilder
    private var preview: some View {
        if let giorni = silenzioPersonale {
            // Avviso personale con tatto: un invito, non una sirena.
            Text(verbatim: String.localizedStringWithFormat(
                String(localized: "sedia.ti.aspetta", bundle: L10n.bundle), giorni))
                .font(AppFont.caption(14, relativeTo: .footnote))
                .foregroundStyle(Color.warning)
        } else if nuovi > 0 {
            Text(verbatim: String.localizedStringWithFormat(
                String(localized: "salotto.nuovi.interventi", bundle: L10n.bundle), nuovi))
                .font(AppFont.caption(14, relativeTo: .footnote).weight(.semibold))
                .foregroundStyle(Color.textPrimary)
        } else if let ultimo {
            Text(verbatim: "\(ultimo.author?.isMe == true ? String(localized: "salotto.tu", bundle: L10n.bundle) : (ultimo.author?.name ?? "—")): \(ultimo.text)")
                .font(AppFont.caption(14, relativeTo: .footnote))
                .foregroundStyle(Color.textSecondary)
                .lineLimit(2)
        } else if warmth == .inAttesa {
            Text("salotto.tavolo.attesa")
                .font(AppFont.caption(14, relativeTo: .footnote))
                .italic()
                .foregroundStyle(Color.textMuted)
        } else {
            Text("salotto.tavolo.silenzioso")
                .font(AppFont.caption(14, relativeTo: .footnote))
                .italic()
                .foregroundStyle(Color.textMuted)
        }
    }
}

/// Pressione di una riga: un velo appena percettibile, niente card.
struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.surface.opacity(configuration.isPressed ? 1 : 0))
                    .padding(.horizontal, -Space.s)
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
