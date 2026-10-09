//
//  TableGlyph.swift
//  Sobremesa
//
//  La firma visiva di Sobremesa (v3 "Ultima luce", disegno di Astra):
//  il tavolo visto dall'alto — dodici posti su una circonferenza attorno
//  a un centro caldo, la BRACE. Lo stesso segno vive in tre scale:
//  44 pt nelle liste, 88 pt nella stanza, ~228 pt nel foglio dei commensali.
//
//  Regole:
//  - posto occupato = pieno; libero = solo contorno; il mio = anello ottone;
//  - la brace dice lo stato del TAVOLO (collettivo), mai il punteggio;
//  - il disegno dei posti è statico; l'eventuale respiro della brace è
//    un layer separato (±1,5 %, ciclo 4,5 s), spento con Reduce Motion
//    e sempre spento nelle liste.
//

import SwiftUI

// MARK: - La brace

struct EmberCore: View {
    let warmth: TableWarmth
    var breathing = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var inhale = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                // Alone: solo quando il tavolo è vivo.
                if warmth == .viva {
                    SwiftUI.Circle()
                        .fill(RadialGradient(colors: [Color.emberAlive.opacity(0.45), Color.emberAlive.opacity(0)],
                                             center: .center, startRadius: 0, endRadius: side * 0.5))
                        .frame(width: side, height: side)
                }
                // Nucleo irregolare.
                EmberBlob()
                    .fill(coreGradient(side: side))
                    .frame(width: side * coreScale, height: side * coreScale)
                    .overlay {
                        if warmth == .inAttesa {
                            EmberBlob()
                                .stroke(Color.emberWaiting.opacity(0.8), lineWidth: max(1, side * 0.03))
                                .frame(width: side * coreScale, height: side * coreScale)
                        }
                    }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .scaleEffect(inhale ? 1.015 : 1)
        }
        .onAppear {
            guard breathing, warmth == .viva, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.25).repeatForever(autoreverses: true)) {
                inhale = true
            }
        }
        .accessibilityHidden(true)
    }

    private var coreScale: CGFloat {
        switch warmth {
        case .viva: return 0.46
        case .siAffievolisce: return 0.38
        case .inAttesa: return 0.32
        }
    }

    private func coreGradient(side: CGFloat) -> RadialGradient {
        switch warmth {
        case .viva:
            return RadialGradient(colors: [Color(white: 1).opacity(0.85), .emberAlive, .emberAlive.opacity(0.85)],
                                  center: UnitPoint(x: 0.45, y: 0.42), startRadius: 0, endRadius: side * 0.25)
        case .siAffievolisce:
            return RadialGradient(colors: [.emberFading, .emberFading.opacity(0.7)],
                                  center: .center, startRadius: 0, endRadius: side * 0.2)
        case .inAttesa:
            return RadialGradient(colors: [.emberWaiting.opacity(0.35), .emberWaiting.opacity(0.15)],
                                  center: .center, startRadius: 0, endRadius: side * 0.16)
        }
    }
}

/// Il nucleo della brace: un disco appena irregolare (non una fiamma).
struct EmberBlob: Shape {
    func path(in rect: CGRect) -> Path {
        // Dieci punti su un cerchio con raggi leggermente diversi, uniti da curve morbide.
        let radii: [CGFloat] = [1.0, 0.93, 0.98, 0.9, 1.0, 0.95, 0.88, 0.97, 0.92, 1.0]
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let pts: [CGPoint] = radii.enumerated().map { i, k in
            let a = Double(i) / Double(radii.count) * 2 * .pi - .pi / 2
            return CGPoint(x: c.x + r * k * cos(a), y: c.y + r * k * sin(a))
        }
        var p = Path()
        let mid = { (a: CGPoint, b: CGPoint) in CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        p.move(to: mid(pts[pts.count - 1], pts[0]))
        for i in pts.indices {
            let next = pts[(i + 1) % pts.count]
            p.addQuadCurve(to: mid(pts[i], next), control: pts[i])
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Il tavolo

struct TableGlyph: View {
    /// Posti occupati (0…maxSeats).
    let occupied: Int
    let maxSeats: Int
    let warmth: TableWarmth
    /// Indice del mio posto tra gli occupati (nil se non siedo).
    var mySeat: Int? = nil
    var size: CGFloat = 44
    var breathing = false

    var body: some View {
        ZStack {
            Canvas { context, canvasSize in
                let side = min(canvasSize.width, canvasSize.height)
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let seatSize = side * 0.13
                let ringRadius = side / 2 - seatSize / 2 - 1
                let tableRadius = side * 0.30

                // Il piano del tavolo.
                let table = Path(ellipseIn: CGRect(x: center.x - tableRadius, y: center.y - tableRadius,
                                                   width: tableRadius * 2, height: tableRadius * 2))
                context.fill(table, with: .color(Color.surface))
                context.stroke(table, with: .color(Color.divider), lineWidth: max(0.75, side * 0.008))

                // I dodici posti, a 30° l'uno dall'altro, partendo da −90°.
                for index in 0..<maxSeats {
                    let angle = Double(index) / Double(maxSeats) * 2 * .pi - .pi / 2
                    let point = CGPoint(x: center.x + ringRadius * cos(angle),
                                        y: center.y + ringRadius * sin(angle))
                    let rect = CGRect(x: point.x - seatSize / 2, y: point.y - seatSize / 2,
                                      width: seatSize, height: seatSize)
                    let seat = Path(roundedRect: rect, cornerRadius: seatSize * 0.32)
                    if index < occupied {
                        context.fill(seat, with: .color(Color.brass.opacity(0.92)))
                        if index == mySeat {
                            let halo = Path(roundedRect: rect.insetBy(dx: -seatSize * 0.28, dy: -seatSize * 0.28),
                                            cornerRadius: seatSize * 0.5)
                            context.stroke(halo, with: .color(Color.brass), lineWidth: max(1, side * 0.012))
                        }
                    } else {
                        context.stroke(seat, with: .color(Color.outline), lineWidth: max(0.75, side * 0.01))
                    }
                }
            }
            EmberCore(warmth: warmth, breathing: breathing)
                .frame(width: size * 0.5, height: size * 0.5)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: String.localizedStringWithFormat(
            String(localized: "a11y.table", bundle: L10n.bundle),
            occupied, maxSeats, max(0, maxSeats - occupied))))
        .accessibilityValue(Text(verbatim: warmth.label))
    }
}

// MARK: - Etichetta del calore (sempre testo, mai solo colore)

extension TableWarmth {
    var label: String {
        switch self {
        case .viva:           return String(localized: "calore.viva", bundle: L10n.bundle)
        case .siAffievolisce: return String(localized: "calore.affievolisce", bundle: L10n.bundle)
        case .inAttesa:       return String(localized: "calore.attesa", bundle: L10n.bundle)
        }
    }

    var tint: Color {
        switch self {
        case .viva:           return .emberAlive
        case .siAffievolisce: return .emberFading
        case .inAttesa:       return .emberWaiting
        }
    }
}

struct WarmthLabel: View {
    let warmth: TableWarmth
    var body: some View {
        HStack(spacing: 6) {
            SwiftUI.Circle().fill(warmth.tint).frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Text(verbatim: warmth.label)
                .font(AppFont.caption(13, relativeTo: .caption).weight(.medium))
                .foregroundStyle(warmth.tint)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Calcolo del calore per un tavolo (dai dati locali)

extension AppStore {
    /// Calore collettivo: dall'ultimo intervento di CHIUNQUE al tavolo.
    func warmth(of tavolo: Tavolo, lastMessageAt: Date?) -> TableWarmth {
        engine.tableWarmth(memberCount: tavolo.memberCount, lastMessageAt: lastMessageAt, now: .now)
    }
}

// MARK: - L'anello grande dei commensali (con le iniziali sui posti)

/// Versione "foglio dei commensali" del tavolo (~228 pt): sui posti
/// occupati compaiono le iniziali, in ordine d'arrivo; il mio posto è
/// cerchiato d'ottone; i liberi sono tratteggiati.
struct SeatRing: View {
    let people: [Person]
    let maxSeats: Int
    let warmth: TableWarmth
    var size: CGFloat = 228

    var body: some View {
        let seat = size * 0.16
        let ringRadius = size / 2 - seat / 2
        ZStack {
            SwiftUI.Circle()
                .fill(Color.surface)
                .overlay(SwiftUI.Circle().strokeBorder(Color.divider, lineWidth: 1))
                .frame(width: size * 0.56, height: size * 0.56)
            EmberCore(warmth: warmth, breathing: true)
                .frame(width: size * 0.36, height: size * 0.36)
            ForEach(0..<maxSeats, id: \.self) { index in
                let angle = Double(index) / Double(maxSeats) * 2 * .pi - .pi / 2
                seatView(index: index, side: seat)
                    .offset(x: ringRadius * cos(angle), y: ringRadius * sin(angle))
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: String.localizedStringWithFormat(
            String(localized: "a11y.table", bundle: L10n.bundle),
            people.count, maxSeats, max(0, maxSeats - people.count))))
        .accessibilityValue(Text(verbatim: warmth.label))
    }

    @ViewBuilder
    private func seatView(index: Int, side: CGFloat) -> some View {
        if index < people.count {
            let person = people[index]
            SwiftUI.Circle()
                .fill(person.isMe ? Color.brass : Color.elevated)
                .overlay(SwiftUI.Circle().strokeBorder(person.isMe ? Color.brass : Color.outline, lineWidth: 1))
                .overlay(
                    Text(verbatim: person.initials)
                        .font(AppFont.ui(side * 0.36, relativeTo: .caption2).weight(.semibold))
                        .foregroundStyle(person.isMe ? Color.brassInk : Color.textSecondary)
                        .minimumScaleFactor(0.6)
                )
                .frame(width: side, height: side)
        } else {
            SwiftUI.Circle()
                .strokeBorder(Color.outline, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .frame(width: side, height: side)
        }
    }
}
