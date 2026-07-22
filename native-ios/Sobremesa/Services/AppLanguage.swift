//
//  AppLanguage.swift
//  Sobremesa
//
//  Il multilingua interno: di serie l'app segue il telefono, ma la lingua
//  si può scegliere da Tu → Lingua, senza passare dalle Impostazioni
//  di sistema e senza riavviare l'app.
//

import Foundation

/// Le lingue di Sobremesa. `system` = quella del dispositivo.
enum AppLanguage: String, CaseIterable {
    case system
    case it, en, es, fr, de, pt

    static let storageKey = "sobremesa.lingua"

    /// Le lingue scelte a mano, nell'ordine del selettore.
    static var choices: [AppLanguage] { allCases.filter { $0 != .system } }

    /// Lettura dalla preferenza salvata (con fallback sicuro al sistema).
    static var saved: AppLanguage {
        UserDefaults.standard.string(forKey: storageKey)
            .flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    /// Il nome della lingua *nella lingua stessa*: non si traduce mai —
    /// chi cerca la propria lingua deve poterla riconoscere a colpo d'occhio.
    var endonym: String {
        switch self {
        case .system: ""
        case .it: "Italiano"
        case .en: "English"
        case .es: "Español"
        case .fr: "Français"
        case .de: "Deutsch"
        case .pt: "Português"
        }
    }

    /// Il Locale per l'ambiente SwiftUI (le `Text` si localizzano da qui).
    var locale: Locale {
        self == .system ? .autoupdatingCurrent : Locale(identifier: rawValue)
    }

    /// Il bundle .lproj corrispondente, per le stringhe fuori da SwiftUI
    /// (toast, notifiche locali, messaggi di condivisione).
    var bundle: Bundle {
        guard self != .system,
              let path = Bundle.main.path(forResource: rawValue, ofType: "lproj"),
              let override = Bundle(path: path) else { return .main }
        return override
    }
}

/// Punto unico per le stringhe programmatiche: `String(localized:bundle:)`
/// legge da qui, così i toast e le notifiche parlano la lingua scelta.
enum L10n {
    nonisolated(unsafe) static var bundle: Bundle = .main
}
