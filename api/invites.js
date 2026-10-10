// POST /api/invites            { tableId } → un codice per sedersi a QUEL tavolo
// POST /api/invites?accept=1   { code }    → riscatta il codice e siediti
//
// Il codice è MONOUSO ("Un codice, una sedia"): chi lo riscatta per primo
// si siede, e il codice si spegne. Se la sedia non c'è più (tavolo al
// completo, o troppi tavoli), il codice torna valido per qualcun altro.
import { sql, seat, schemaV3 } from "./_lib/db.js";
import { requireAuth } from "./_lib/auth.js";
import { randomBytes } from "node:crypto";

// GET /i/CODICE (riscritto su /api/invites?page=CODICE) → la pagina del link
// d'invito: un bottone che apre l'app (sobremesa://invito/CODICE) e il codice
// in chiaro come ripiego. Nessun dato personale, nessuno script.
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

async function invitePage(req, res) {
  const code = String(req.query.page || "").toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 8);
  let table = null;
  if (code.length === 8) {
    try {
      const { rows } = await sql`
        SELECT c.name FROM invites i JOIN circles c ON c.id = i.circle_id
        WHERE i.code = ${code} AND i.status = 'open'`;
      table = rows[0]?.name ?? null;
    } catch { table = null; }
  }
  const shown = code.length === 8 ? `${code.slice(0, 4)}-${code.slice(4)}` : code;
  const title = table ? `Siediti a «${esc(table)}»` : "Un invito a Sobremesa";
  const html = `<!doctype html><html lang="it"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${title} · Sobremesa</title>
<style>
:root{color-scheme:dark}
body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;
background:#0F1A16;color:#F2E8D5;font-family:Georgia,"Times New Roman",serif;padding:24px;box-sizing:border-box}
main{max-width:420px;width:100%;text-align:center}
h1{font-weight:400;font-size:30px;line-height:1.2;margin:0 0 12px}
p{color:#C9BBA0;font-size:17px;line-height:1.5;margin:0 0 28px}
a.btn{display:block;background:linear-gradient(#E3B866,#C4954A);color:#1B140B;text-decoration:none;
font:600 17px -apple-system,system-ui,sans-serif;padding:16px;border-radius:14px}
.code{margin:28px 0 8px;font:500 26px -apple-system,system-ui,sans-serif;letter-spacing:2px;
border:1px solid rgba(196,149,74,.8);border-radius:13px;padding:16px}
small{color:#8E8470;font:13px -apple-system,system-ui,sans-serif;line-height:1.5;display:block}
</style></head><body><main>
<h1>${title}</h1>
<p>${table ? "Ti hanno tenuto una sedia. Apri Sobremesa e sei a tavola." : "Apri Sobremesa per sederti al tavolo."}</p>
${code.length === 8 ? `<a class="btn" href="sobremesa://invito/${code}">Apri in Sobremesa</a>
<div class="code">${shown}</div>
<small>Se il bottone non funziona: in Sobremesa vai su Tavoli e inserisci questo codice.<br>
Non hai ancora l'app? Chiedi a chi ti ha invitato l'accesso a TestFlight.</small>` : `<small>Questo link non contiene un codice valido.</small>`}
</main></body></html>`;
  res.setHeader("Content-Type", "text/html; charset=utf-8");
  res.setHeader("Cache-Control", "no-store");
  return res.status(200).send(html);
}

export default async function handler(req, res) {
  if (req.method === "GET" && req.query.page !== undefined) return invitePage(req, res);
  if (req.method !== "POST") return res.status(405).json({ error: "POST" });
  const me = await requireAuth(req, res);
  if (!me) return;
  await schemaV3(); // garantisce invites.circle_id (mai un'eccezione)

  if (!req.query.accept) {
    // Un invito nasce sempre A un tavolo, e lo crea chi ci siede.
    const { tableId } = req.body || {};
    if (!tableId) return res.status(400).json({ error: "tableId mancante" });
    const { rows: seated } = await sql`
      SELECT 1 FROM memberships WHERE user_id = ${me.id} AND circle_id = ${tableId}`;
    if (!seated.length) return res.status(403).json({ error: "non siedi a questo tavolo" });
    // Codice leggibile, senza ambiguità (niente 0/O, 1/I).
    const alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
    const code = Array.from(randomBytes(8)).map((b) => alphabet[b % alphabet.length]).join("");
    try {
      await sql`INSERT INTO invites (code, inviter, circle_id) VALUES (${code}, ${me.id}, ${tableId})`;
    } catch (error) {
      console.error("invito non creato:", error);
      return res.status(500).json({ error: "invito non creato", detail: String(error.message || error).slice(0, 160) });
    }
    return res.status(200).json({ code });
  }

  // Riscatto. Il codice si mostra "Q7M4-K2LP": trattini e spazi non contano.
  const code = ((req.body || {}).code || "").toUpperCase().replace(/[^A-Z0-9]/g, "");
  if (code.length !== 8) return res.status(404).json({ error: "codice non valido" });
  const { rows } = await sql`SELECT * FROM invites WHERE code = ${code}`;
  const invite = rows[0];
  if (!invite || invite.status !== "open" || !invite.circle_id) {
    return res.status(404).json({ error: "codice non valido" });
  }
  const { rows: already } = await sql`
    SELECT 1 FROM memberships WHERE user_id = ${me.id} AND circle_id = ${invite.circle_id}`;
  if (already.length) return res.status(409).json({ error: "siedi già a questo tavolo", tableId: invite.circle_id });

  // 1. Consumo atomico del codice: solo UN riscatto passa (status='open' nel WHERE).
  const { rowCount: consumed } = await sql`
    UPDATE invites SET status = 'used', used_by = ${me.id}
    WHERE code = ${code} AND status = 'open'`;
  if (!consumed) return res.status(404).json({ error: "codice non valido" });

  // 2. La sedia, garantita dal database. Se non c'è, il codice si riaccende.
  const result = await seat(me.id, invite.circle_id);
  if (!result.ok) {
    await sql`UPDATE invites SET status = 'open', used_by = NULL WHERE code = ${code}`;
    return res.status(result.status).json({ error: result.error });
  }
  res.status(200).json({ seated: true, tableId: invite.circle_id });
}
