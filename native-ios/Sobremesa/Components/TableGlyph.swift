//
//  TableGlyph.swift
//  Sobremesa
//
//  La firma visiva di Sobremesa (v3.1, dai mockup di Astra, round 6):
//  un tavolo tondo visto dall'alto, con DODICI SEDIE vere (seduta e
//  schienale curvo, filo d'ottone), il piano in feltro illuminato dal
//  centro e, al centro, una CANDELA nel piattino d'ottone: la brace.
//
//  - sedia occupata = cuscino di cuoio caldo + filo d'ottone pieno;
//    libera = solo un filo d'ottone tenue; la mia = cornice d'ottone;
//  - la fiamma dice lo stato del TAVOLO (collettivo):
//      viva → fiamma piena, alone caldo che illumina il piano;
//      si affievolisce → fiamma bassa, luce debole;
//      in attesa → candela spenta (solo lo stoppino);
//  - la fiamma si muove (respiro lento + tremolio minimo + luce che
//    pulsa sul tavolo) solo dove `animated` è vero e mai con Reduce Motion.
//    Nelle liste resta ferma: il movimento è per la stanza e l'ingresso.
//

import SwiftUI

// MARK: - Il tavolo

struct TableGlyph: View {
    /// Sedie occupate (0…maxSeats), in ordine d'arrivo.
    let occupied: Int
    let maxSeats: Int
    let warmth: TableWarmth
    /// Il mio posto nell'ordine d'arrivo (nil se non siedo).
    var mySeat: Int? = nil
    var size: CGFloat = 44
    /// La fiamma si muove (stanza, onboarding, commensali).
    var breathing = false
    /// Da quale sedia (in senso orario da ore 12) parte l'ordine d'arrivo:
    /// con 1, la sedia di ore 12 resta libera ("c'è sempre una sedia per te").
    var startIndex = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if breathing && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    canvas(time: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                canvas(time: 0.7)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: String.localizedStringWithFormat(
            String(localized: "a11y.table", bundle: L10n.bundle),
            occupied, maxSeats, max(0, maxSeats - occupied))))
        .accessibilityValue(Text(verbatim: warmth.label))
    }

    private func canvas(time: Double) -> some View {
        Canvas { context, canvasSize in
            TableDrawing(occupied: occupied, maxSeats: maxSeats, warmth: warmth,
                         mySeat: mySeat, startIndex: startIndex, time: time)
                .draw(in: &context, size: canvasSize)
        }
    }
}

// MARK: - Il disegno (puro, riusato da TableGlyph e SeatRing)

struct TableDrawing {
    let occupied: Int
    let maxSeats: Int
    let warmth: TableWarmth
    let mySeat: Int?
    let startIndex: Int
    let time: Double

    /// Proporzioni (frazioni del lato).
    static let tableRadius: CGFloat = 0.30
    static let chairRing: CGFloat = 0.405
    static let chairWidth: CGFloat = 0.13
    static let chairDepth: CGFloat = 0.12

    /// L'angolo della sedia `index` (0 = ore 12, senso orario).
    static func angle(of index: Int, of count: Int) -> Double {
        Double(index) / Double(count) * 2 * .pi - .pi / 2
    }

    private func isOccupied(_ index: Int) -> Bool {
        let order = (index - startIndex + maxSeats) % maxSeats
        return order < occupied
    }

    private func isMine(_ index: Int) -> Bool {
        guard let mySeat else { return false }
        return (index - startIndex + maxSeats) % maxSeats == mySeat
    }

    /// Quanta luce fa la candela sul piano.
    private var lit: CGFloat {
        switch warmth {
        case .viva: return 1
        case .siAffievolisce: return 0.45
        case .inAttesa: return 0
        }
    }

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let side = min(size.width, size.height)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        drawChairs(&context, side: side, center: center)
        drawTable(&context, side: side, center: center)
        drawCandle(&context, side: side, center: center)
    }

    // MARK: Le sedie

    private func drawChairs(_ context: inout GraphicsContext, side: CGFloat, center: CGPoint) {
        let ring = side * Self.chairRing
        let width = side * Self.chairWidth * 0.92
        let depth = side * Self.chairDepth
        let line = max(0.7, side * 0.008)

        for index in 0..<maxSeats {
            let angle = Self.angle(of: index, of: maxSeats)
            var chair = context
            chair.translateBy(x: center.x + ring * cos(angle), y: center.y + ring * sin(angle))
            chair.rotate(by: .radians(angle + .pi / 2))
            // Nello spazio della sedia: −y = verso l'esterno (lo schienale).
            let occupiedSeat = isOccupied(index)
            let seatHeight = depth * 0.62
            let seatY = -seatHeight / 2 + depth * 0.18
            let seat = Path(roundedRect: CGRect(x: -width / 2, y: seatY, width: width, height: seatHeight),
                            cornerRadius: width * 0.22)
            if occupiedSeat {
                chair.fill(seat, with: .radialGradient(
                    Gradient(colors: [.chairLeather, .chairLeatherDeep]),
                    center: CGPoint(x: 0, y: seatY + seatHeight * 0.4),
                    startRadius: 0, endRadius: width * 0.8))
            } else {
                chair.fill(seat, with: .color(.chairEmpty))
            }
            let wire: Color = occupiedSeat ? .brass : .brass.opacity(0.32)
            chair.stroke(seat, with: .color(wire), lineWidth: line)

            // Lo schienale: un arco curvo, staccato dalla seduta.
            let backRadius = width * 0.8
            let gap = depth * 0.1
            let arcCenter = CGPoint(x: 0, y: seatY - gap + backRadius)
            var back = Path()
            back.addArc(center: arcCenter, radius: backRadius,
                        startAngle: .radians(.pi * 1.28), endAngle: .radians(.pi * 1.72), clockwise: false)
            chair.stroke(back, with: .color(wire),
                         style: StrokeStyle(lineWidth: max(1, side * 0.022), lineCap: .round))
            if occupiedSeat {
                var shine = Path()
                shine.addArc(center: arcCenter, radius: backRadius,
                             startAngle: .radians(.pi * 1.33), endAngle: .radians(.pi * 1.67), clockwise: false)
                chair.stroke(shine, with: .color(.flameCore.opacity(0.55)),
                             style: StrokeStyle(lineWidth: max(0.4, side * 0.006), lineCap: .round))
            }
            if isMine(index) {
                let frame = Path(roundedRect: CGRect(x: -width * 0.78, y: -depth * 0.62,
                                                     width: width * 1.56, height: depth * 1.35),
                                 cornerRadius: width * 0.42)
                chair.stroke(frame, with: .color(.brass.opacity(0.9)), lineWidth: max(1, side * 0.01))
            }
        }
    }

    // MARK: Il piano in feltro

    private func drawTable(_ context: inout GraphicsContext, side: CGFloat, center: CGPoint) {
        let radius = side * Self.tableRadius
        let disc = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                          width: radius * 2, height: radius * 2))
        context.fill(disc, with: .radialGradient(Gradient(colors: [.surface, .feltEdge]),
                                                 center: center, startRadius: 0, endRadius: radius))
        // La luce della candela sul feltro (respira con la fiamma).
        if lit > 0 {
            let pulse = 1 + 0.04 * sin(time * 2.1) + 0.02 * sin(time * 5.3)
            context.fill(disc, with: .radialGradient(
                Gradient(stops: [
                    .init(color: .feltLit.opacity(0.75 * lit), location: 0),
                    .init(color: .emberAlive.opacity(0.22 * lit), location: 0.35),
                    .init(color: .emberAlive.opacity(0), location: 1)
                ]),
                center: center, startRadius: 0, endRadius: radius * 0.9 * pulse))
        }
        // Il filo d'ottone del bordo, con un'ombra appena dentro.
        context.stroke(disc, with: .linearGradient(
            Gradient(colors: [.flameGold, .brass, .chairLeather, .brass]),
            startPoint: CGPoint(x: center.x - radius, y: center.y - radius),
            endPoint: CGPoint(x: center.x + radius, y: center.y + radius)),
            lineWidth: max(0.8, side * 0.013))
        let inner = Path(ellipseIn: CGRect(x: center.x - radius + side * 0.012, y: center.y - radius + side * 0.012,
                                           width: (radius - side * 0.012) * 2, height: (radius - side * 0.012) * 2))
        context.stroke(inner, with: .color(.background.opacity(0.45)), lineWidth: max(0.5, side * 0.01))
    }

    // MARK: La candela

    private func drawCandle(_ context: inout GraphicsContext, side: CGFloat, center: CGPoint) {
        let small = side < 60
        // Il piattino d'ottone.
        let dishRadius = side * 0.04
        let dishCenter = CGPoint(x: center.x, y: center.y + side * 0.012)
        let dish = Path(ellipseIn: CGRect(x: dishCenter.x - dishRadius, y: dishCenter.y - dishRadius,
                                          width: dishRadius * 2, height: dishRadius * 2))
        context.fill(dish, with: .color(.chairLeatherDeep))
        context.stroke(dish, with: .color(.brass), lineWidth: max(0.7, side * 0.009))

        guard warmth != .inAttesa else {
            // Candela spenta: solo lo stoppino.
            var wick = Path()
            wick.move(to: CGPoint(x: center.x, y: dishCenter.y))
            wick.addLine(to: CGPoint(x: center.x, y: dishCenter.y - side * 0.024))
            context.stroke(wick, with: .color(.emberWaiting.opacity(0.8)),
                           style: StrokeStyle(lineWidth: max(0.8, side * 0.01), lineCap: .round))
            return
        }

        let strength: CGFloat = warmth == .viva ? 1 : 0.62
        // Respiro lento (±5 %) + tremolio minimo, mai nervoso.
        let breath = 1 + 0.05 * sin(time * 1.4) + 0.03 * sin(time * 7.7) + 0.015 * sin(time * 13.1)
        let height = side * (small ? 0.16 : 0.11) * strength * breath
        let width = side * (small ? 0.085 : 0.055) * strength
        let sway = side * 0.012 * strength * sin(time * 3.3)
        let base = CGPoint(x: center.x, y: center.y + side * 0.025)

        // L'alone della fiamma.
        let glowRadius = height * (small ? 1.6 : 1.3)
        let glowCenter = CGPoint(x: base.x, y: base.y - height * 0.4)
        let glowColor: Color = warmth == .viva ? .emberAlive : .emberFading
        context.fill(Path(ellipseIn: CGRect(x: glowCenter.x - glowRadius, y: glowCenter.y - glowRadius,
                                            width: glowRadius * 2, height: glowRadius * 2)),
                     with: .radialGradient(Gradient(colors: [glowColor.opacity(warmth == .viva ? 0.7 : 0.4),
                                                             glowColor.opacity(0)]),
                                           center: glowCenter, startRadius: 0, endRadius: glowRadius))

        // La fiamma: una goccia che punta in alto e ondeggia appena.
        var flame = Path()
        flame.move(to: base)
        flame.addCurve(to: CGPoint(x: base.x + sway, y: base.y - height),
                       control1: CGPoint(x: base.x - width * 0.75, y: base.y - height * 0.05),
                       control2: CGPoint(x: base.x - width * 0.45, y: base.y - height * 0.65))
        flame.addCurve(to: base,
                       control1: CGPoint(x: base.x + width * 0.45, y: base.y - height * 0.65),
                       control2: CGPoint(x: base.x + width * 0.75, y: base.y - height * 0.05))
        let colors: [Gradient.Stop] = warmth == .viva
            ? [.init(color: .flameCore, location: 0), .init(color: .flameGold, location: 0.35),
               .init(color: .emberAlive, location: 0.8), .init(color: .emberAlive.opacity(0.6), location: 1)]
            : [.init(color: .emberFading, location: 0), .init(color: .emberFading.opacity(0.5), location: 1)]
        context.fill(flame, with: .linearGradient(Gradient(stops: colors),
                                                  startPoint: base,
                                                  endPoint: CGPoint(x: base.x, y: base.y - height)))
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

// MARK: - Il tavolo grande dei commensali (con le iniziali sulle sedie)

/// Versione "foglio dei commensali" (~240 pt): lo stesso tavolo, con le
/// iniziali di chi siede sulle sedie occupate, in ordine d'arrivo.
struct SeatRing: View {
    let people: [Person]
    let maxSeats: Int
    let warmth: TableWarmth
    var size: CGFloat = 240

    var body: some View {
        let ring = size * TableDrawing.chairRing
        ZStack {
            TableGlyph(occupied: people.count, maxSeats: maxSeats, warmth: warmth,
                       mySeat: people.firstIndex { $0.isMe }, size: size, breathing: true)
            ForEach(Array(people.prefix(maxSeats).enumerated()), id: \.offset) { index, person in
                let angle = TableDrawing.angle(of: index, of: maxSeats)
                Text(verbatim: person.initials)
                    .font(AppFont.ui(max(10, size * 0.046), relativeTo: .caption2).weight(.semibold))
                    .foregroundStyle(person.isMe ? Color.brass : Color.textPrimary)
                    .minimumScaleFactor(0.6)
                    .frame(width: size * TableDrawing.chairWidth)
                    // Le iniziali stanno sul cuscino (un filo più verso il tavolo).
                    .offset(x: (ring - size * 0.012) * cos(angle), y: (ring - size * 0.012) * sin(angle))
                    .accessibilityHidden(true)
            }
        }
        .frame(width: size, height: size)
    }
}
