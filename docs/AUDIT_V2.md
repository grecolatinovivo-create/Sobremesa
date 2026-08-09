# Audit v2 a tre voci — Developer · Neuromarketing · UI

Tre esperti hanno fatto il giro completo di Sobremesa v2 ("solo tavoli") sul codice reale.
Esito: **13 finding tecnici** (4 alti), **12 raccomandazioni di loop**, **15 finding UI** (5 alti).
Qui: cosa è stato CORRETTO in questa iterazione e cosa resta in roadmap.

## Corretto — Developer

1. ✅ **Sync per upsert** (il finding più grave): `applySync` non azzera più lo store — aggiorna in place per `serverID`, adotta i record ottimistici (niente duplicati post-fondazione, niente messaggi persi offline), cancella solo ciò che il server non conosce più. Le view non tengono mai riferimenti a oggetti cancellati; la stanza ha comunque una guardia `isAlive` con schermata "il tavolo si è chiuso".
2. ✅ **Tavoli chiusi raggiungibili**: il catalogo include anche i chiusi (con lucchetto e "Chiedi di sederti"); la fondazione ha il toggle aperto/chiuso. La catena richiesta→decisione ora è un flusso vero.
3. ✅ **`penalty_applied` nel sync**: niente più −2 ripetuti a ogni foreground.
4. ✅ **Race sulle sedie**: INSERT guardati in un solo statement (join, riscatto invito, accoglienza richiesta) — la 13ª sedia è impossibile anche in concorrenza; riscatto del codice atomico (un codice, un solo uso).
5. ✅ **`remote()` risincronizza sui rifiuti** (409): l'ottimismo locale rientra, con un toast onesto ("toast.rifiutato") invece del fuorviante "sei offline".
6. ✅ **Salotto reattivo**: `@Query` sulle Membership (la fondazione del primo tavolo aggiorna la home da sola).
7. ✅ **Niente notifica di espulsione all'animatore** (che non viene mai espulso).
8. ✅ **Cancellazione account verificata**: la DELETE controlla lo status HTTP.
9. ✅ **`CRON_SECRET` assente = porta chiusa** + confronto a tempo costante.
10. ✅ **`catalogQuery` non resta appiccicata**: si azzera quando il campo si svuota.

## Corretto — Loop (neuromarketing)

- ✅ **"N interventi nuovi"** nel Salotto (`lastReadAt` per sedia, mai toccato dal sync): la ricompensa alla riapertura è ciò che gli altri hanno detto. Nome in semibold + punto ottone — niente rosso, niente badge.
- ✅ **Il rituale della sera** (Tu → "Il tuo momento"): UNA notifica locale al giorno, all'ora scelta, solo se hai tavoli. Un campanile, non una slot.
- ✅ **I Nutre ricevuti arrivano**: al sync, se le tue parole hanno nutrito qualcuno, un toast aggregato lo dice.
- ✅ **Da soli si invita, non si monologa**: stanza con card "A tavola si parla almeno in due" + invito a portata di pollice; copy dell'empty state riscritto.
- ✅ **L'avviso-brace propone due vie**: riprendi la parola *o apparecchia per una voce nuova* (notifica giorno 4 riscritta + bottone rapido in stanza).
- ✅ **Anzianità visibile**: "Viva — a questo tavolo da N giorni" (endowment sobrio).
- ✅ **Tagline emotiva** nell'onboarding (il manifesto al posto del pitch).

## Corretto — UI

- ✅ Chip categoria leggibili nella fondazione (onDark); pallino brace 10pt a contrasto vero (BrassDeep/ErrorTone su carta) e parlante per VoiceOver; icone categoria su cerchio Felt pieno.
- ✅ Stanza: testata FISSA (tema + sedie + brace in `safeAreaInset(top)`), codice invito in **sheet** dedicato (mai più fuori schermo), bolle altrui su Felt pieno con bordo ottone, Nutre solo sui messaggi altrui (e guardia anti-auto-nutre nel servizio), tap target ≥44pt, azione VoiceOver dedicata sulla bolla.
- ✅ Tavoli: ordine codice→catalogo→fonda, ricerca che filtra LIVE, raggio campo 14, placeholder d'esempio.
- ✅ Salotto: n/12 accanto al nome; ✕ del toast a 44pt.

## Roadmap (non in questa build, decisioni prese)

1. **Push remoto APNs** ("qualcuno ha parlato al tuo tavolo", digest max 1/giorno/tavolo) — richiede tabella device_tokens + invio da `posts` — la leva di ritorno più forte.
2. **Background App Refresh** come ponte senza server (sync in background + notifica locale se ci sono interventi nuovi).
3. **Invito come universal link** (`sobremesa.app/t/CODICE`) — azzera l'attrito del codice ricopiato.
4. **I "tavoli della casa"**: 6 tavoli ufficiali animati dal team, uno per categoria — la leva D7 finché la rete è piccola (operativa, non di codice).
5. Dynamic Type completo su icone e diametri (@ScaledMetric diffuso).
