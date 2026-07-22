# L10N_NOTES — Sobremesa

String Catalog: `Sobremesa/Resources/Localizable.xcstrings` — **133 chiavi**, di cui **7 con variazioni plurali**, tutte tradotte in **6 lingue**: italiano (lingua di sviluppo, `sourceLanguage: it`), inglese, spagnolo, francese, tedesco, portoghese (`pt`, convenzione Apple: portoghese brasiliano).

Zero stringhe hardcoded nelle view: ogni testo passa dal catalogo (chiavi statiche) o dalla risoluzione delle chiavi seed (`String.loc`). Date e numeri usano i formatter di sistema (`Text(_:format: .relative)`, `String.localizedStringWithFormat` per i plurali).

## Criteri di traduzione

Traduzione **editoriale, non letterale**: ogni termine di prodotto è stato reso cercando l'immagine equivalente nella lingua d'arrivo, non la parola equivalente. I nomi propri delle persone demo non si traducono; i contenuti demo (post, commenti, circoli, bio, interessi) sì, per intero.

## Glossario dei termini di prodotto

| Concetto | IT | EN | ES | FR | DE | PT |
|---|---|---|---|---|---|---|
| La reazione | Nutre | Nourish | Nutre | Nourrit | Nährt | Nutre |
| La brace | la brace | the embers | las brasas | la braise | die Glut | as brasas |
| CTA del silenzio | Riprendi la parola | Take the floor again | Retoma la palabra | Reprends la parole | Ergreife wieder das Wort | Retome a palavra |
| Azione sedia | Libera sedia | Free chair | Liberar silla | Libérer la chaise | Stuhl freigeben | Liberar cadeira |
| Fascia ≥75 | Voce viva | Living voice | Voz viva | Voix vive | Lebendige Stimme | Voz viva |
| Fascia ≥45 | Presenza discreta | Quiet presence | Presencia discreta | Présence discrète | Stille Präsenz | Presença discreta |
| Fascia <45 | Ombra al tavolo | Shadow at the table | Sombra en la mesa | Ombre à la table | Schatten am Tisch | Sombra à mesa |
| Il feed | Salotto | Salon | Salón | Salon | Salon | Sala |
| L'animatore | animatore | host | animador | animateur | Gastgeber | anfitrião |
| Motto circoli | Un circolo non si segue: si abita. | You don't follow a circle: you inhabit it. | Un círculo no se sigue: se habita. | Un cercle ne se suit pas : on l'habite. | Einem Zirkel folgt man nicht – man bewohnt ihn. | Um círculo não se segue: habita-se. |
| Motto tavola | Dodici è il numero giusto. Per una nuova voce, una deve alzarsi. | Twelve is the right number. For a new voice, one must stand up. | Doce es el número justo. Para una nueva voz, una debe levantarse. | Douze est le bon nombre. Pour une nouvelle voix, une doit se lever. | Zwölf ist die richtige Zahl. Für eine neue Stimme muss eine aufstehen. | Doze é o número certo. Para uma nova voz, uma precisa se levantar. |

Note per lingua:

- **EN** — "Nourish" mantiene la metafora alimentare/culturale del brand; "host" per l'animatore (più naturale di "animator", che in inglese è chi fa cartoni animati); "embers" al plurale, come si dice davvero dei tizzoni che restano vivi.
- **ES** — "sobremesa" è parola di casa: il copy la usa con naturalezza (il manifesto la dà per nota). "Animador" è corretto e usato per chi conduce un club di lettura.
- **FR** — spazi tipografici francesi prima di `?`, `!`, `:` e dentro « » rispettati in tutte le stringhe; tu informale coerente col tono del prodotto.
- **DE** — "Zirkel" (e non "Kreis") per il circolo: è il termine storico dei circoli letterari (Lesezirkel); "die Glut" è naturalmente singolare collettivo.
- **PT** — attenzione richiesta dal brief: **"sobremesa" in portoghese significa "dessert"**. Il brand resta Sobremesa ovunque, ma il copy PT disambigua dove serve: il manifesto apre con "Sobremesa — em espanhol, a conversa que fica à mesa depois da refeição —…" e il post demo sull'idea del giorno chiarisce "no sentido espanhol". Nessuna stringa PT usa "sobremesa" come nome comune, così l'ambiguità col dolce non si crea mai. Variante scelta: portoghese brasiliano ("você", "Ajustes"), codice `pt` come da convenzione Apple.

## Plurali

Gestiti con le variazioni plurali del String Catalog (mai concatenazioni): `post.comments.count`, `tavola.sedie.libere` ("1 sedia libera / N sedie libere"), `circolo.membri.count`, `circoli.richieste.section`, `circoli.catalogo.pieno`, `brace.affievolita`, `brace.avviso`. Le regole CLDR fanno il resto (es. in francese "0 commentaire" usa correttamente la forma *one*).

## Numeri nel copy

Il copy non contiene mai numeri di business scritti a mano: le soglie e i punti arrivano da `ProductRules` come argomenti di formato (es. `toast.penalita` riceve il valore −2 dall'engine; `circoli.catalogo.pieno` riceve il 5). Unica eccezione dichiarata: i motti del prodotto ("Dodici è il numero giusto…", "doce sillas, cinco círculos" nel manifesto), che sono testo editoriale, e l'etichetta del pulsante di debug.

## Multilingua interno (v1.1)

La lingua non è più legata al dispositivo: da **Tu → Lingua** si sceglie tra "Come il telefono" e le sei lingue, elencate col loro **endonimo** (Italiano, English, Español, Français, Deutsch, Português) — che per definizione non si traduce. Il cambio è immediato: le `Text` SwiftUI si localizzano dal `\.locale` d'ambiente iniettato alla radice, mentre tutte le stringhe programmatiche passano da `String(localized:bundle: L10n.bundle)`, dove `L10n.bundle` punta all'`.lproj` scelto (o a `.main` per "Come il telefono"). Le notifiche della brace già programmate vengono rigenerate nella nuova lingua al momento del cambio. `AppleLanguages` viene aggiornato in parallelo così che, al riavvio successivo, anche gli elementi disegnati dal sistema (bottone Sign in with Apple, formati di data) si allineino. La preferenza vive in `UserDefaults` (`sobremesa.lingua`) — non è una credenziale.

Nota per chi scrive codice: **mai** `String(localized:)` nudo — sempre con `bundle: L10n.bundle`, altrimenti quella stringa ignorerà la lingua scelta.
