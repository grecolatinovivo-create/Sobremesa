//
//  TableRingView.swift
//  Sobremesa
//
//  L'elemento firma: le 12 sedie in cerchio. Occupate: ottone pieno con
//  le iniziali. Libere: tratteggiate. Al centro il conteggio.
//  Usata nell'onboarding (tavola vuota) e nella stanza del tavolo.
//

import SwiftUI

struct TableRingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let friends: [Person]
    let maxChairs: Int
    /// Altezza del disegno: parametrica (l'onboarding ne usa una ridotta).
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

/// Riga di stato della brace (pallino + testo), condivisa da Salotto e stanza.
struct EmberLine: View {
    let state: EmberState
    /// Giorni al tavolo: se la brace è viva, l'anzianità rende visibile
    /// cosa si perderebbe (endowment effect, sobrio).
    var sinceDays: Int? = nil

    var body: some View {
        HStack(spacing: 6) {
            SwiftUI.Circle().fill(color).frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(verbatim: label)
                .font(AppFont.caption())
                .foregroundStyle(color)
        }
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch state {
        case .viva: return .successTone
        case .affievolita: return .brassSoft
        case .avviso, .espulsione: return .errorSoft
        }
    }

    private var label: String {
        switch state {
        case .viva:
            if let sinceDays {
                return String.localizedStringWithFormat(
                    String(localized: "brace.viva.giorni", bundle: L10n.bundle), sinceDays)
            }
            return String(localized: "brace.viva", bundle: L10n.bundle)
        case .affievolita(let giorni):
            return String.localizedStringWithFormat(String(localized: "brace.affievolita", bundle: L10n.bundle), giorni)
        case .avviso(let giorni), .espulsione(let giorni):
            return String.localizedStringWithFormat(String(localized: "brace.avviso", bundle: L10n.bundle), giorni)
        }
    }
}
