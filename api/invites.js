// POST /api/invites            { tableId } → un codice per sedersi a QUEL tavolo
// POST /api/invites?accept=1   { code }    → riscatta il codice e siediti
import { sql, myTableIds, seatCount } from "./_lib/db.js";
import { requireAuth } from "./_lib/auth.js";
import { RULES } from "./_lib/rules.js";
import { randomBytes } from "node:crypto";

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "POST" });
  const me = await requireAuth(req, res);
  if (!me) return;

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
    await sql`INSERT INTO invites (code, inviter, circle_id) VALUES (${code}, ${me.id}, ${tableId})`;
    return res.status(200).json({ code });
  }

  // Riscatto: la sedia è a quel tavolo, se c'è posto per tutti e due i vincoli.
  const code = ((req.body || {}).code || "").trim().toUpperCase();
  const { rows } = await sql`SELECT * FROM invites WHERE code = ${code}`;
  const invite = rows[0];
  if (!invite || invite.status !== "open" || !invite.circle_id) {
    return res.status(404).json({ error: "codice non valido" });
  }
  const { rows: already } = await sql`
    SELECT 1 FROM memberships WHERE user_id = ${me.id} AND circle_id = ${invite.circle_id}`;
  if (already.length) return res.status(409).json({ error: "siedi già a questo tavolo" });
  if ((await myTableIds(me.id)).length >= RULES.maxCircles) {
    return res.status(409).json({ error: "siedi già al massimo dei tavoli" });
  }
  if ((await seatCount(invite.circle_id)) >= RULES.maxFriends) {
    return res.status(409).json({ error: "il tavolo è al completo" });
  }
  // Consumo atomico del codice: solo UN riscatto passa (status='open' nel WHERE).
  const { rowCount: consumed } = await sql`
    UPDATE invites SET status = 'used', used_by = ${me.id}
    WHERE code = ${code} AND status = 'open'`;
  if (!consumed) return res.status(404).json({ error: "codice non valido" });
  const { rowCount: seated } = await sql`
    INSERT INTO memberships (user_id, circle_id)
    SELECT ${me.id}, ${invite.circle_id}
    WHERE (SELECT COUNT(*) FROM memberships WHERE circle_id = ${invite.circle_id}) < ${RULES.maxFriends}
    ON CONFLICT DO NOTHING`;
  if (!seated) return res.status(409).json({ error: "il tavolo è al completo" });
  res.status(200).json({ seated: true });
}
