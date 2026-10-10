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

    @ViewBuilder
    private func canvas(time: Double) -> some View {
        // Se ci sono gli asset dipinti da Astra (feltro, cuoio, ottone, candela)
        // il tavolo si compone con quelli; altrimenti resta il disegno a codice.
        if AssetTable.available {
            AssetTable(occupied: occupied, maxSeats: maxSeats, warmth: warmth,
                       mySeat: mySeat, startIndex: startIndex, size: size, time: time)
        } else {
            Canvas { context, canvasSize in
                TableDrawing(occupied: occupied, maxSeats: maxSeats, warmth: warmth,
                             mySeat: mySeat, startIndex: startIndex, time: time)
                    .draw(in: &context, size: canvasSize)
            }
        }
    }
}

// MARK: - Il tavolo composto con gli asset illustrati (handoff di Astra, sezione F)

struct AssetTable: View {
    let occupied: Int
    let maxSeats: Int
    let warmth: TableWarmth
    let mySeat: Int?
    let startIndex: Int
    let size: CGFloat
    let time: Double

    static let available = UIImage(named: "table_top") != nil
        && UIImage(named: "chair_occupied") != nil
        && UIImage(named: "chair_free") != nil
        && UIImage(named: "candle_dish") != nil

    /// Proporzioni (frazioni del lato), tarate sul dettaglio dei tre stati.
    static let tableSide: CGFloat = 0.72
    static let chairRing: CGFloat = 0.415
    static let chairSide: CGFloat = 0.17
    static let dishSide: CGFloat = 0.15

    private func order(_ index: Int) -> Int { (index - startIndex + maxSeats) % maxSeats }

    private var lit: Double {
        switch warmth {
        case .viva: return 1
        case .siAffievolisce: return 0.45
        case .inAttesa: return 0
        }
    }

    var body: some View {
        let ring = size * Self.chairRing
        let pulse = 1 + 0.05 * sin(time * 2.1) + 0.02 * sin(time * 5.3)
        ZStack {
            // Le sedie, rivolte verso il tavolo (schienale verso l'esterno).
            ForEach(0..<maxSeats, id: \.self) { index in
                let angle = TableDrawing.angle(of: index, of: maxSeats)
                let taken = order(index) < occupied
                ZStack {
                    Image(taken ? "chair_occupied" : "chair_free")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .opacity(taken ? 1 : 0.85)
                    if let mySeat, order(index) == mySeat {
                        RoundedRectangle(cornerRadius: size * 0.03, style: .continuous)
                            .strokeBorder(Color.brass, lineWidth: max(1, size * 0.008))
                            .padding(-size * 0.008)
                    }
                }
                .frame(width: size * Self.chairSide, height: size * Self.chairSide)
                .rotationEffect(.radians(angle + .pi / 2))
                .offset(x: ring * cos(angle), y: ring * sin(angle))
            }

            // Il piano in feltro.
            Image("table_top")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size * Self.tableSide, height: size * Self.tableSide)

            // La luce della candela sul feltro.
            if lit > 0 {
                SwiftUI.Circle()
                    .fill(RadialGradient(
                        colors: [Color.emberAlive.opacity(0.42 * lit), Color.emberAlive.opacity(0.12 * lit), .clear],
                        center: .center, startRadius: 0, endRadius: size * 0.3 * pulse))
                    .frame(width: size * 0.64, height: size * 0.64)
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }

            // Il piattino con la candela.
            Image("candle_dish")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size * Self.dishSide, height: size * Self.dishSide)

            if warmth != .inAttesa {
                flame
            }
        }
        .frame(width: size, height: size)
    }

    /// La fiamma: fotogrammi dipinti (flame_1…4) a ciclo, più un respiro lento.
    @ViewBuilder
    private var flame: some View {
        let strength: CGFloat = warmth == .viva ? 1 : 0.6
        let breath = 1 + 0.03 * sin(time * 1.4) + 0.02 * sin(time * 7.7)
        let frame = Int((time * 8).rounded(.down)) % 4 + 1
        let height = size * 0.13 * strength * breath
        let name = UIImage(named: "flame_\(frame)") != nil ? "flame_\(frame)" : "flame_1"
        ZStack {
            SwiftUI.Circle()
                .fill(RadialGradient(colors: [Color.emberAlive.opacity(warmth == .viva ? 0.6 : 0.35), .clear],
                                     center: .center, startRadius: 0, endRadius: height * 0.9))
                .frame(width: height * 1.8, height: height * 1.8)
            if UIImage(named: name) != nil {
                Image(name)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(height: height)
                    .saturation(warmth == .viva ? 1 : 0.6)
            }
        }
        .offset(y: -height * 0.42)
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
    static let tableRadius: CGFloat = 0.355
    static let chairRing: CGFloat = 0.415
    static let chairWidth: CGFloat = 0.15
    static let chairDepth: CGFloat = 0.14

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
            let seatHeight = depth * 0.66
            let seatY = -seatHeight / 2 + depth * 0.12
            let seat = Path(roundedRect: CGRect(x: -width / 2, y: seatY, width: width, height: seatHeight),
                            cornerRadius: width * 0.22)
            if occupiedSeat {
                chair.fill(seat, with: .radialGradient(
                    Gradient(colors: [.chairLeather, .chairLeatherDeep]),
                    center: CGPoint(x: 0, y: seatY + seatHeight * 0.4),
                    startRadius: 0, endRadius: width * 0.8))
            } else {
                chair.fill(seat, with: .color(.chairEmpty.opacity(0.35)))
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
                let frame = Path(roundedRect: CGRect(x: -width * 0.68, y: -depth * 0.58,
                                                     width: width * 1.36, height: depth * 1.16),
                                 cornerRadius: width * 0.4)
                chair.stroke(frame, with: .color(.brass.opacity(0.9)), lineWidth: max(1, side * 0.01))
            }
        }
    }

    // MARK: Il piano in feltro

    private func drawTable(_ context: inout GraphicsContext, side: CGFloat, center: CGPoint) {
        let radius = side * Self.tableRadius
        let disc = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                          width: radius * 2, height: radius * 2))
        context.fill(disc, with: .radialGradient(Gradient(colors: [.elevated, .surface, .feltEdge]),
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
        let dishRadius = side * 0.06
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
        let breath = 1 + 0.035 * sin(time * 1.4) + 0.025 * sin(time * 7.7) + 0.012 * sin(time * 13.1)
        let height = side * (small ? 0.17 : 0.13) * strength * breath
        let width = side * (small ? 0.08 : 0.06) * strength
        let sway = side * 0.012 * strength * sin(time * 3.3)
        let base = CGPoint(x: center.x, y: center.y + side * 0.03)

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
