# Sobremesa

*Il social della cultura dove la scarsità è la feature.*

**Sobremesa** (dallo spagnolo: il tempo passato a tavola a conversare, dopo il pasto) è un'app iOS nativa in SwiftUI che inverte il modello dei social generalisti: non quantità infinita, ma presenza scelta e coltivata.

---

## 1. Analisi del brief

I social generalisti ottimizzano metriche di quantità: follower illimitati, gruppi illimitati, scroll passivo, algoritmi che massimizzano il tempo di permanenza. Sobremesa fa il contrario e trasforma tre vincoli in identità di prodotto:

1. **La Tavola** — massimo **12 amici** (le sedie di una tavola). Solo amicizia reciproca, nessun follow asimmetrico. Per invitare il 13°, qualcuno deve alzarsi.
2. **I Circoli** — massimo **5 circoli** tematici abitati contemporaneamente. Un circolo non si segue: si abita.
3. **La regola della brace** — la partecipazione nei circoli va tenuta viva: dopo **4 giorni** di silenzio scatta l'avviso, a **7 giorni** il posto si libera automaticamente. Commentare (o pubblicare, o "riprendere la parola") in un circolo azzera il silenzio.

A questi si aggiunge il **punteggio di partecipazione** (0–100, globale per persona), che serve come strumento decisionale (mai come classifica pubblica), e la reazione **"Nutre"** al posto del like.

## 2. Obiettivo principale

Consegnare un'app iOS 17+ completa, compilabile ed eseguibile su simulatore, che dimostri end-to-end tutte le meccaniche di prodotto (tavola, circoli, brace, punteggio, richieste d'ingresso) con dati demo credibili, persistenza locale SwiftData, localizzazione completa in 6 lingue e una identità visiva forte ("la sala lettura di una biblioteca la sera").

## 3. Utenti target

- **Lettori e spettatori "forti"**: persone che leggono, vanno al cinema/teatro, ascoltano musica con intenzione e vogliono parlarne con poche persone scelte, non con un pubblico.
- **Stanchi dei social**: utenti in fuga da feed algoritmici e vanity metrics, attratti da spazi piccoli e a bassa pressione.
- **Animatori culturali**: chi anima un circolo (book club, cineforum) e ha bisogno di strumenti leggeri per decidere chi accogliere.

## 4. Requisiti funzionali

1. **Salotto (feed)** — composer con categoria a chip e validazione inline; feed cronologico dei soli amici e circoli abitati; "Nutre" toggle senza doppio conteggio; commenti espandibili con form inline; commentare in un circolo azzera il silenzio con feedback visivo; stato vuoto con copy dedicato.
2. **Tavola** — visualizzazione grafica della tavola rotonda con 12 sedie (occupate in ottone con iniziali, libere tratteggiate, conteggio al centro, animazione discreta); lista amici con "Libera sedia" (con conferma); lista candidati con "Invita"; flusso "tavola piena → libera una sedia → auto-seduta dell'invitato in sospeso".
3. **Circoli** — punteggio personale con fascia e colore; contatore slot N/5 sempre visibile; card circoli abitati con stato della brace (viva / si affievolisce / avviso rosso con "Riprendi la parola") e azione Esci; pannello animatore con richieste d'ingresso (Accogli/Declina con badge punteggio); catalogo con Entra (disabilitato ma visibile a 5/5); espulsione automatica a 7 giorni con notifica in-app; pulsante DEBUG "Simula 3 giorni di silenzio".
4. **Tu (profilo)** — nome, bio, badge punteggio, manifesto, lingua dell'app, azzeramento dati demo.
5. **Punteggio di partecipazione** — +2 pubblicazione, +1 commento, +1 riprendi la parola, −2 per periodo di silenzio per circolo silente, −5 espulsione; clamp 0–100; fasce Voce viva (≥75, verde), Presenza discreta (≥45, ottone), Ombra al tavolo (<45, rosso); visibile solo in contesti decisionali e nel proprio profilo.
6. **Localizzazione** — String Catalog in it/en/es/fr/de/pt, zero stringhe hardcoded, plurali corretti, dati demo localizzati, glossario editoriale dei termini di prodotto.

## 5. Vincoli

- SwiftUI puro, iOS 17+, MVVM con `@Observable`, Swift Concurrency, nessuna dipendenza di terze parti.
- Persistenza SwiftData; tempo reale (il silenzio si calcola dalle date effettive, rivalutato a ogni avvio e ritorno in foreground).
- Tutti i numeri di prodotto (12, 5, soglie 2/4/7, pesi, soglie fasce) vivono **solo** in `ProductRules`.
- Logica di business in un layer puro e testabile (`SobremesaEngine`), dietro protocolli; backend simulato da `LocalDataService` conforme a `DataService`.
- Dark-first, font custom con fallback dichiarato, Dynamic Type, VoiceOver, contrasti AA, tap target ≥44pt, riduzione animazioni rispettata.

## 6. Rischi e mitigazioni

| Rischio | Mitigazione |
|---|---|
| Meccanica temporale difficile da testare manualmente | Pulsante DEBUG "Simula 3 giorni di silenzio" che sposta indietro le date reali; unit test sull'engine con date sintetiche |
| Doppio conteggio del punteggio da percorsi diversi | Tutte le mutazioni passano da un solo punto (`AppStore` → engine); flag `penaltyApplied` per periodo di silenzio |
| Stringhe hardcoded che sfuggono | QA con script di verifica: ogni chiave usata nel codice deve esistere nel catalogo in tutte e 6 le lingue |
| Nome del modello `Circle` in conflitto con `SwiftUI.Circle` | Il modello si chiama `Circolo` (decisione documentata in DECISIONI.md) |
| Bundling font fallisce | `AppFont` verifica la disponibilità a runtime e ripiega su `.serif` / `.default` di sistema |
| "Sobremesa" = "dessert" in portoghese | Copy PT rivisto per evitare ambiguità; il brand resta Sobremesa (v. L10N_NOTES.md) |

## 7. Roadmap (fasi del team)

1. **PM** → questo documento, struttura del progetto, DECISIONI.md.
2. **UX** → `docs/UX_SPEC.md`: IA, wireframe testuali, flussi, design system.
3. **iOS Developer** → progetto Xcode completo + `docs/TECH_NOTES.md`.
4. **Localization Engineer** → `Localizable.xcstrings` in 6 lingue + `docs/L10N_NOTES.md`.
5. **QA** → test end-to-end, correzioni, `docs/QA_REPORT.md`.

## 8. Struttura del progetto

```
Sobremesa/                          ← cartella radice del repo (dottrina fabbrica-app:
│                                      nessun .xcodeproj versionato, si genera con XcodeGen)
├── native-ios/
│   ├── project.yml                 ← sorgente di verità del progetto Xcode (XcodeGen)
│   ├── Config/
│   │   └── Info.plist              ← UIAppFonts, launch screen, ITSAppUsesNonExemptEncryption
│   ├── Sobremesa/                  ← sorgenti dell'app
│   │   ├── App/                    ← SobremesaApp, RootTabView
│   │   ├── Models/                 ← @Model SwiftData (Person, Friendship, Circolo, Membership,
│   │   │                              Post, Comment, JoinRequest, ParticipationEvent)
│   │   ├── Engine/                 ← ProductRules + SobremesaEngine (puri, testabili, zero UI)
│   │   ├── Services/               ← DataService (protocollo), LocalDataService, AppStore
│   │   ├── Views/                  ← una vista per tab (Salotto, Tavola, Circoli, Tu)
│   │   ├── Components/             ← Theme, ScoreBadge, chip, card, toast…
│   │   └── Resources/
│   │       ├── Localizable.xcstrings  ← String Catalog, 6 lingue
│   │       ├── Assets.xcassets        ← Color Set (Ink, Felt, Paper, Brass…), AppIcon
│   │       └── Fonts/                 ← Young Serif, Source Serif 4, Inter (OFL)
│   └── SobremesaTests/             ← unit test XCTest sull'engine
├── .github/workflows/              ← check (push) · release TestFlight (manuale) · retry upload
├── CLAUDE.md                       ← regole del progetto per gli agenti
└── docs/                           ← README, UX_SPEC, TECH_NOTES, L10N_NOTES, QA_REPORT, DECISIONI
```

## 9. Criteri di accettazione

Sono quelli del brief, verificati uno per uno dal QA in `docs/QA_REPORT.md`: compilazione senza warning; UI interamente tradotta nelle 6 lingue con plurali corretti; flusso "13° amico" con auto-seduta; regola della brace con tempo reale e simulatore di debug; aritmetica esatta del punteggio con UI sempre aggiornata; gestione richieste dell'animatore; test unitari verdi; zero stringhe hardcoded, zero colori literal, zero numeri di business fuori da `ProductRules`.
