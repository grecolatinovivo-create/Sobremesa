//
//  TuView.swift
//  Sobremesa
//
//  Tu (v3 "Ultima luce"): la persona dietro le parole. In cima l'identità
//  e la presenza (l'unico posto dove vive il numero 0–100, spiegato);
//  sotto, un indice sobrio: come funziona Sobremesa, il tuo momento,
//  la lingua, i crediti; poi sicurezza e privacy (persone bloccate,
//  informativa, condizioni d'uso, assistenza); e — in fondo, lontano dal
//  pollice — l'eliminazione dell'account, detta col suo nome.
//

import SwiftUI
import SwiftData

struct TuView: View {
    @Environment(AppStore.self) private var store
    @Query(filter: #Predicate<Person> { $0.isMe }) private var meQuery: [Person]

    @State private var confirmReset = false

    private var me: Person? { meQuery.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    ScreenTitle(titleKey: "tu.title")
                    if let me {
                        IdentityHeader(me: me)
                    }
                    indice
                    sicurezza
                    Button(role: .destructive) {
                        confirmReset = true
                    } label: {
                        Label("tu.reset", systemImage: "trash")
                            .font(AppFont.ui(15).weight(.medium))
                            .foregroundStyle(Color.warning)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .padding(.top, Space.l)
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.l)
                .padding(.bottom, Space.xxl)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog(Text("tu.reset.confirm.title"),
                                isPresented: $confirmReset,
                                titleVisibility: .visible) {
                Button("tu.reset.confirm.action", role: .destructive) {
                    store.resetAllData()
                }
                Button("confirm.cancel", role: .cancel) { confirmReset = false }
            } message: {
                Text("tu.reset.confirm.message")
            }
        }
    }

    // MARK: L'indice

    private var indice: some View {
        VStack(spacing: 0) {
            NavigationLink {
                ComeFunzionaView()
            } label: {
                IndexRow(icon: "book", titleKey: "tu.comefunziona.title", subtitleKey: "tu.comefunziona.sub")
            }
            Hairline(inset: 40)
            NavigationLink {
                RitualeView()
            } label: {
                IndexRow(icon: "clock", titleKey: "tu.rituale.label",
                         subtitle: store.ritualEnabled ? ritualTime : nil,
                         subtitleKey: store.ritualEnabled ? nil : "tu.rituale.spento")
            }
            Hairline(inset: 40)
            NavigationLink {
                LinguaView()
            } label: {
                IndexRow(icon: "globe", titleKey: "tu.lingua.label",
                         value: store.language == .system
                            ? String(localized: "tu.lingua.sistema", bundle: L10n.bundle)
                            : store.language.endonym)
            }
            Hairline(inset: 40)
            NavigationLink {
                CreditiView()
            } label: {
                IndexRow(icon: "textformat", titleKey: "tu.riconoscimenti.title", subtitleKey: "tu.crediti.sub")
            }
        }
        .buttonStyle(RowPressStyle())
    }

    // MARK: Sicurezza e privacy

    private var sicurezza: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel(textKey: "tu.sicurezza.section")
            VStack(spacing: 0) {
                NavigationLink {
                    BloccatiView()
                } label: {
                    IndexRow(icon: "hand.raised", titleKey: "tu.bloccati.title",
                             value: store.blocked.isEmpty ? nil : "\(store.blocked.count)")
                }
                Hairline(inset: 40)
                Link(destination: SobremesaLinks.privacy) {
                    IndexRow(icon: "lock", titleKey: "tu.privacy.title", external: true)
                }
                Hairline(inset: 40)
                Link(destination: SobremesaLinks.terms) {
                    IndexRow(icon: "doc.text", titleKey: "tu.termini.title", external: true)
                }
                Hairline(inset: 40)
                Link(destination: SobremesaLinks.support) {
                    IndexRow(icon: "envelope", titleKey: "tu.assistenza.title",
                             subtitleKey: "tu.assistenza.sub", external: true)
                }
            }
            .buttonStyle(RowPressStyle())
        }
    }

    private var ritualTime: String {
        let date = Calendar.current.date(bySettingHour: store.ritualMinutes / 60,
                                         minute: store.ritualMinutes % 60,
                                         second: 0, of: .now) ?? .now
        return String(format: String(localized: "tu.rituale.alle", bundle: L10n.bundle),
                      date.formatted(date: .omitted, time: .shortened))
    }
}

// MARK: - Identità e presenza

private struct IdentityHeader: View {
    @Environment(AppStore.self) private var store
    let me: Person
    @State private var draftName = ""
    @FocusState private var editing: Bool

    private var band: ScoreBand { store.engine.band(for: me.score) }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            HStack(alignment: .center, spacing: Space.l) {
                AvatarView(initials: me.initials, size: 64, highlighted: true)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        // Il nome è tuo: si corregge quando vuoi.
                        TextField("tu.nome.placeholder", text: $draftName)
                            .font(AppFont.title(24, relativeTo: .title2))
                            .foregroundStyle(Color.textPrimary)
                            .tint(.brass)
                            .submitLabel(.done)
                            .focused($editing)
                            .onAppear { draftName = me.name }
                            .onSubmit { store.updateName(draftName) }
                            .accessibilityLabel(Text("tu.nome.placeholder"))
                        if !editing {
                            Image(systemName: "pencil")
                                .imageScale(.small)
                                .foregroundStyle(Color.textMuted)
                                .accessibilityHidden(true)
                        }
                    }
                    Text("tu.sottotitolo")
                        .font(AppFont.caption(13))
                        .foregroundStyle(Color.textMuted)
                }
            }

            // La presenza: l'unico posto dove vive il numero.
            VStack(alignment: .leading, spacing: Space.s) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: band.localizedName)
                        .font(AppFont.title(20, relativeTo: .title3))
                        .foregroundStyle(Color.brass)
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(verbatim: "\(me.score)")
                            .font(AppFont.title(22, relativeTo: .title3).monospacedDigit())
                            .foregroundStyle(Color.textPrimary)
                        Text(verbatim: "/ \(store.rules.scoreMax)")
                            .font(AppFont.caption(13))
                            .foregroundStyle(Color.textMuted)
                    }
                }
                PresenceBar(value: Double(me.score) / Double(max(1, store.rules.scoreMax)))
                Text(verbatim: String(format: String(localized: "tu.presenza.spiega", bundle: L10n.bundle),
                                      store.rules.pointsComment,
                                      store.rules.pointsRetake,
                                      abs(store.rules.pointsSilencePenalty)))
                    .font(AppFont.bodySerif(15, relativeTo: .footnote))
                    .italic()
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .panel()
            .accessibilityElement(children: .combine)
        }
    }
}

private struct PresenceBar: View {
    let value: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.elevated)
                Capsule().fill(Color.brass)
                    .frame(width: max(6, geo.size.width * min(1, max(0, value))))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

// MARK: - Riga d'indice

private struct IndexRow: View {
    let icon: String
    let titleKey: LocalizedStringKey
    var subtitle: String? = nil
    var subtitleKey: LocalizedStringKey? = nil
    var value: String? = nil
    /// Apre fuori dall'app (sito, posta): freccia obliqua invece del chevron.
    var external = false

    var body: some View {
        HStack(spacing: Space.l) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.textSecondary)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(titleKey)
                    .font(AppFont.ui(16, relativeTo: .body).weight(.medium))
                    .foregroundStyle(Color.textPrimary)
                if let subtitle {
                    Text(verbatim: subtitle)
                        .font(AppFont.caption(13))
                        .foregroundStyle(Color.textMuted)
                } else if let subtitleKey {
                    Text(subtitleKey)
                        .font(AppFont.caption(13))
                        .foregroundStyle(Color.textMuted)
                }
            }
            Spacer()
            if let value {
                Text(verbatim: value)
                    .font(AppFont.caption(14))
                    .foregroundStyle(Color.textMuted)
            }
            Image(systemName: external ? "arrow.up.right" : "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.textMuted)
                .accessibilityHidden(true)
        }
        .padding(.vertical, Space.l)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
    }
}

// MARK: - Come funziona (il manifesto, reso comprensibile)

struct ComeFunzionaView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                Text("tu.manifesto.text")
                    .font(AppFont.bodySerif(18, relativeTo: .body))
                    .foregroundStyle(Color.textPrimary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Spacer()
                    TableGlyph(occupied: 7, maxSeats: store.rules.maxFriends, warmth: .viva,
                               size: 120, breathing: true)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: Space.l) {
                    regola(icon: "circle.dotted", titleKey: "regola.tavolo.title",
                           text: String(format: String(localized: "regola.tavolo.testo", bundle: L10n.bundle),
                                        store.rules.maxFriends, store.rules.maxCircles))
                    regola(icon: "sparkle", titleKey: "regola.brace.title",
                           text: String(format: String(localized: "regola.brace.testo", bundle: L10n.bundle),
                                        store.rules.tableWarmthAliveHours))
                    regola(icon: "chair", titleKey: "regola.sedia.title",
                           text: String(format: String(localized: "regola.sedia.testo", bundle: L10n.bundle),
                                        store.rules.emberWarningAfterDays, store.rules.emberExpulsionAfterDays))
                    regola(icon: "leaf", titleKey: "regola.nutre.title",
                           text: String(localized: "regola.nutre.testo", bundle: L10n.bundle))
                    regola(icon: "person.wave.2", titleKey: "regola.presenza.title",
                           text: String(format: String(localized: "regola.presenza.testo", bundle: L10n.bundle),
                                        store.rules.bandVoceVivaThreshold,
                                        store.rules.bandPresenzaDiscretaThreshold))
                }
            }
            .padding(Space.gutter)
        }
        .screenBackground()
        .navigationTitle(Text("tu.comefunziona.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func regola(icon: String, titleKey: LocalizedStringKey, text: String) -> some View {
        HStack(alignment: .top, spacing: Space.l) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.brass)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(titleKey)
                    .font(AppFont.title(18, relativeTo: .headline))
                    .foregroundStyle(Color.textPrimary)
                Text(verbatim: text)
                    .font(AppFont.bodySerif(16, relativeTo: .callout))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Il tuo momento

struct RitualeView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                Text("tu.rituale.hint")
                    .font(AppFont.bodySerif(17, relativeTo: .body))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: Space.l) {
                    Toggle(isOn: Binding(get: { store.ritualEnabled },
                                         set: { store.ritualEnabled = $0 })) {
                        Text("tu.rituale.attiva")
                            .font(AppFont.ui(16, relativeTo: .body).weight(.medium))
                            .foregroundStyle(Color.textPrimary)
                    }
                    .tint(.brass)
                    if store.ritualEnabled {
                        Hairline()
                        DatePicker(selection: Binding(
                                       get: {
                                           Calendar.current.date(
                                               bySettingHour: store.ritualMinutes / 60,
                                               minute: store.ritualMinutes % 60,
                                               second: 0, of: .now) ?? .now
                                       },
                                       set: { date in
                                           let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                                           store.ritualMinutes = (parts.hour ?? 21) * 60 + (parts.minute ?? 30)
                                       }),
                                   displayedComponents: .hourAndMinute) {
                            Text("tu.rituale.ora")
                                .font(AppFont.ui(16, relativeTo: .body))
                                .foregroundStyle(Color.textPrimary)
                        }
                        .tint(.brass)
                    }
                }
                .panel()
                .animation(.easeInOut(duration: 0.2), value: store.ritualEnabled)

                VStack(spacing: Space.xs) {
                    Text("notif.rituale.title")
                        .font(AppFont.ui(14).weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text("notif.rituale.body")
                        .font(AppFont.caption(13))
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .panel(.elevated, padding: Space.m)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("tu.rituale.anteprima"))
            }
            .padding(Space.gutter)
        }
        .screenBackground()
        .navigationTitle(Text("tu.rituale.label"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Lingua

struct LinguaView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Text("tu.lingua.hint")
                    .font(AppFont.bodySerif(16, relativeTo: .callout))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 0) {
                    riga(.system, label: String(localized: "tu.lingua.sistema", bundle: L10n.bundle))
                    ForEach(AppLanguage.choices, id: \.self) { lingua in
                        Hairline()
                        // Gli endonimi non si traducono: ognuno riconosce la sua.
                        riga(lingua, label: lingua.endonym)
                    }
                }
            }
            .padding(Space.gutter)
        }
        .screenBackground()
        .navigationTitle(Text("tu.lingua.label"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func riga(_ lingua: AppLanguage, label: String) -> some View {
        Button {
            store.language = lingua
        } label: {
            HStack {
                Text(verbatim: label)
                    .font(AppFont.ui(16, relativeTo: .body))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                if store.language == lingua {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.brass)
                }
            }
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(store.language == lingua ? [.isSelected] : [])
    }
}

// MARK: - Persone bloccate

struct BloccatiView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Text("tu.bloccati.hint")
                    .font(AppFont.bodySerif(16, relativeTo: .callout))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if store.blocked.isEmpty {
                    Text("tu.bloccati.vuoto")
                        .font(AppFont.bodySerif(16, relativeTo: .callout))
                        .italic()
                        .foregroundStyle(Color.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.xl)
                } else {
                    VStack(spacing: 0) {
                        ForEach(store.blocked) { person in
                            HStack(spacing: Space.m) {
                                AvatarView(initials: Self.initials(person.name), size: 36)
                                Text(verbatim: person.name)
                                    .font(AppFont.ui(16, relativeTo: .body).weight(.medium))
                                    .foregroundStyle(Color.textPrimary)
                                Spacer()
                                Button("blocca.sblocca") { store.unblock(person) }
                                    .buttonStyle(SecondaryButtonStyle())
                            }
                            .padding(.vertical, Space.s)
                            if person.id != store.blocked.last?.id { Hairline(inset: 36 + Space.m) }
                        }
                    }
                }
            }
            .padding(Space.gutter)
            .animation(.easeInOut(duration: 0.2), value: store.blocked)
        }
        .screenBackground()
        .navigationTitle(Text("tu.bloccati.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private static func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).map { String($0.prefix(1)) }.joined()
    }
}

// MARK: - Crediti

struct CreditiView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Text("tu.riconoscimenti.text")
                    .font(AppFont.bodySerif(17, relativeTo: .body))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("tu.crediti.design")
                    .font(AppFont.bodySerif(15, relativeTo: .footnote))
                    .italic()
                    .foregroundStyle(Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Space.gutter)
        }
        .screenBackground()
        .navigationTitle(Text("tu.riconoscimenti.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
