//
//  CircoliView.swift
//  Sobremesa
//
//  I 5 slot: punteggio personale, circoli abitati con lo stato della brace,
//  pannello dell'animatore con le richieste d'ingresso, catalogo dei circoli
//  aperti (a 5/5 il bottone è disabilitato e SPIEGATO, mai nascosto).
//

import SwiftUI
import SwiftData

struct CircoliView: View {
    @Environment(AppStore.self) private var store
    @Query(filter: #Predicate<Membership> { $0.person?.isMe == true },
           sort: \Membership.joinedAt) private var myMemberships: [Membership]
    @Query private var allCircles: [Circolo]
    @Query(sort: \JoinRequest.createdAt) private var allRequests: [JoinRequest]
    @Query(filter: #Predicate<Person> { $0.isMe }) private var meQuery: [Person]

    @State private var circoloToLeave: Circolo?

    private var me: Person? { meQuery.first }

    /// Catalogo: circoli aperti che non abito già.
    private var catalog: [Circolo] {
        let mine = myMemberships.compactMap(\.circolo)
        return allCircles
            .filter { circolo in circolo.isOpen && !mine.contains(where: { $0 === circolo }) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Text("circoli.title")
                    .font(AppFont.display())
                    .foregroundStyle(Color.paperDim)
                    .accessibilityAddTraits(.isHeader)

                Text("circoli.motto")
                    .font(AppFont.bodySerif(15, relativeTo: .subheadline))
                    .italic()
                    .foregroundStyle(Color.brassSoft)

                scoreRow
                slotCounter

                SectionTitle(textKey: "circoli.miei.section")
                if myMemberships.isEmpty {
                    Text("circoli.miei.empty")
                        .font(AppFont.ui())
                        .foregroundStyle(Color.brassSoft)
                }
                ForEach(myMemberships, id: \.persistentModelID) { membership in
                    if let circolo = membership.circolo {
                        CircleCard(membership: membership,
                                   circolo: circolo,
                                   requests: allRequests.filter { $0.circolo === circolo },
                                   onLeave: { circoloToLeave = circolo })
                    }
                }

                SectionTitle(textKey: "circoli.catalogo.section")
                ForEach(catalog, id: \.persistentModelID) { circolo in
                    CatalogRow(circolo: circolo,
                               slotsFull: !store.engine.canJoinCircle(currentCircleCount: myMemberships.count))
                }

                #if DEBUG
                // Solo build DEBUG: per testare la meccanica temporale della brace.
                Button("debug.simula") {
                    store.simulateSilence(days: 3)
                }
                .buttonStyle(QuietPillButtonStyle())
                .padding(.top, 6)
                #endif
            }
            .padding(16)
        }
        .background(Color.ink)
        .confirmationDialog(
            Text(String(format: String(localized: "confirm.esci.title"),
                        circoloToLeave?.nameKey.loc ?? "")),
            isPresented: Binding(get: { circoloToLeave != nil },
                                 set: { if !$0 { circoloToLeave = nil } }),
            titleVisibility: .visible
        ) {
            Button("confirm.esci.confirm", role: .destructive) {
                if let circolo = circoloToLeave { store.leaveCircle(circolo) }
                circoloToLeave = nil
            }
            Button("confirm.cancel", role: .cancel) { circoloToLeave = nil }
        } message: {
            Text("confirm.esci.message")
        }
    }

    // MARK: Punteggio e slot

    /// Il punteggio nel PROPRIO contesto: numero + fascia, mai una classifica.
    private var scoreRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("circoli.punteggio.label")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.brassSoft)
                if let me {
                    HStack(spacing: 10) {
                        Text(verbatim: "\(me.score)")
                            .font(AppFont.display(30, relativeTo: .title))
                            .foregroundStyle(Color.paperDim)
                        ScoreBadge(score: me.score, band: store.engine.band(for: me.score))
                    }
                }
            }
            Spacer()
        }
        .padding(14)
        .background(Color.felt, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Contatore N/5 sempre visibile.
    private var slotCounter: some View {
        Text(verbatim: String.localizedStringWithFormat(
            String(localized: "circoli.slot"),
            myMemberships.count, store.rules.maxCircles))
            .font(AppFont.ui())
            .foregroundStyle(Color.brassSoft)
            .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Card di un circolo abitato

private struct CircleCard: View {
    @Environment(AppStore.self) private var store
    let membership: Membership
    let circolo: Circolo
    let requests: [JoinRequest]
    let onLeave: () -> Void

    private var emberState: EmberState {
        store.engine.emberState(lastActivity: membership.lastActivity, now: .now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: circolo.nameKey.loc)
                        .font(AppFont.title(19, relativeTo: .title3))
                        .foregroundStyle(Color.ink)
                    Text(verbatim: circolo.themeKey.loc)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.felt)
                    Text(verbatim: String.localizedStringWithFormat(
                        String(localized: "circolo.membri.count"), circolo.memberCount))
                        .font(AppFont.caption())
                        .foregroundStyle(Color.felt)
                }
                Spacer()
                CategoryChip(category: circolo.category)
            }

            if circolo.animatedByMe {
                animatorBadge
            }

            EmberRow(state: emberState) {
                store.retakeWord(in: circolo)
            }

            if circolo.animatedByMe && !requests.isEmpty {
                requestsPanel
            }

            HStack {
                Spacer()
                Button("action.esci", action: onLeave)
                    .buttonStyle(QuietPillButtonStyle(tint: .felt))
                    .accessibilityLabel(Text(verbatim: String(
                        format: String(localized: "a11y.esci"), circolo.nameKey.loc)))
            }
        }
        .sobreCard()
    }

    private var animatorBadge: some View {
        Text("circoli.animatore.badge")
            .font(AppFont.caption(12, relativeTo: .caption2))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.brass.opacity(0.18)))
            .overlay(Capsule().strokeBorder(Color.brass, lineWidth: 1))
            .foregroundStyle(Color.brass)
    }

    /// Le richieste d'ingresso: il punteggio è lo strumento decisionale.
    private var requestsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: String.localizedStringWithFormat(
                String(localized: "circoli.richieste.section"), requests.count))
                .font(AppFont.ui(14, relativeTo: .footnote))
                .foregroundStyle(Color.felt)
            ForEach(requests, id: \.persistentModelID) { request in
                if let person = request.person {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            AvatarView(initials: person.initials, size: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: person.name)
                                    .font(AppFont.ui(14, relativeTo: .footnote))
                                    .foregroundStyle(Color.ink)
                                Text(verbatim: person.interestKeys.map(\.loc).joined(separator: ", "))
                                    .font(AppFont.caption(11, relativeTo: .caption2))
                                    .foregroundStyle(Color.felt)
                            }
                            Spacer()
                            ScoreBadge(score: person.score, band: store.engine.band(for: person.score))
                        }
                        HStack(spacing: 8) {
                            Button("action.accogli") { store.accept(request) }
                                .buttonStyle(PillButtonStyle())
                            Button("action.declina") { store.decline(request) }
                                .buttonStyle(QuietPillButtonStyle(tint: .felt))
                        }
                    }
                    .padding(10)
                    .background(Color.paperDim,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }
}

// MARK: - Stato della brace

/// viva / si affievolisce / avviso rosso con "Riprendi la parola".
private struct EmberRow: View {
    let state: EmberState
    let onRetake: () -> Void

    var body: some View {
        switch state {
        case .viva:
            label(color: .successTone, text: String(localized: "brace.viva"))
        case .affievolita(let giorni):
            label(color: .brass, text: String.localizedStringWithFormat(
                String(localized: "brace.affievolita"), giorni))
        case .avviso(let giorni):
            VStack(alignment: .leading, spacing: 8) {
                label(color: .errorTone, text: String.localizedStringWithFormat(
                    String(localized: "brace.avviso"), giorni))
                Button("action.riprendi", action: onRetake)
                    .buttonStyle(PillButtonStyle())
            }
        case .espulsione(let giorni):
            // In pratica non visibile: l'espulsione rimuove la membership.
            label(color: .errorTone, text: String.localizedStringWithFormat(
                String(localized: "brace.avviso"), giorni))
        }
    }

    private func label(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            SwiftUI.Circle().fill(color).frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(verbatim: text)
                .font(AppFont.caption())
                .foregroundStyle(color)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Riga del catalogo

private struct CatalogRow: View {
    @Environment(AppStore.self) private var store
    let circolo: Circolo
    let slotsFull: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: circolo.nameKey.loc)
                        .font(AppFont.title(17, relativeTo: .headline))
                        .foregroundStyle(Color.ink)
                    Text(verbatim: circolo.themeKey.loc)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.felt)
                    Text(verbatim: String.localizedStringWithFormat(
                        String(localized: "circolo.membri.count"), circolo.memberCount))
                        .font(AppFont.caption())
                        .foregroundStyle(Color.felt)
                }
                Spacer()
                Button("action.entra") { store.joinCircle(circolo) }
                    .buttonStyle(PillButtonStyle())
                    .disabled(slotsFull)
                    .opacity(slotsFull ? 0.45 : 1)
                    .accessibilityLabel(Text(verbatim: String(
                        format: String(localized: "a11y.entra"), circolo.nameKey.loc)))
            }
            if slotsFull {
                // Disabilitato e spiegato, mai nascosto.
                Text(verbatim: String.localizedStringWithFormat(
                    String(localized: "circoli.catalogo.pieno"), store.rules.maxCircles))
                    .font(AppFont.caption())
                    .foregroundStyle(Color.errorTone)
            }
        }
        .sobreCard(.paperDim)
    }
}
