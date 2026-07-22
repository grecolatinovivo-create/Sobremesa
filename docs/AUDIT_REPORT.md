# AUDIT_REPORT — Sobremesa

Audit completo pre-push, eseguito da **quattro auditor in parallelo** sul codice reale, ognuno con la lente di una skill del team: **UX**, **QA**, **Auditor (conformità)**, **Neuromarketing**. In coda: gli interventi applicati subito e ciò che resta aperto, onestamente.

Domanda d'innesco dell'utente: *"come entro in una conversazione di un tavolo?"* — Risposta pre-audit: **non si entrava**. La conversazione esisteva solo mescolata nel feed; un circolo era una card di gestione senza un "dove". Era il finding n.1 dell'audit UX ed è stato corretto (v. Interventi, A).

---

## 1. Audit UX (lente: agent-ux)

| # | Gravità | Finding | Esito |
|---|---|---|---|
| 1 | CRITICO | **Manca la "stanza" del circolo**: nessuna navigazione, i post del circolo vivono solo mescolati nel Salotto. La tesi "un circolo si abita" è smentita dall'app. | ✅ Corretto (A) |
| 2 | CRITICO | **Da zero la Tavola è un vicolo cieco**: nessun candidato potrà mai esistere senza backend; Invita/auto-seduta sono irraggiungibili per un utente reale. | ⚠ Aperto (mitigato dal copy onesto; richiede inviti reali → backend) |
| 3 | ALTO | Penalità ed espulsione comunicati con toast che svanisce in 3,5 s (la spec chiede *persistente*). | ✅ Corretto (D) |
| 4 | ALTO | Toast mai annunciato a VoiceOver (contro UX_SPEC §2.3). | ✅ Corretto (D) |
| 5 | ALTO | Contrasti sotto AA misurati: Brass su Paper 2,65:1, badge 2,31:1, ErrorTone su Ink 2,37:1. | ✅ Corretto (G) |
| 6 | ALTO | Nome utente mai modificabile; dopo reset/reinstallazione resta "Tu" per sempre. | ✅ Corretto (E) |
| 7 | MEDIO | Annullare Sign in with Apple trattato come errore. | ✅ Corretto (E) |
| 8 | MEDIO | Stili bottone ciechi a `isEnabled`: disabilitati identici agli attivi. | ✅ Corretto (H) |
| 9 | MEDIO | Menu destinazione e Nutre opachi a VoiceOver (né valore selezionato né contatore). | ✅ Corretto (H) |
| 10 | MEDIO | TableRingView altezza fissa 300pt in conflitto con l'onboarding. | ✅ Corretto (H) |
| 11 | BASSO | Icone a dimensione fissa, non scalano con Dynamic Type. | ⚠ Aperto (minore) |
| 12 | BASSO | Micro-deviazioni dal DS (radius 10 nelle richieste, scoreRow non-sobreCard); UX_SPEC non aggiornata al "da zero". | ⚠ Parzialmente aperto (spec: addendum aggiunto) |

## 2. Audit QA (lente: agent-qa)

| # | Gravità | Finding | Esito |
|---|---|---|---|
| 1 | CRITICO | **Crash-loop in migrazione**: se lo schema della vecchia build demo non migra, `ModelContainer` fallisce e `fatalError` blocca l'app a ogni lancio. | ✅ Corretto (B) |
| 2 | ALTO | **Espulsione silenziosa ad app chiusa**: zero notifiche locali; la perdita avviene a insaputa. | ✅ Corretto (C) |
| 3 | ALTO | `seedDemoData()` morto (mai invocato) e senza flag. | ✅ Corretto (F: bottone DEBUG nell'onboarding; il flag NON va settato — il seed esiste solo in build DEBUG, mai distribuite) |
| 4 | ALTO | Login Apple successivi senza nome → profilo "Tu" per sempre. | ✅ Corretto (E) |
| 5 | ALTO | L'animatore veniva espulso dal **proprio** circolo → circolo orfano irraggiungibile. | ✅ Corretto (F) |
| 6 | MEDIO | Destinazione stantia nel composer: post pubblicato in un circolo non più abitato. | ✅ Corretto (H) |
| 7 | MEDIO | Purge silenziosa + onboarding che non verificava la creazione del profilo. | ✅ Corretto (E: si esce dall'onboarding solo se `hasProfile()` è vero) |
| 8 | MEDIO | `invite()`/`accept()` senza guardie anti-duplicato. | ✅ Corretto (H) |
| 9 | MEDIO | Toast non annunciato a VoiceOver. | ✅ Corretto (D) |
| 10 | BASSO | Flash della schermata di accesso al lancio per utenti già registrati. | ✅ Corretto (E: deciso in `AppStore.init`) |
| 11 | BASSO | Annullo SIWA mostrato come errore. | ✅ Corretto (E) |
| 12 | BASSO | Tavola: flusso candidati morto in produzione. | ⚠ Aperto (= UX#2) |

## 3. Audit conformità (lente: agent-auditor)

| # | Gravità | Finding | Esito |
|---|---|---|---|
| 1 | CRITICO | **Nessuna privacy policy** (obbligatoria per App Store Connect, anche in beta). | ✅ Corretto (I: `privacy.html` sul sito; URL da inserire in ASC) |
| 2 | ALTO | Il sito caricava i font da Google Fonts: IP dei visitatori UE a Google senza consenso (GDPR). | ✅ Corretto (I: font self-hostati) |
| 3 | ALTO | Font OFL nel bundle **senza testo di licenza**. | ✅ Corretto (I: OFL.txt nel bundle + "Riconoscimenti" in Tu) |
| 4 | ALTO | Claim "codice aperto" senza file LICENSE nel repo. | ✅ Mitigato (I: claim riformulato). ⚠ Scelta della licenza: decisione dell'autore |
| 5 | MEDIO | Account deletion 5.1.1(v): ok per app locale, ma la credenziale SIWA resta lato Apple. | ⚠ Aperto (nota per le Review Notes; copy del reset già onesto) |
| 6 | MEDIO | SIWA obbligatorio per un'app locale: rischio 5.1.1(ii). | ⚠ Aperto (motivare nelle Review Notes; eventuale "continua senza accesso" è una scelta di prodotto) |
| 7 | MEDIO | App Privacy labels: dichiarare **Data Not Collected**; il copy "non ha *ancora* un server" preannunciava un cambio. | ✅ Corretto (copy privacy riscritto; label da dichiarare in ASC) |
| 8 | MEDIO | `onboarding.privacy` non citava l'`appleUserID`. | ✅ Corretto |
| 9 | BASSO | `toast.reset` fuorviante ("dati demo"). | ✅ Corretto |
| 10 | BASSO | Sito: `<footer>` dentro `<main>`. | ✅ Corretto (I) |
| 11 | BASSO | Sito senza header di sicurezza. | ✅ Corretto (I: CSP, X-Frame-Options, nosniff in vercel.json) |

## 4. Audit Neuromarketing (lente: agent-neuromarketer)

| # | Impatto | Finding | Esito |
|---|---|---|---|
| 1 | ALTO | Promessa d'onboarding non mantenibile ("apparecchia la tua tavola" con zero persone invitabili). | ✅ Corretto (copy: "fonda il tuo primo circolo") |
| 2 | ALTO | Primo minuto senza percorso: tre stanze vuote, nessun aha moment. | ✅ Corretto (H: card "I primi passi" a 3 tappe con spunte) |
| 3 | ALTO | **La brace puniva chi è solo**: espulso dal proprio circolo senza nessuno con cui parlare. | ✅ Corretto (F: brace "in attesa" sotto 2 membri, `emberMinimumMembers` in ProductRules) |
| 4 | ALTO | Loss aversion senza richiamo: la perdita avveniva a insaputa. | ✅ Corretto (C: notifica locale al giorno 4 e al giorno 7) |
| 5 | MEDIO | Espulsione = toast da 3,5 s. | ✅ Corretto (D) |
| 6 | MEDIO | Annullo SIWA colpevolizzante. | ✅ Corretto (E) |
| 7 | MEDIO | "Slot abitati" gergo da inventario. | ✅ Corretto ("Abiti N circoli su 5", plurale nelle 6 lingue) |
| 8 | MEDIO | Reset incoerente ("dati demo" all'ultimo istante). | ✅ Corretto |
| 9 | BASSO | `toast.penalita` contabile, senza via d'uscita. | ✅ Corretto (copy con CTA) |
| 10 | BASSO | Tagline/privacy: micro-incrinature di tono. | ✅ Privacy corretta; tagline mantenuta (è il motto del brief di prodotto) |

---

## Interventi applicati (tutti in questo push)

**A. La stanza del circolo** — nuova `CircoloRoomView`: `NavigationStack` nella tab Circoli, riga "Conversazione" su ogni card → stanza con testata (nome, tema, membri, stato brace), composer con destinazione già decisa, cronologia dei soli post del circolo, stato vuoto "Rompi tu il silenzio". `PostCard` resa riusabile.

**B. Migrazione a prova di crash** — se il `ModelContainer` non riesce ad aprire lo store (schema delle vecchie build demo), lo store si cancella e si ricrea da zero: i dati erano comunque finti e destinati alla purge. Mai più `fatalError` come prima risposta.

**C. Notifiche locali della brace** — nuovo `NotificationScheduler`: richiami schedulati sul dispositivo al giorno dell'avviso e al giorno dell'espulsione (valori da `ProductRules`), ricalcolati a ogni attività reale; permesso chiesto solo quando si inizia ad abitare un circolo, mai al primo avvio; sospesi nei circoli dove sei solo. Nessun server, nessun push remoto.

**D. Eventi gravi non più a scomparsa** — penalità ed espulsioni sono `sticky`: il banner resta finché non lo chiudi (✕ sempre presente, 44pt) ed è **annunciato a VoiceOver** (`AccessibilityNotification.Announcement`), come la spec chiedeva.

**E. Identità robusta** — annullo SIWA non è più un errore; se Apple non fornisce il nome (login successivi) l'onboarding lo chiede con un campo dedicato ("Siediti a tavola"); il nome è modificabile in Tu; si esce dall'onboarding solo se il profilo esiste davvero; niente flash della schermata di accesso al lancio.

**F. La brace ha senso solo in compagnia** — nuova regola `emberMinimumMembers = 2` in `ProductRules`: sotto quella soglia la brace è "in attesa" (dichiarato in UI), niente penalità né espulsioni né notifiche; e l'animatore non viene mai espulso dal proprio circolo. Seed demo richiamabile dal bottone DEBUG nell'onboarding.

**G. Contrasti AA** — nuovi colori `BrassDeep #8A6015` (testi ottone su carta, 4,6:1) e `ErrorSoft #E8917F` (errori su notte); badge "Presenza discreta" e label brace aggiornati.

**H. Pulizia trasversale** — guardie anti-duplicato su inviti/accoglienze; destinazione stantia del composer degradata alla tavola; stili bottone consapevoli di `isEnabled`; `accessibilityValue` su destinazione e Nutre; TableRing con altezza parametrica; card "I primi passi" nel Salotto.

**I. Sito e conformità** — `privacy.html` (informativa breve e vera: tutto sul dispositivo, nessuna raccolta); font self-hostati al posto di Google Fonts; footer fuori da `<main>`; claim GitHub riformulato; header di sicurezza in `vercel.json`; testi OFL nel bundle dell'app + card "Riconoscimenti" in Tu.

## Restano aperti (dichiarati)

1. **Gli inviti reali non esistono**: senza backend nessuno può sedersi alla tavola. È il limite strutturale del locale-only; la UI lo dichiara. Prossimo passo di prodotto: backend (o inviti via link/contatti).
2. **Review Notes per Apple**: motivare SIWA-only (5.1.1(ii)) e la revoca credenziale via Impostazioni (5.1.1(v)); dichiarare "Data Not Collected" nelle App Privacy labels; inserire l'URL privacy in App Store Connect.
3. **LICENSE del repo**: scelta dell'autore (MIT consigliata se si vuole il claim "aperto").
4. Minori: icone non scalate con Dynamic Type; due micro-deviazioni dal design system; UX_SPEC aggiornata per addendum, non riscritta.
