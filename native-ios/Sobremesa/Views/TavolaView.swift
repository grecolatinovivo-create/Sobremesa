//
//  TavolaView.swift
//  Sobremesa
//
//  Le 12 sedie: la visualizzazione grafica della tavola rotonda,
//  la lista degli amici ("Libera sedia"), i candidati ("Invita")
//  e il flusso chiave "tavola piena → libera una sedia → auto-seduta".
//

import SwiftUI
import SwiftData

struct TavolaView: View {
    @Environment(AppStore.self) private var store
    @Query(sort: \Friendship.since) private var friendships: [Friendship]
    @Query(filter: #Predicate<Person> { $0.isCandidate || $0.hasPendingInvite },
           sort: \Person.name) private var candidates: [Person]

    /// Amico di cui si sta per liberare la sedia (conferma in corso).
    @State private var friendshipToFree: Friendship?
    /// Codice d'invito appena generato, pronto da condividere.
    @State private var inviteCode: String?
    @State private var redeemCode = ""

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Text("tavola.title")
                    .font(AppFont.display())
                    .foregroundStyle(Color.paperDim)
                    .accessibilityAddTraits(.isHeader)

                Text("tavola.motto")
                    .font(AppFont.bodySerif(15, relativeTo: .subheadline))
                    .italic()
                    .foregroundStyle(Color.brassSoft)

                TableRingView(friends: friendships.compactMap(\.person),
                              maxChairs: store.rules.maxFriends)
                    .frame(maxWidth: .infinity)

                if let pending = store.pendingInvitee {
                    fullTablePanel(for: pending)
                }

                inviteCard
                friendsSection
                candidatesSection
            }
            .padding(16)
        }
        .background(Color.ink)
        .confirmationDialog(
            Text(String(format: String(localized: "confirm.libera.title", bundle: L10n.bundle),
                        friendshipToFree?.person?.name ?? "")),
            isPresented: Binding(get: { friendshipToFree != nil },
                                 set: { if !$0 { friendshipToFree = nil } }),
            titleVisibility: .visible
        ) {
            Button("confirm.libera.confirm", role: .destructive) {
                if let friendship = friendshipToFree {
                    store.freeChair(friendship)
                }
                friendshipToFree = nil
            }
            Button("confirm.cancel", role: .cancel) { friendshipToFree = nil }
        } message: {
            Text("confirm.libera.message")
        }
    }

    // MARK: Pannello "tavola piena"

    /// Il 13° invito non aggiunge: spiega. E quando una sedia si libera,
    /// l'invitato in sospeso si siede automaticamente.
    private func fullTablePanel(for pending: Person) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: String(format: String(localized: "tavola.full.message", bundle: L10n.bundle), pending.name))
                .font(AppFont.ui())
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("tavola.full.hint")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.felt)
                Spacer()
                Button("tavola.full.annulla") { store.cancelPendingInvite() }
                    .buttonStyle(QuietPillButtonStyle(tint: .felt))
            }
        }
        .sobreCard(.paperDim)
        .accessibilityElement(children: .combine)
    }

    // MARK: Inviti reali

    /// Ci si trova con un codice: lo generi, lo mandi tu a chi vuoi.
    /// Niente ricerca pubblica delle persone: la tavola resta intima.
    private var inviteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("tavola.invito.title")
                .font(AppFont.ui(15, relativeTo: .subheadline))
                .foregroundStyle(Color.ink)

            if let code = inviteCode {
                HStack(spacing: 12) {
                    Text(verbatim: code)
                        .font(AppFont.title(20, relativeTo: .title3))
                        .foregroundStyle(Color.ink)
                        .textSelection(.enabled)
                    Spacer()
                    ShareLink(item: String(format: String(localized: "invito.messaggio", bundle: L10n.bundle), code)) {
                        Label("tavola.invito.condividi", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PillButtonStyle())
                }
            } else {
                Button("tavola.invito.crea") {
                    Task { inviteCode = await store.createInviteCode() }
                }
                .buttonStyle(QuietPillButtonStyle(tint: .felt))
            }

            Divider().overlay(Color.felt.opacity(0.2))

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

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(textKey: "tavola.friends.section")
            if friendships.isEmpty {
                Text("tavola.friends.empty")
                    .font(AppFont.ui())
                    .foregroundStyle(Color.brassSoft)
            }
            ForEach(friendships, id: \.persistentModelID) { friendship in
                if let person = friendship.person {
                    PersonRow(person: person) {
                        Button("action.libera.sedia") { friendshipToFree = friendship }
                            .buttonStyle(QuietPillButtonStyle(tint: .felt))
                            .accessibilityLabel(Text(verbatim: String(
                                format: String(localized: "a11y.libera.sedia", bundle: L10n.bundle), person.name)))
                    }
                }
            }
        }
    }

    private var candidatesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(textKey: "tavola.candidates.section")
            if candidates.isEmpty {
                // Onestà del prodotto: senza backend non c'è ancora nessuno da invitare.
                Text("tavola.candidates.empty")
                    .font(AppFont.ui())
                    .foregroundStyle(Color.brassSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(candidates, id: \.persistentModelID) { person in
                PersonRow(person: person) {
                    if person.hasPendingInvite {
                        Text("tavola.invito.sospeso")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.felt)
                    } else {
                        Button("action.invita") { store.invite(person) }
                            .buttonStyle(PillButtonStyle())
                            .accessibilityLabel(Text(verbatim: String(
                                format: String(localized: "a11y.invita", bundle: L10n.bundle), person.name)))
                    }
                }
            }
        }
    }
}

// MARK: - Riga persona (amico o candidato) con badge punteggio

/// Card persona: il punteggio compare qui perché è un CONTESTO DECISIONALE
/// (chi invitare, chi far alzare) — mai una classifica.
struct PersonRow<Trailing: View>: View {
    @Environment(AppStore.self) private var store
    let person: Person
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 10) {
            AvatarView(initials: person.initials)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: person.name)
                    .font(AppFont.ui(15, relativeTo: .subheadline))
                    .foregroundStyle(Color.ink)
                Text(verbatim: person.interestKeys.map(\.loc).joined(separator: ", "))
                    .font(AppFont.caption())
                    .foregroundStyle(Color.felt)
                ScoreBadge(score: person.score, band: store.engine.band(for: person.score))
            }
            Spacer()
            trailing
        }
        .sobreCard()
    }
}

// MARK: - La tavola rotonda

/// Elemento firma: 12 sedie in cerchio. Occupate: ottone pieno con iniziali.
/// Libere: tratteggiate. Al centro il conteggio. Animazione discreta
/// (dissolvenza se l'utente riduce le animazioni).
struct TableRingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let friends: [Person]
    let maxChairs: Int
    /// Altezza del disegno: parametrica, così l'onboarding può usarne una ridotta.
    var height: CGFloat = 300

    private let chairSize: CGFloat = 40

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let radius = side / 2 - chairSize / 2
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                // Il piano della tavola.
                SwiftUI.Circle()
                    .fill(Color.felt.opacity(0.5))
                    .frame(width: radius * 1.35, height: radius * 1.35)
                    .position(center)

                // Le 12 sedie.
                ForEach(0..<maxChairs, id: \.self) { index in
                    chair(at: index)
                        .position(chairPosition(index: index, radius: radius, center: center))
                }

                // Il conteggio al centro.
                VStack(spacing: 2) {
                    Text(verbatim: "\(friends.count)/\(maxChairs)")
                        .font(AppFont.display(30, relativeTo: .title))
                        .foregroundStyle(Color.paperDim)
                    Text(verbatim: String.localizedStringWithFormat(
                        String(localized: "tavola.sedie.libere", bundle: L10n.bundle),
                        max(0, maxChairs - friends.count)))
                        .font(AppFont.caption())
                        .foregroundStyle(Color.brassSoft)
                }
                .position(center)
            }
        }
        .frame(height: height)
        .animation(reduceMotion ? .default.speed(2) : .spring(duration: 0.5, bounce: 0.25),
                   value: friends.count)
        // La tavola grafica ha una descrizione testuale equivalente.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: String.localizedStringWithFormat(
            String(localized: "a11y.table", bundle: L10n.bundle),
            friends.count, maxChairs, max(0, maxChairs - friends.count))))
    }

    @ViewBuilder
    private func chair(at index: Int) -> some View {
        if index < friends.count {
            // Sedia occupata: ottone pieno con le iniziali.
            SwiftUI.Circle()
                .fill(Color.brass)
                .overlay(
                    Text(verbatim: friends[index].initials)
                        .font(AppFont.ui(13, relativeTo: .caption))
                        .foregroundStyle(Color.ink)
                )
                .frame(width: chairSize, height: chairSize)
                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
        } else {
            // Sedia libera: tratteggiata.
            SwiftUI.Circle()
                .stroke(Color.brassSoft.opacity(0.55),
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .frame(width: chairSize, height: chairSize)
                .transition(.opacity)
        }
    }

    private func chairPosition(index: Int, radius: CGFloat, center: CGPoint) -> CGPoint {
        let angle = (Double(index) / Double(maxChairs)) * 2 * .pi - .pi / 2
        return CGPoint(x: center.x + radius * cos(angle),
                       y: center.y + radius * sin(angle))
    }
}
