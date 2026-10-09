//
//  Theme.swift
//  Sobremesa
//
//  Design system "ULTIMA LUCE" (v3, brainstorming Claude × Astra):
//  il pasto è finito, le luci sono basse, sul tavolo resta un punto di
//  calore e le persone continuano a parlare.
//
//  Regole del sistema:
//  - il fondo È l'interfaccia: le card sono eccezioni, non contenitori;
//  - l'OTTONE indica ciò che posso fare, la BRACE ciò che vive il tavolo:
//    non si confondono mai;
//  - gerarchia affidata a spazio, tipografia e pochi accenti.
//  UNICO punto del codice che nomina colori (per nome asset) e font.
//

import SwiftUI
import UIKit

// MARK: - Colori (dagli Asset, mai literal)

extension Color {
    // Superfici
    static let background    = Color("Background")    // #101C19 verde quasi nero
    static let surface       = Color("Surface")       // #1C2B25 verde feltro
    static let elevated      = Color("Elevated")      // #293B32 superfici secondarie
    // Testi
    static let textPrimary   = Color("TextPrimary")   // #F5EFE3 avorio caldo (15,3:1)
    static let textSecondary = Color("TextSecondary") // #CDD2C4 (11,3:1)
    static let textMuted     = Color("TextMuted")     // #A6B2A5 (7,9:1)
    // Linee
    static let divider       = Color("Divider")       // #405349 decorativo
    static let outline       = Color("Outline")       // #708574 contorni funzionali (≥3:1)
    // Azione
    static let brass         = Color("Brass")         // #E7BC6C azione primaria
    static let brassInk      = Color("BrassInk")      // #2B210F testo sull'ottone (8,9:1)
    // Brace (vita del tavolo — MAI usata per le azioni)
    static let emberAlive    = Color("EmberAlive")    // #FFAF68
    static let emberFading   = Color("EmberFading")   // #DFA27D
    static let emberWaiting  = Color("EmberWaiting")  // #ADB9AC
    // Avvisi personali (con tatto: mai rosso pieno)
    static let warning       = Color("Warning")       // #F0A69A
}

// MARK: - Spaziature (scala unica)

enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    /// Margine laterale delle schermate.
    static let gutter: CGFloat = 20
}

// MARK: - Tipografia (ruoli distinti, con fallback dichiarato)

/// Young Serif: titoli e numeri identitari (mai i messaggi).
/// Source Serif 4: la lettura — messaggi e testi narrativi.
/// Inter: interfaccia, metadati, etichette.
/// Tutto è Dynamic Type (relativeTo:); fallback dichiarato sui font di sistema.
enum AppFont {

    private static let youngSerif = "Young Serif"
    private static let sourceSerif = "Source Serif 4"
    private static let inter = "Inter"

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
        return .system(style, design: design)
    }

    /// Titolo di schermata (32).
    static func display(_ size: CGFloat = 32, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        custom(youngSerif, size: size, relativeTo: style, fallback: .serif)
    }

    /// Titoli di tavolo e di sezione (27 / 20).
    static func title(_ size: CGFloat = 27, relativeTo style: Font.TextStyle = .title2) -> Font {
        custom(youngSerif, size: size, relativeTo: style, fallback: .serif)
    }

    /// Lettura: messaggi (18) e testi narrativi (17).
    static func bodySerif(_ size: CGFloat = 17, relativeTo style: Font.TextStyle = .body) -> Font {
        custom(sourceSerif, size: size, relativeTo: style, fallback: .serif)
    }

    /// Interfaccia e pulsanti (15).
    static func ui(_ size: CGFloat = 15, relativeTo style: Font.TextStyle = .subheadline) -> Font {
        custom(inter, size: size, relativeTo: style, fallback: .default)
    }

    /// Metadati (13).
    static func caption(_ size: CGFloat = 13, relativeTo style: Font.TextStyle = .caption) -> Font {
        custom(inter, size: size, relativeTo: style, fallback: .default)
    }

    /// Microetichette maiuscole spaziate (12), es. "DA DECIDERE".
    static func label(_ size: CGFloat = 12, relativeTo style: Font.TextStyle = .caption2) -> Font {
        custom(inter, size: size, relativeTo: style, fallback: .default)
    }
}

// MARK: - Pannello (l'eccezione, non la regola)

/// Superficie per i pochi elementi che lo meritano (composer, codice d'invito,
/// richieste da decidere). Raggio 12, nessuna ombra.
struct Panel: ViewModifier {
    var fill: Color = .surface
    var padding: CGFloat = Space.l
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

extension View {
    func panel(_ fill: Color = .surface, padding: CGFloat = Space.l) -> some View {
        modifier(Panel(fill: fill, padding: padding))
    }

    /// Sfondo standard di ogni schermata.
    func screenBackground() -> some View {
        background(Color.background.ignoresSafeArea())
    }
}

// MARK: - Bottoni

/// Azione primaria: pillola ottone, altezza 48.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var fullWidth = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.ui(16, relativeTo: .body).weight(.semibold))
            .padding(.horizontal, 22)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 48)
            .background(Capsule().fill(Color.brass))
            .foregroundStyle(Color.brassInk)
            .opacity(configuration.isPressed ? 0.8 : (isEnabled ? 1 : 0.4))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Azione secondaria: contorno, su fondo trasparente. Altezza 44.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var tint: Color = .textSecondary
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.ui(15, relativeTo: .subheadline).weight(.medium))
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .overlay(Capsule().strokeBorder(Color.outline, lineWidth: 1))
            .foregroundStyle(tint)
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.6 : (isEnabled ? 1 : 0.4))
    }
}

/// Azione testuale (link d'interfaccia): ottone, nessun contenitore.
struct TextActionStyle: ButtonStyle {
    var tint: Color = .brass
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.ui(15, relativeTo: .subheadline).weight(.semibold))
            .foregroundStyle(tint)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Avatar con iniziali

struct AvatarView: View {
    let initials: String
    var size: CGFloat = 32
    var highlighted = false

    var body: some View {
        SwiftUI.Circle()
            .fill(Color.elevated)
            .overlay(
                Text(verbatim: initials)
                    .font(AppFont.ui(size * 0.38, relativeTo: .caption).weight(.medium))
                    .foregroundStyle(Color.textSecondary)
            )
            .overlay(SwiftUI.Circle().strokeBorder(highlighted ? Color.brass : Color.divider, lineWidth: 1))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - Fascia di presenza (parola, mai classifica)

struct BandLabel: View {
    let band: ScoreBand

    var body: some View {
        Text(verbatim: band.localizedName)
            .font(AppFont.caption(12, relativeTo: .caption2))
            .foregroundStyle(Color.textMuted)
    }
}

extension ScoreBand {
    var localizedName: String {
        switch self {
        case .voceViva:         return String(localized: "band.voceViva", bundle: L10n.bundle)
        case .presenzaDiscreta: return String(localized: "band.presenzaDiscreta", bundle: L10n.bundle)
        case .ombraAlTavolo:    return String(localized: "band.ombraAlTavolo", bundle: L10n.bundle)
        }
    }
}

// MARK: - Chip categoria

struct CategoryChip: View {
    let category: PostCategory
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: category.symbolName)
                .imageScale(.small)
            Text(verbatim: category.labelKey.loc)
                .font(AppFont.caption(13, relativeTo: .footnote).weight(.medium))
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 36)
        .background(Capsule().fill(isSelected ? Color.brass : Color.clear))
        .overlay(Capsule().strokeBorder(isSelected ? Color.brass : Color.outline, lineWidth: 1))
        .foregroundStyle(isSelected ? Color.brassInk : Color.textSecondary)
    }
}

// MARK: - Toast (notifica in-app)

struct ToastView: View {
    let notice: AppNotice
    var onDismiss: () -> Void = {}

    var body: some View {
        HStack(alignment: .center, spacing: Space.s) {
            Text(verbatim: notice.message)
                .font(AppFont.ui(14, relativeTo: .footnote))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.textMuted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("a11y.toast.chiudi"))
        }
        .padding(.leading, Space.l)
        .padding(.trailing, Space.xs)
        .padding(.vertical, Space.xs)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.elevated)
                .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
        )
        .padding(.horizontal, Space.gutter)
    }
}

// MARK: - Etichetta di sezione (maiuscoletto spaziato)

struct SectionLabel: View {
    let textKey: LocalizedStringKey
    var body: some View {
        Text(textKey)
            .font(AppFont.label().weight(.semibold))
            .textCase(.uppercase)
            .kerning(1.2)
            .foregroundStyle(Color.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Filetto sottile decorativo.
struct Hairline: View {
    var inset: CGFloat = 0
    var body: some View {
        Rectangle()
            .fill(Color.divider)
            .frame(height: 0.5)
            .padding(.leading, inset)
            .accessibilityHidden(true)
    }
}

/// Titolo di schermata (Young Serif 32) con sottotitolo opzionale.
struct ScreenTitle: View {
    let titleKey: LocalizedStringKey
    var subtitleKey: LocalizedStringKey? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(titleKey)
                .font(AppFont.display())
                .foregroundStyle(Color.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if let subtitleKey {
                Text(subtitleKey)
                    .font(AppFont.bodySerif(16, relativeTo: .callout))
                    .italic()
                    .foregroundStyle(Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
