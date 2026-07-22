# UX_SPEC — Sobremesa

Estetica guida: **"la sala lettura di una biblioteca la sera"**. Luce bassa, carta avorio, ottone caldo. L'app è dark-first: il tema scuro **è** l'identità, non un'opzione.

---

## 1. Architettura dell'informazione

```
TabView (4 tab)
├── 1. Salotto   — il feed: ciò che nutre, in ordine cronologico
├── 2. Tavola    — le 12 sedie: amici reciproci, inviti, "libera sedia"
├── 3. Circoli   — i 5 slot: brace, animatore, richieste, catalogo
└── 4. Tu        — profilo: punteggio, manifesto, lingua, reset demo
```

Gerarchia dei concetti: la **Tavola** è la relazione (chi), i **Circoli** sono i luoghi (dove), il **Salotto** è la conversazione (cosa), **Tu** è lo specchio (come sto partecipando).

Il punteggio di partecipazione appare **solo** in contesti decisionali (card persona nelle liste inviti/richieste) e nel proprio profilo / testata Circoli. Mai classifiche, mai punteggi sui post.

## 2. Design system

### 2.1 Colori (Asset Catalog, mai literal nel codice)

| Nome asset | Hex | Uso |
|---|---|---|
| `Ink` | `#14251F` | sfondo dell'app |
| `Felt` | `#1E3A31` | superfici scure (righe, pannelli secondari, campi) |
| `Paper` | `#F4EFE4` | card avorio, contenuti |
| `PaperDim` | `#E9E2D2` | card secondarie, superfici avorio smorzate |
| `Brass` | `#C08A2D` | accento: CTA, sedie occupate, tab attiva |
| `BrassSoft` | `#E4C98A` | testi/dettagli in ottone su superfici scure |
| `ErrorTone` | `#9E3B2F` | errori, avviso brace, fascia "Ombra al tavolo" |
| `SuccessTone` | `#3E6B4F` | conferme, brace viva, fascia "Voce viva" |

Regole di contrasto: testo su `Paper` è sempre `Ink` (contrasto 12.9:1). Testo su `Ink` è `Paper`/`PaperDim` (AA large e small). `Brass` su `Ink` è riservato ad accenti ≥18pt o elementi grafici; le CTA a pillola usano fondo `Brass` con testo `Ink` (5.9:1).

### 2.2 Tipografia

| Ruolo | Font | Fallback | Uso |
|---|---|---|---|
| Display / titoli / numeri | **Young Serif** (Regular) | `.serif` sistema | titoli di sezione, numero al centro della tavola, punteggio |
| Corpo dei post | **Source Serif 4** (variabile) | `.serif` sistema | testo dei post e dei commenti |
| UI | **Inter** (variabile) | `.default` sistema | label, bottoni, chip, badge, didascalie |

Scala (Dynamic Type: ogni stile è `relativeTo:` un `TextStyle` di sistema):
`displayXL 34/largeTitle · title 24/title2 · headline 17/headline · bodySerif 17/body · ui 15/subheadline · caption 13/caption1 · badge 12/caption2`

### 2.3 Componenti

- **Card avorio**: fondo `Paper`, angoli **14pt**, padding 16, ombra nulla (la profondità la dà il contrasto carta/notte).
- **Bottone pill**: capsula, fondo `Brass`, testo `Ink`, altezza ≥44pt; variante "quiet": bordo `BrassSoft` su fondo trasparente, testo `BrassSoft`.
- **Chip categoria**: capsula piccola con icona SF Symbol + label; selezionata: fondo `Brass`/testo `Ink`; non selezionata: bordo `Felt` su `Paper` o bordo `BrassSoft` su scuro.
- **Badge punteggio**: capsula con numero + nome fascia; colore per fascia: Voce viva `SuccessTone`, Presenza discreta `Brass`, Ombra al tavolo `ErrorTone`. Sempre accompagnato dal nome della fascia (mai solo colore — accessibilità daltonici).
- **Toast**: banner in basso, fondo `Felt`, testo `Paper`, bordo `BrassSoft`; auto-dismiss 3,5s; annunciato a VoiceOver.
- **Stato brace**: pallino + label testuale: viva (`SuccessTone`), si affievolisce (`Brass`), avviso (`ErrorTone`, con giorni e CTA "Riprendi la parola").

### 2.4 Icone categoria (SF Symbols)

Libro `book.closed.fill` · Film `film` · Musica `music.note` · Arte `paintpalette.fill` · Teatro `theatermasks.fill` · Idea `lightbulb.fill`. Nutre: `leaf.fill` (la cultura nutre, non si consuma).

### 2.5 Accessibilità

VoiceOver su ogni elemento interattivo; la tavola grafica è un unico elemento accessibile con descrizione equivalente ("Tavola: 9 sedie occupate su 12, 3 libere"); tap target ≥44pt; `reduceMotion` rispettato (le animazioni della tavola e dei toast degradano a dissolvenze o a nessun movimento); i colori non sono mai l'unico canale d'informazione.

## 3. Wireframe testuali

### 3.1 Salotto (feed)

```
[Titolo] Salotto                                  (Young Serif)
┌─ Card composer (Paper) ─────────────────────────┐
│ "Cosa ti ha nutrito oggi?"  (TextField, serif)  │
│ [⚠ inline: "Scrivi qualcosa prima…"]  (se vuoto)│
│ (chips) Libro Film Musica Arte Teatro Idea      │
│ (menu destinazione) 🞄 La tavola ▾               │
│                              [ Pubblica ] (pill)│
└─────────────────────────────────────────────────┘
┌─ Card post (Paper) ─────────────────────────────┐
│ (○EM) Elena Marchetti · nel circolo Lettori…    │
│ [chip: Libro]                        2 h fa     │
│ Testo del post in Source Serif 4 …              │
│ (🌿 Nutre 4)   (💬 3 commenti ▾)                │
│   └ commenti espansi + campo "Rispondi…" [Invia]│
└─────────────────────────────────────────────────┘
[stato vuoto] "Il salotto è silenzioso. / Racconta tu
cosa ti ha nutrito oggi."
```

- Errore composer **sempre inline**, mai alert.
- Nutre: toggle con contatore; secondo tap rimuove; mai doppio conteggio.
- Commentare un post di circolo → toast "La brace di «X» torna viva" + evento +1.

### 3.2 Tavola

```
[Titolo] Tavola
"Dodici è il numero giusto. Per una nuova voce,
 una deve alzarsi."                    (motto, serif)

        ◍ ◍ ◌ ◍          ← 12 sedie in cerchio
      ◍         ◍           occupate: cerchio Brass pieno + iniziali
     ◌     9/12  ◍          libere: tratteggio BrassSoft
      ◍         ◌        al centro: conteggio (Young Serif)
        ◍ ◍ ◍

[banner se invito in sospeso] (PaperDim)
 "La tavola è piena. Per invitare Pietro, libera
  una sedia."

— A tavola (9) ————————————————
(○EM) Elena Marchetti      [88 · Voce viva]
      poesia, cinema d'essai      [Libera sedia]
… (confirmationDialog: "Elena si alza dalla tavola?")

— Persone che potresti invitare (5) ————
(○PC) Pietro Colombo       [71 · Presenza discreta]
      fotografia, jazz               [ Invita ]
```

- Animazione discreta (spring breve / dissolvenza con reduceMotion) quando una sedia cambia stato.
- Auto-seduta: liberando una sedia con invito in sospeso, l'invitato si siede da solo → toast "Pietro si è seduto alla tavola".

### 3.3 Circoli

```
[Titolo] Circoli
┌─ riga punteggio (Felt) ─────────────────────────┐
│ Il tuo punteggio   63  [Presenza discreta]      │
└─────────────────────────────────────────────────┘
Slot abitati: 3/5                     (sempre visibile)

— I tuoi circoli ——————————————
┌─ Card (Paper) ──────────────────────────────────┐
│ Lettori del Novecento          [chip Libro]     │
│ Romanzi del secolo breve · 14 membri            │
│ ● La brace si affievolisce da 3 giorni          │
│                                     [Esci]      │
└─────────────────────────────────────────────────┘
┌─ Card con avviso ───────────────────────────────┐
│ ● Avviso: silenzio da 5 giorni (rosso)          │
│ [ Riprendi la parola ]  (pill Brass)            │
└─────────────────────────────────────────────────┘
┌─ Card animatore ────────────────────────────────┐
│ Sala d'ascolto     [Sei l'animatore]            │
│ — Richieste d'ingresso (2)                      │
│ (○BR) Bianca Romano   [82 · Voce viva]          │
│        jazz, minimalismo   [Accogli] [Declina]  │
│ (○OK) Otto Krause     [31 · Ombra al tavolo]    │
└─────────────────────────────────────────────────┘

— Circoli aperti ——————————————
│ Sguardi sull'arte · 21 membri        [ Entra ]  │
│ (a 5/5: bottone disabilitato + "Abiti già 5
│  circoli. Per entrare qui, lasciane uno.")      │
[DEBUG] Simula 3 giorni di silenzio
```

- Espulsione automatica → toast persistente: "Il tuo posto in «X» si è liberato: 7 giorni di silenzio."
- Il bottone Entra a 5/5 è **disabilitato e spiegato, mai nascosto**.

### 3.4 Tu

```
[Titolo] Tu
(○G) Giampiero  ·  63 [Presenza discreta]
bio breve (serif)
┌─ Card manifesto (Paper) ────────────────────────┐
│ "Sobremesa è il tempo che resta a tavola…"      │
└─────────────────────────────────────────────────┘
Lingua dell'app → (apre Impostazioni di sistema)
[Azzera i dati demo] (quiet, conferma distruttiva)
```

## 4. Flussi utente chiave

**F1 — Pubblicare.** Salotto → scrivo → (vuoto? errore inline, stop) → scelgo categoria → scelgo destinazione (tavola o circolo) → Pubblica → post in cima al feed, +2 punteggio; se destinazione circolo: silenzio azzerato, toast brace.

**F2 — Il 13° amico.** Tavola (12/12) → Invita su Pietro → nessuna aggiunta: banner "La tavola è piena. Per invitare Pietro, libera una sedia." → Libera sedia su un amico → conferma → la sedia si svuota e **Pietro si siede automaticamente** (animazione + toast). A <12 posti, Invita siede subito.

**F3 — La brace.** Nessuna attività in un circolo → giorno 2: "si affievolisce" (ottone) → giorno 4: avviso rosso + "Riprendi la parola" + **una** penalità −2 per quel periodo → giorno 7: il posto si libera da solo, −5, toast di spiegazione, slot N−1/5. Commentare/pubblicare/riprendere la parola in qualunque momento azzera il silenzio e il flag di penalità.

**F4 — Richieste d'ingresso (animatore).** Circoli → card del circolo animato → richiesta con nome, interessi, badge punteggio → Accogli (diventa membro, contatore aggiornato) oppure Declina (la richiesta scompare). Il punteggio è lo strumento decisionale.

**F5 — Entrare in un circolo.** Catalogo → Entra (se slot <5) → card passa tra "I tuoi circoli" con brace viva. A 5/5 il bottone resta visibile, disabilitato, con la spiegazione.

**F6 — Ritorno in foreground.** A ogni avvio/foreground l'app rivaluta il silenzio reale di tutti i circoli abitati e applica avvisi/penalità/espulsioni con relative notifiche in-app.

---

## Addendum v1.1 — Da zero e la stanza del circolo (post-audit)

L'app parte **da zero**: onboarding con Sign in with Apple (solo nome; se Apple non lo fornisce lo chiede un campo dedicato), nessun dato demo, card "I primi passi" nel Salotto (3 tappe con spunte) come percorso del primo minuto. Ogni circolo ha ora la sua **stanza** (`CircoloRoomView`): dalla card, riga "Conversazione" → testata con tema/membri/brace, composer con destinazione già decisa, cronologia dei soli post del circolo. La **brace** è valutata solo con ≥2 membri ("La brace si accenderà quando sarete almeno in due"), ha **richiami locali** al giorno 4 e 7, e gli eventi gravi usano banner **persistenti** con chiusura esplicita, annunciati a VoiceOver. Nuovi colori `BrassDeep` (ottone su carta, AA) ed `ErrorSoft` (errori su notte). "Azzera i dati demo" è diventato "Ricomincia da zero". Il nome è modificabile in Tu; in Tu vive anche "Riconoscimenti" (font OFL).
