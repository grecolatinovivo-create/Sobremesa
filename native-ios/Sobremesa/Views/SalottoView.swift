//
//  SalottoView.swift
//  Sobremesa
//
//  Il salotto: il colpo d'occhio della giornata. Le tue conversazioni
//  (i tavoli a cui siedi, con l'ultimo intervento e lo stato della brace),
//  e le richieste che aspettano una tua parola. Come la home di una chat,
//  ma con l'anima di Sobremesa.
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

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    Text("salotto.title")
                        .font(AppFont.display())
                        .foregroundStyle(Color.paperDim)
                        .accessibilityAddTraits(.isHeader)

                    if !joinRequests.isEmpty {
                        daDecidere
                    }

                    if mieSedie.isEmpty {
                        heroVuoto
                    } else {
                        conversazioni
                    }
                }
                .padding(16)
            }
            .background(Color.ink)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Tavolo.self) { tavolo in
                TavoloRoomView(tavolo: tavolo)
            }
        }
    }

    // MARK: Da zero: una strada, non un deserto

    private var heroVuoto: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "flame")
                .font(.system(size: 28))
                .foregroundStyle(Color.brass)
                .accessibilityHidden(true)
            Text("salotto.vuoto.title")
                .font(AppFont.title(19, relativeTo: .title3))
                .foregroundStyle(Color.ink)
            Text("salotto.vuoto.testo")
                .font(AppFont.ui(14, relativeTo: .footnote))
                .foregroundStyle(Color.felt)
                .fixedSize(horizontal: false, vertical: true)
            Button("salotto.vuoto.cta") { store.stanzaCorrente = .tavoli }
                .buttonStyle(PillButtonStyle())
        }
        .sobreCard(.paperDim)
    }

    // MARK: Le conversazioni (una riga per tavolo, come una chat colta)

    private var conversazioni: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(textKey: "salotto.conversazioni.section")
            ForEach(mieSedie, id: \.persistentModelID) { membership in
                if let tavolo = membership.tavolo {
                    NavigationLink(value: tavolo) {
                        rigaTavolo(tavolo: tavolo, membership: membership)
                    }
                    .buttonStyle(.plain)
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

    private func rigaTavolo(tavolo: Tavolo, membership: Membership) -> some View {
        let nuovi = nuoviInterventi(tavolo: tavolo, membership: membership)
        return HStack(spacing: 12) {
            Image(systemName: tavolo.category.symbolName)
                .font(AppFont.ui(16, relativeTo: .callout))
                .foregroundStyle(Color.brassSoft)
                .frame(width: 36, height: 36)
                .background(Color.felt, in: SwiftUI.Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(verbatim: tavolo.name)
                        .font(AppFont.ui(15, relativeTo: .subheadline))
                        .fontWeight(nuovi > 0 ? .semibold : .regular)
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                    Text(verbatim: "\(tavolo.memberCount)/\(store.rules.maxFriends)")
                        .font(AppFont.caption(11, relativeTo: .caption2))
                        .foregroundStyle(Color.felt.opacity(0.8))
                    braceDot(membership: membership, tavolo: tavolo)
                }
                if nuovi > 0 {
                    // La ricompensa alla riapertura: cosa è successo da ieri.
                    Text(verbatim: String.localizedStringWithFormat(
                        String(localized: "salotto.nuovi.interventi", bundle: L10n.bundle), nuovi))
                        .font(AppFont.caption())
                        .foregroundStyle(Color.brassDeep)
                } else if let ultimo = ultimoMessaggio(di: tavolo) {
                    Text(verbatim: "\(ultimo.author?.isMe == true ? String(localized: "salotto.tu", bundle: L10n.bundle) : (ultimo.author?.name ?? "—")): \(ultimo.text)")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.felt)
                        .lineLimit(2)
                } else {
                    Text("salotto.tavolo.silenzioso")
                        .font(AppFont.caption())
                        .italic()
                        .foregroundStyle(Color.felt.opacity(0.8))
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if let ultimo = ultimoMessaggio(di: tavolo) {
                    Text(ultimo.createdAt, format: .relative(presentation: .named))
                        .font(AppFont.caption(11, relativeTo: .caption2))
                        .foregroundStyle(Color.felt.opacity(0.8))
                }
                if nuovi > 0 {
                    SwiftUI.Circle().fill(Color.brass).frame(width: 9, height: 9)
                        .accessibilityHidden(true)
                }
            }
        }
        .sobreCard()
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("a11y.tavolo.apri"))
    }

    private func braceDot(membership: Membership, tavolo: Tavolo) -> some View {
        SwiftUI.Circle()
            .fill(braceColor(membership: membership, tavolo: tavolo))
            .frame(width: 10, height: 10)
            .accessibilityLabel(Text(verbatim: braceLabel(membership: membership, tavolo: tavolo)))
    }

    private func braceColor(membership: Membership, tavolo: Tavolo) -> Color {
        // Su carta chiara: colori a contrasto vero (BrassDeep, non BrassSoft).
        guard tavolo.memberCount >= store.rules.emberMinimumMembers else {
            return .felt.opacity(0.45)
        }
        switch store.engine.emberState(lastActivity: membership.lastActivity, now: .now) {
        case .viva: return .successTone
        case .affievolita: return .brassDeep
        case .avviso, .espulsione: return .errorTone
        }
    }

    private func braceLabel(membership: Membership, tavolo: Tavolo) -> String {
        guard tavolo.memberCount >= store.rules.emberMinimumMembers else {
            return String(localized: "brace.attesa", bundle: L10n.bundle)
        }
        switch store.engine.emberState(lastActivity: membership.lastActivity, now: .now) {
        case .viva:
            return String(localized: "brace.viva", bundle: L10n.bundle)
        case .affievolita(let giorni):
            return String.localizedStringWithFormat(String(localized: "brace.affievolita", bundle: L10n.bundle), giorni)
        case .avviso(let giorni), .espulsione(let giorni):
            return String.localizedStringWithFormat(String(localized: "brace.avviso", bundle: L10n.bundle), giorni)
        }
    }

    // MARK: Da decidere (richieste ai tavoli che animo)

    private var daDecidere: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(textKey: "decidere.section")
            ForEach(joinRequests, id: \.persistentModelID) { request in
                if let person = request.person, let tavolo = request.tavolo {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            AvatarView(initials: person.initials)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: String(format: String(localized: "richiesta.riga", bundle: L10n.bundle),
                                                      person.name, tavolo.name))
                                    .font(AppFont.ui(14, relativeTo: .footnote))
                                    .foregroundStyle(Color.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                ScoreBadge(score: person.score, band: store.engine.band(for: person.score))
                            }
                            Spacer()
                        }
                        HStack(spacing: 8) {
                            Button("sedia.accetta") { store.accept(request) }
                                .buttonStyle(PillButtonStyle())
                            Button("sedia.declina") { store.decline(request) }
                                .buttonStyle(QuietPillButtonStyle(tint: .felt))
                            Spacer()
                        }
                    }
                    .sobreCard()
                }
            }
        }
    }
}
