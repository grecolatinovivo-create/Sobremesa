// POST /api/invites            { tableId } → un codice per sedersi a QUEL tavolo
// POST /api/invites?accept=1   { code }    → riscatta il codice e siediti
//
// Il codice è MONOUSO ("Un codice, una sedia"): chi lo riscatta per primo
// si siede, e il codice si spegne. Se la sedia non c'è più (tavolo al
// completo, o troppi tavoli), il codice torna valido per qualcun altro.
import { sql, seat, schemaV3 } from "./_lib/db.js";
import { requireAuth } from "./_lib/auth.js";
import { randomBytes } from "node:crypto";

export default async function handler(req, res) {
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
  if (already.length) return res.status(409).json({ error: "siedi già a questo tavolo" });

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
