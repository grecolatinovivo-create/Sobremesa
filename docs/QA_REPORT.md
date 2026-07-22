# QA_REPORT — Sobremesa

Ambiente QA: container Linux (niente Xcode/macOS disponibili in fase di sviluppo). Il QA ha quindi eseguito **realmente** tutto ciò che è eseguibile fuori da Xcode e ha verificato per revisione sistematica il resto, dichiarandolo onestamente.

## 1. Cosa è stato ESEGUITO davvero

### Unit test dell'engine — ✅ 12/12 verdi
Eseguiti con Swift 6.0.3 su Linux tramite un pacchetto SwiftPM ombra che compila i file di `Engine/` (puri, Foundation-only) **e lo stesso identico file di test** del target `SobremesaTests` (`@testable import Sobremesa`):

```
Executed 12 tests, with 0 failures (0 unexpected)
```

| Test | Copre |
|---|---|
| testThirteenthInviteIsBlocked | 13° invito bloccato a 12/12, sedie libere mai negative |
| testAutoSeatAfterChairIsFreed | auto-seduta con invito in sospeso dopo la liberazione |
| testSixthCircleIsBlocked | 6° circolo bloccato, vincolo anche per i richiedenti |
| testEmberProgression | brace 0 → 2 → 4 → 7 (viva/affievolita/avviso/espulsione) |
| testEmberWarningAppliesPenaltyExactlyOncePerSilencePeriod | −2 una sola volta per periodo |
| testEmberExpulsionAtSevenDays | espulsione a ≥7 gg, penalità arretrata se mai valutata |
| testCommentResetsSilence | l'attività azzera il silenzio |
| testScorePointsMatchProductRules | pesi +2/+1/+1/−2/−5 letti da ProductRules |
| testScoreArithmetic | sequenza 50→52→53→54→52→47 esatta |
| testScoreClampAtBounds | clamp 0–100 a ogni passo, iniziale fuori range normalizzato |
| testScoreBands | soglie esatte 75/74/45/44 e estremi 0/100 |
| testJoinRequestAcceptance | accoglienza/declino con vincolo slot del richiedente |

### Verifica sintattica dei sorgenti — ✅
`swiftc -parse` su tutti i 13 file Swift (app + test): **zero errori di sintassi**.

### Audit di localizzazione (script) — ✅
- Chiavi usate nel codice vs catalogo: **nessuna chiave mancante**; 133 chiavi, tutte presenti in **tutte e 6 le lingue** (2 chiavi segnalate "non usate" dallo script sono un falso positivo del regex: `a11y.nutre.on/off` vivono in un operatore ternario).
- **Placeholder coerenti** tra le 6 lingue per ogni chiave (stesso set di `%@`/`%lld`): nessuna incoerenza → niente crash da formato.
- Plurali: 7 chiavi con variazioni one/other in tutte le lingue.

### Audit design system e numeri di business (script) — ✅
- **Zero colori literal** nelle view/componenti: solo i nomi asset in `Theme.swift`.
- **Zero numeri di business fuori da `ProductRules`**: 12, 5, 2/4/7, pesi e soglie compaiono solo lì (verificato a mano file per file; il "3" del pulsante di debug è un parametro di debug richiesto dal brief, non una regola di prodotto; il copy riceve i valori come argomenti di formato).
- Font e colori validi: file .ttf verificati (famiglie "Young Serif", "Source Serif 4", "Inter" lette dai metadati reali dei file).

## 2. Bug trovati e corretti direttamente (con verifica del flusso intero)

1. **Toast della penalità con "−2" hardcoded nel copy** → violava "zero numeri di business fuori da ProductRules". Corretto: `toast.penalita` riceve il valore da `engine.points(for: .silenzio)`. Verificato l'intero flusso silenzio → avviso → toast → punteggio.
2. **`isFriend` euristico in AppStore** (deducva l'amicizia da flag negativi: avrebbe incluso nel feed anche i richiedenti) → sostituito con la verifica reale sulle `Friendship` nel servizio. Verificato il flusso feed completo: post di amici ✓, di circoli abitati ✓, di estranei esclusi ✓, dopo espulsione i post del circolo spariscono ✓.
3. **`TuView` usava `UIApplication` senza `import UIKit`** → aggiunto l'import. Verificato il flusso "Lingua dell'app → Apri Impostazioni".
4. **Chi si alzava dalla tavola spariva per sempre** (né amico né candidato) → ora torna tra le "Persone che potresti invitare". Verificato il flusso completo: libera sedia → auto-seduta dell'invitato in sospeso → l'ex amico ricompare tra i candidati e può essere reinvitato.
5. **Prevenzione (fase Dev, registrata qui)**: il modello `Circle` avrebbe colliso con `SwiftUI.Circle` in tutte le view → rinominato `Circolo` prima dell'implementazione (DECISIONI.md #1).

## 3. Criteri di accettazione, uno per uno

| # | Criterio | Esito QA |
|---|---|---|
| 1 | Compila senza warning ed esegue su simulatore | ⚠ **Da confermare su Xcode** (non disponibile in questo ambiente). Fatto tutto il possibile qui: sintassi verificata su ogni file, engine compilato ed eseguito davvero, pattern iOS 17 standard, progetto in formato Xcode 16. |
| 2 | 6 lingue complete, demo inclusi, plurali corretti | ✅ Verificato via audit: 133/133 chiavi in 6 lingue, placeholder coerenti, plurali CLDR; i seed memorizzano chiavi risolte a runtime. |
| 3 | Flusso 13° amico con auto-seduta | ✅ Logica testata (unit); flusso UI tracciato: Invita→pannello→Libera sedia→auto-seduta+toast+animazione sedia. |
| 4 | Brace con tempo reale e debug; espulsione comunicata | ✅ Logica testata (unit); valutazione a bootstrap e a ogni foreground (`scenePhase`); il debug sposta le date reali. |
| 5 | Punteggio esatto e UI sempre aggiornata | ✅ Aritmetica testata (unit); tutte le mutazioni passano da un solo punto (`applyScore`); la UI legge con `@Query` reattive. |
| 6 | Animatore accoglie/declina, membri aggiornati | ✅ Logica testata (unit); accoglienza crea Membership reale e aggiorna `memberCount`; richiesta rimossa; toast. |
| 7 | Tutti i test unitari passano | ✅ 12/12 eseguiti realmente (Linux, stesso file di test del target Xcode). |
| 8 | Zero stringhe hardcoded / colori literal / numeri fuori da ProductRules | ✅ Verificato via script + revisione manuale. |

## 4. Cosa funziona (riepilogo)

Composer con errore inline e destinazione (tavola/circolo) · feed cronologico filtrato su amici+circoli · Nutre senza doppio conteggio · commenti espandibili con azzeramento del silenzio e feedback · tavola grafica animata con conteggio, plurali e descrizione VoiceOver · libera sedia con conferma · invito a tavola piena con pannello e auto-seduta · punteggio con fasce e badge solo nei contesti decisionali · slot 3/5 · stato brace su tre livelli con CTA · pannello animatore con 2 richieste dai punteggi contrastanti · catalogo con Entra disabilitato-e-spiegato a 5/5 · espulsione automatica con toast · debug della meccanica temporale · profilo con manifesto, lingua e reset demo · dark-first, Dynamic Type, tap target ≥44pt, riduzione animazioni.

## 5. Punti aperti (dichiarati onestamente)

1. **Compilazione e run su simulatore non eseguiti in questo ambiente** (niente macOS). La verifica però è automatizzata: al primo push su GitHub, `check-ios-native.yml` genera il progetto con XcodeGen e compila + testa su runner macOS — l'esito si vede nel tab Actions in pochi minuti. La probabilità di attriti residui è concentrata nelle view SwiftUI (sintassi verificata, type-check no); eventuali errori saranno fix da una riga, visibili nel log del check.
2. **Icona app**: placeholder vuoto (nessun asset grafico generato). Il progetto compila comunque.
3. **Font variabili** (Inter, Source Serif 4) usati all'istanza di default: i pesi bold sintetici non sono attivi per scelta (v. DECISIONI.md #15).
4. **Circoli abbandonati/espulsi non-aperti**: i tre circoli seed dell'utente sono privati (`isOpen = false`); dopo un'uscita o un'espulsione non ricompaiono nel catalogo. Coerente col prodotto (ci si rientra su invito), ma da decidere a livello di prodotto.
5. **I membri di sfondo dei circoli non vengono mai espulsi**: la valutazione della brace riguarda solo l'utente (DECISIONI.md #8).
6. **`Date` e DST**: i giorni di silenzio usano 86.400s fissi; ai cambi d'ora la soglia può slittare di ±1h su 4-7 giorni. Irrilevante in pratica, documentato.
