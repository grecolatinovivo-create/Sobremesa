# TECH_NOTES — Sobremesa

## Stack e motivazione

- **SwiftUI puro, iOS 17+** — richiesto dal brief; iOS 17 abilita `@Observable`, SwiftData e le `#Predicate` tipizzate.
- **SwiftData** per la persistenza locale: modelli dichiarativi, query reattive (`@Query`) che tengono la UI sempre aggiornata senza plumbing.
- **Swift Concurrency** (async/await, `Task`) — usata per i toast a scomparsa; niente Combine.
- **Nessuna dipendenza di terze parti.** I tre font sono bundlati come risorse (licenza OFL).
- **Dottrina fabbrica-app**: il `.xcodeproj` **non è versionato** — la sorgente di verità del progetto è `native-ios/project.yml` (XcodeGen); il progetto si rigenera con `xcodegen generate`, in CI avviene da solo. Build e rilascio vivono in GitHub Actions: check a ogni push, release TestFlight manuale con firma cloud, retry senza ricompilare.

## Architettura

```
Views (SwiftUI, MVVM con @Observable)
  │  leggono con @Query (reattività SwiftData)
  │  mutano SOLO tramite AppStore
  ▼
AppStore (@Observable, @MainActor)          ← stato UI: toast, invito in sospeso
  ▼
DataService (protocollo) ◄── LocalDataService (SwiftData)   ← "backend" simulato
  ▼
SobremesaEngine + ProductRules (puri, Foundation-only)       ← TUTTE le regole
```

- **`ProductRules`**: l'unica fonte dei numeri di business (12, 5, 2/4/7, +2/+1/+1/−2/−5, 0–100, 75/45). Iniettabile nei test.
- **`SobremesaEngine`**: funzioni pure e deterministiche — capienza tavola e circoli, stato della brace, valutazione penalità/espulsione, aritmetica del punteggio con clamp, fasce. Zero import di UI o persistenza: per questo è testabile ovunque (i test girano perfino su Linux, v. QA_REPORT).
- **`LocalDataService`** (conforme a `DataService`): seed demo, CRUD, valutazione della brace ad avvio/foreground, auto-seduta con invito in sospeso. Sostituibile in futuro con un client di rete senza toccare view né engine.
- **`AppStore`**: facade osservabile per le view; possiede i toast e lo stato dell'invito in sospeso.

## Il tempo è reale

Il silenzio si calcola dalla data dell'ultima attività (`Membership.lastActivity`), rivalutato a ogni avvio e a ogni ritorno in foreground (`scenePhase`). Il pulsante DEBUG "Simula 3 giorni di silenzio" **sposta indietro le date reali** di 3 giorni e rivaluta: la meccanica esercitata è identica alla produzione, non un percorso parallelo.

La penalità −2 scatta una sola volta per periodo di silenzio per circolo (flag `silencePenaltyApplied`, azzerato da ogni attività). A ≥7 giorni: espulsione automatica, −5, slot liberato, toast esplicativo.

## Localizzazione dei dati demo

I contenuti seed (post, commenti, nomi/temi dei circoli, bio, interessi) memorizzano **chiavi** del String Catalog (`isSeedContent = true`) risolte a runtime: cambiando la lingua del dispositivo anche i dati demo cambiano lingua. I contenuti creati dall'utente restano testo puro. I nomi propri delle persone non si traducono.

## Font

`Fonts/` contiene Young Serif (regular), Source Serif 4 e Inter (variabili, istanza di default), registrati via `UIAppFonts` in `Config/Info.plist`. `AppFont` verifica a runtime la reale disponibilità della famiglia (`UIFont.familyNames`) e in caso di problemi ripiega dichiaratamente su `.serif` / `.default` di sistema, sempre con Dynamic Type (`relativeTo:`).

`Config/Info.plist` vive fuori dalle cartelle sorgente ed è agganciato con `INFOPLIST_FILE` (+ `GENERATE_INFOPLIST_FILE = YES`, le chiavi si fondono): così non viene copiato due volte nel bundle. Contiene `UIAppFonts`, il launch screen e `ITSAppUsesNonExemptEncryption`.

## Build e rilascio (dottrina fabbrica-app)

**Non si compila in locale per rilasciare.** I tre workflow in `.github/workflows/`:

1. **`check-ios-native.yml`** — a ogni push su `native-ios/**`: XcodeGen genera il progetto, build su simulatore senza firma, poi i 12 unit test dell'engine. `concurrency: cancel-in-progress` (si paga solo l'ultimo push) e `timeout-minutes` su ogni job.
2. **`release-ios-native.yml`** — **solo manuale** (`workflow_dispatch`): archive senza firma, archivio salvato come artifact PRIMA dell'upload (paracadute), firma cloud all'export con la chiave API di App Store Connect, upload diretto su TestFlight. Build number = `github.run_number`.
3. **`retry-upload-ios-native.yml`** — se lo store rifiuta (es. errore 90382, limite giornaliero): scarica l'artifact `xcarchive-<numero>` del run fallito e rifà solo firma + upload, senza ricompilare.

Secrets richiesti (GitHub → Settings → Secrets and variables → Actions): `ASC_API_KEY_P8`, `ASC_KEY_ID`, `ASC_ISSUER_ID` (chiave API di App Store Connect), `APPLE_TEAM_ID` (Apple Developer → Membership).

**Sviluppo locale (facoltativo):** `brew install xcodegen`, poi `cd native-ios && xcodegen generate` e aprire il `Sobremesa.xcodeproj` generato (che resta fuori dal repo). Simulatore: ⌘R; test: ⌘U. Le 6 lingue: Scheme → Run → Options → App Language. La brace: tab **Circoli** → "Simula 3 giorni di silenzio" (solo DEBUG): prima pressione avvisi e penalità, seconda espulsione.

**Versioning:** `MARKETING_VERSION` si alza a mano in `project.yml` quando cambia la sostanza; il build number cresce da solo col numero di run e non si tocca mai.

## Scelte degne di nota

- Il modello dei circoli si chiama `Circolo` (evita la collisione con `SwiftUI.Circle`) — DECISIONI.md #1.
- I membri "di sfondo" dei circoli sono un contatore (`memberCount`); le `Membership` reali esistono per l'utente e per chi viene accolto — DECISIONI.md #7.
- Il toggle "Nutre" è un flag sul post (`nutritoDaMe`) sommato al contatore seed: impossibile il doppio conteggio per costruzione.
- `ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS = NO` + accesso ai colori per nome centralizzato in `Theme.swift`: un solo punto di verità, zero rischio di collisioni di simboli generati.
- Chi si alza dalla tavola torna tra i candidati invitabili (nessun "buco nero" di persone).
