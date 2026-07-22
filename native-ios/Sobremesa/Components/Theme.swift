//
//  Theme.swift
//  Sobremesa
//
//  Design system: "la sala lettura di una biblioteca la sera".
//  UNICO punto del codice che nomina colori (per nome asset, mai literal)
//  e famiglie di font (con fallback dichiarato sui font di sistema).
//

import SwiftUI
import UIKit

// MARK: - Colori (dagli Asset, mai literal)

extension Color {
    static let ink        = Color("Ink")         // sfondo dell'app
    static let felt       = Color("Felt")        // superfici scure
    static let paper      = Color("Paper")       // card avorio
    static let paperDim   = Color("PaperDim")    // avorio smorzato
    static let brass      = Color("Brass")       // accento / CTA
    static let brassSoft  = Color("BrassSoft")   // dettagli ottone su scuro
    static let errorTone  = Color("ErrorTone")   // errori, avviso brace
    static let successTone = Color("SuccessTone")// conferme, brace viva
}

// MARK: - Tipografia (con fallback dichiarato)

/// Young Serif per i titoli e i numeri, Source Serif 4 per il corpo dei post,
/// Inter per la UI. Se il bundling di un font fallisse, il fallback è
/// dichiarato: .serif / .default di sistema. Tutto è Dynamic Type (relativeTo:).
enum AppFont {

    private static let youngSerif = "Young Serif"
    private static let sourceSerif = "Source Serif 4"
    private static let inter = "Inter"

    /// Il font di famiglia `family` è realmente disponibile a runtime?
    private static func available(_ family: String) -> Bool {
        UIFont.familyNames.contains(family)
    }

    private static func custom(_ family: String,
                               size: CGFloat,
                               relativeTo style: Font.TextStyle,
                               fallback design: Font.Design) -> Font {
        if available(family) {
            return .custom(family, size: size, relativeTo: style)
        }
        // Fallback dichiarato: serif/sans di sistema, sempre Dynamic Type.
        return .system(style, design: design)
    }

    /// Titoli grandi e numeri (Young Serif).
    static func display(_ size: CGFloat = 34, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        custom(youngSerif, size: size, relativeTo: style, fallback: .serif)
    }

    /// Titoli di card e sezioni (Young Serif).
    static func title(_ size: CGFloat = 24, relativeTo style: Font.TextStyle = .title2) -> Font {
        custom(youngSerif, size: size, relativeTo: style, fallback: .serif)
    }

    /// Corpo dei post e dei commenti (Source Serif 4).
    static func bodySerif(_ size: CGFloat = 17, relativeTo style: Font.TextStyle = .body) -> Font {
        custom(sourceSerif, size: size, relativeTo: style, fallback: .serif)
    }

    /// Testo di interfaccia (Inter).
    static func ui(_ size: CGFloat = 15, relativeTo style: Font.TextStyle = .subheadline) -> Font {
        custom(inter, size: size, relativeTo: style, fallback: .default)
    }

    /// Didascalie e metadati (Inter).
    static func caption(_ size: CGFloat = 13, relativeTo style: Font.TextStyle = .caption) -> Font {
        custom(inter, size: size, relativeTo: style, fallback: .default)
    }
}

// MARK: - Card avorio

struct SobreCard: ViewModifier {
    var background: Color = .paper
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

extension View {
    /// Card avorio del design system (angoli 14pt).
    func sobreCard(_ background: Color = .paper) -> some View {
        modifier(SobreCard(background: background))
    }
}

// MARK: - Bottoni

/// CTA a pillola: fondo ottone, testo notte. Tap target ≥ 44pt.
struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.ui(15, relativeTo: .subheadline))
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .background(Capsule().fill(Color.brass))
            .foregroundStyle(Color.ink)
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Variante silenziosa: bordo ottone su fondo trasparente.
struct QuietPillButtonStyle: ButtonStyle {
    var tint: Color = .brassSoft
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.ui(15, relativeTo: .subheadline))
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .overlay(Capsule().strokeBorder(tint, lineWidth: 1))
            .foregroundStyle(tint)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Avatar con iniziali

struct AvatarView: View {
    let initials: String
    var size: CGFloat = 40

    var body: some View {
        SwiftUI.Circle()
            .fill(Color.felt)
            .overlay(
                Text(verbatim: initials)
                    .font(AppFont.ui(size * 0.38, relativeTo: .caption))
                    .foregroundStyle(Color.brassSoft)
            )
            .overlay(SwiftUI.Circle().strokeBorder(Color.brassSoft.opacity(0.4), lineWidth: 1))
            .frame(width: size, height: size)
            .accessibilityHidden(true) // decorativo: il nome è già nel testo accanto
    }
}

// MARK: - Badge del punteggio

/// Badge "63 · Presenza discreta", colorato per fascia.
/// Mai solo colore: il nome della fascia è sempre scritto.
struct ScoreBadge: View {
    let score: Int
    let band: ScoreBand

    private var bandColor: Color {
        switch band {
        case .voceViva:         return .successTone
        case .presenzaDiscreta: return .brass
        case .ombraAlTavolo:    return .errorTone
        }
    }

    private var bandLabel: String {
        switch band {
        case .voceViva:         return String(localized: "band.voceViva")
        case .presenzaDiscreta: return String(localized: "band.presenzaDiscreta")
        case .ombraAlTavolo:    return String(localized: "band.ombraAlTavolo")
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Text(verbatim: "\(score)")
                .font(AppFont.title(14, relativeTo: .caption))
            Text(verbatim: bandLabel)
                .font(AppFont.caption(11, relativeTo: .caption2))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(bandColor.opacity(0.16)))
        .overlay(Capsule().strokeBorder(bandColor.opacity(0.7), lineWidth: 1))
        .foregroundStyle(bandColor)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(format: String(localized: "a11y.score"), score, bandLabel)))
    }
}

// MARK: - Chip categoria

struct CategoryChip: View {
    let category: PostCategory
    var isSelected: Bool = false
    var onDark: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.symbolName)
                .font(.system(size: 11))
            Text(verbatim: category.labelKey.loc)
                .font(AppFont.caption(12, relativeTo: .caption2))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(isSelected ? Color.brass : .clear))
        .overlay(Capsule().strokeBorder(isSelected ? Color.brass : (onDark ? Color.brassSoft.opacity(0.6) : Color.felt.opacity(0.35)), lineWidth: 1))
        .foregroundStyle(isSelected ? Color.ink : (onDark ? Color.brassSoft : Color.felt))
    }
}

// MARK: - Toast (notifica in-app)

struct ToastView: View {
    let notice: AppNotice

    var body: some View {
        Text(verbatim: notice.message)
            .font(AppFont.ui(14, relativeTo: .footnote))
            .foregroundStyle(Color.paper)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.felt)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.brassSoft.opacity(0.6), lineWidth: 1))
            )
            .padding(.horizontal, 24)
            .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Titolo di sezione

struct SectionTitle: View {
    let textKey: LocalizedStringKey
    var body: some View {
        Text(textKey)
            .font(AppFont.title(20, relativeTo: .title3))
            .foregroundStyle(Color.paperDim)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
