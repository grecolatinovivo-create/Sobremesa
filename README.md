# Sobremesa

*Il social della cultura dove la scarsità è la feature.*

App iOS **nativa SwiftUI** (iOS 17+, SwiftData, zero dipendenze). Dodici sedie a tavola, cinque circoli da abitare, una brace da tenere viva: niente follower infiniti, niente algoritmo, niente vanity metrics. La reazione non è un like: è un **Nutre**.

## Le meccaniche

- **La Tavola** — massimo 12 amici reciproci. Per invitare il 13°, qualcuno deve alzarsi: e quando una sedia si libera, l'invitato in sospeso si siede da solo.
- **I Circoli** — massimo 5 circoli tematici abitati contemporaneamente. Un circolo non si segue: si abita.
- **La regola della brace** — 4 giorni di silenzio in un circolo: avviso. 7 giorni: il posto si libera automaticamente. Commentare azzera il silenzio.
- **Punteggio di partecipazione** (0–100) — +2 pubblicazione, +1 commento, +1 riprendi la parola, −2 silenzio, −5 espulsione. Mai una classifica: solo uno strumento decisionale per l'animatore.

## Com'è fatto il repo

Il progetto segue la dottrina della fabbrica: **il codice è la sorgente di verità, il `.xcodeproj` non esiste nel repo** (si genera da `native-ios/project.yml` con XcodeGen), **build e rilascio vivono in CI**.

```
native-ios/            project.yml + Sources (Models, Engine, Services, Views,
                       Components, Resources) + SobremesaTests + Config
.github/workflows/     check-ios-native (a ogni push: build + 12 unit test)
                       release-ios-native (manuale: firma cloud → TestFlight)
                       retry-upload-ios-native (ricarica senza ricompilare)
docs/                  README prodotto · UX_SPEC · TECH_NOTES · L10N_NOTES
                       QA_REPORT · DECISIONI
CLAUDE.md              regole del progetto per gli agenti
```

Localizzato in **6 lingue** (it · en · es · fr · de · pt) con String Catalog, dati demo inclusi. Design system "sala lettura di una biblioteca la sera": dark-first, Young Serif / Source Serif 4 / Inter, ottone su verde notte.

## Build e rilascio

Non serve compilare in locale: **ogni push compila e testa in CI** (runner macOS). Per TestFlight: tab *Actions* → *Release iOS nativa (TestFlight)* → *Run workflow*. La firma avviene in cloud con la chiave API di App Store Connect (secrets: `ASC_API_KEY_P8`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `APPLE_TEAM_ID`). Il build number è il numero del run.

Per lavorare in locale (facoltativo): `brew install xcodegen`, poi `cd native-ios && xcodegen generate` e aprire il progetto generato.

---

Font [Young Serif](https://github.com/noirblancrouge/YoungSerif), [Source Serif 4](https://github.com/adobe-fonts/source-serif) e [Inter](https://github.com/rsms/inter) — SIL Open Font License.
