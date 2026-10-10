# Brainstorming notturno — Claude × Astra (ottobre 2026)

Sessione di lavoro a due voci sulla v3 di Sobremesa: **Astra** (design lead visiva, GPT) ha guidato direzione artistica e revisione critica; **Claude** ha implementato in SwiftUI e nel backend, rispondendo a ogni obiezione con codice o con una motivazione.

## Round 1 — Critica e direzioni
- **Tenere**: identità verde/ottone/avorio, i tre caratteri, le tre tab, il lessico (Nutre, rituale).
- **Buttare**: card avorio ovunque, icone di categoria nei cerchi, brace come pallino, bolle da messaggistica, punteggio pubblico, gerarchia piatta.
- Tre direzioni: **Ultima luce** (scelta), Pagina aperta, Costellazione.
- Obiezione chiave: la brace del tavolo è collettiva, il silenzio di 4/7 giorni è personale → non vanno rappresentati con lo stesso segno (DECISIONI #39).

## Round 2 — Mockup ad alta fedeltà
Stanza, Salotto, Onboarding, Tavoli, Tu + specifiche: margini 20, griglia 8 pt, titoli 28, corpo Source Serif 17–18, composer 52/r20, invio 44, transizioni fade + 8 pt in 0,25–0,3 s, microcopy. Correzioni di aderenza di Claude: niente presenza in tempo reale, niente ingranaggio, "Crediti" invece di "Riconoscimenti", niente campanella.

## Round 3 — Schermate secondarie e icona
Foglio Commensali (anello 228 con iniziali, ordine d'arrivo, fascia a parola), Invita ("Un codice, una sedia.", codice a blocchi Q7M4-K2LP, Condividi + Copia), Fonda (categorie 2 colonne, Aperto/Chiuso, "Apparecchia"), Stanza in attesa ("Per ora siete in uno."), Salotto vuoto ("Nessun tavolo, per ora."), icona definitiva: 11 sedie piene + una libera a ore 12, brace al centro.

## Round 4 — Revisione severa pre-TestFlight (10 punti) e sito
| # | Priorità | Punto di Astra | Esito |
|---|---|---|---|
| 1 | Alta | Moderazione UGC (segnala, blocca, contatto, meccanismo reale) | ✅ Fatto (DECISIONI #42) |
| 2 | Alta | "Ricomincia da zero" ambiguo; privacy dentro Tu | ✅ "Elimina account e dati" + Tu → Sicurezza e privacy |
| 3 | Alta | Atomicità di sedie, limiti, codici | ✅ Trigger nel DB, testato con concorrenza reale (#43) |
| 4 | Alta | Contratto temporale esatto; Warning troppo presto | ✅ Precedenze e soglie nei test dell'engine; Warning dal 6° giorno |
| 5 | Alta | Accessibilità reale (VoiceOver, glifo, raggruppati) | ✅ Lato codice; ⏳ prova su iPhone reale |
| 6 | Media | Brace accesa in schermate vuote = stato falso | ✅ Salotto vuoto In attesa |
| 7 | Media | Nutre con numero = vanity metric | ✅ Niente numeri |
| 8 | Media | Etichette "Da decidere", "Tavoli aperti" | ✅ Rinominate |
| 9 | Media | Autoscroll che strappa chi legge | ✅ Pillola "nuovi interventi ↓" |
| 10 | Bassa | Non aggiungere effetti a icona/glifo | ✅ Rispettato |

Sito: landing riscritta col copy e l'architettura di Astra (7 sezioni), privacy aggiornata, nuova pagina Condizioni d'uso.

## Round 5 — Via libera
Vedi la risposta di Astra riportata in fondo al QA_REPORT (sezione v3).

## Il test che Astra propone (prossimo passo, con persone vere)
Cinque persone che non conoscono il progetto, dopo aver visto Salotto e Stanza, senza aiuto:
1. «Che cosa significa sedersi a un tavolo?»
2. «Che cosa ti sta dicendo quella brace?»
3. «Che cosa succede se non parli per una settimana?»
Se rispondono bene, l'interfaccia fa il suo lavoro; altrimenti si corregge il punto preciso in cui la metafora smette di essere comprensibile.
