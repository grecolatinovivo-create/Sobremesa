# Sobremesa — regole del progetto

App iOS **nativa SwiftUI** (iOS 17+). Niente wrapper WebView, niente dipendenze di terze parti.

## Dottrina di build (fabbrica-app)

- **Il codice è la sorgente di verità.** Il `.xcodeproj` NON è versionato: si genera da `native-ios/project.yml` con `xcodegen generate` (in CI avviene da solo). Ogni modifica al progetto passa da `project.yml`, mai dal pbxproj.
- **Build e rilascio vivono in CI.** Ogni push su `native-ios/**` fa scattare `check-ios-native.yml` (build + unit test su simulatore, senza firma). Il rilascio TestFlight è **solo manuale**: workflow `release-ios-native.yml` (`workflow_dispatch`); firma cloud all'export, nessun certificato locale.
- **Build number = `github.run_number`**, mai incrementato a mano. La versione commerciale (`MARKETING_VERSION` in `project.yml`) si alza a mano quando cambia la sostanza.
- **Niente segreti nel repo**, in nessuna forma (`AuthKey*`, `.env` sono in `.gitignore`). Firma e upload usano i GitHub Secrets: `ASC_API_KEY_P8`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `APPLE_TEAM_ID`.
- Se App Store Connect rifiuta l'upload (errore 90382): NON ricompilare — usare `retry-upload-ios-native.yml` col numero del run fallito.

## Regole di codice

- Tutti i numeri di business (12 sedie, 5 circoli, soglie brace 2/4/7, pesi punteggio, fasce) vivono SOLO in `Engine/ProductRules.swift`.
- La logica di prodotto sta in `SobremesaEngine` (puro, Foundation-only, testabile). Le view non mutano mai i modelli direttamente: passano da `AppStore` → `DataService`.
- Zero stringhe hardcoded nelle view: ogni testo è una chiave di `Resources/Localizable.xcstrings` (6 lingue: it sviluppo, en, es, fr, de, pt). I contenuti demo memorizzano chiavi (`isSeedContent`), risolte a runtime.
- Zero colori literal: solo i Color Set degli Assets, via `Components/Theme.swift`.
- Il modello dei circoli si chiama `Circolo` (mai `Circle`: collide con SwiftUI).
- Ogni nuova chiave di localizzazione va aggiunta in TUTTE e 6 le lingue (lo script di QA controlla la parità).

## Documentazione

`docs/`: README (prodotto), UX_SPEC, TECH_NOTES, L10N_NOTES, QA_REPORT, DECISIONI. Ogni scelta presa in autonomia va registrata in `docs/DECISIONI.md`.
