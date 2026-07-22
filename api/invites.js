// POST /api/invites            → crea un codice d'invito alla tavola
// POST /api/invites?accept=1   → riscatta un codice { code }
import { sql, pair, friendCount } from "./_lib/db.js";
import { requireAuth } from "./_lib/auth.js";
import { RULES } from "./_lib/rules.js";
import { randomBytes } from "node:crypto";

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "POST" });
  const me = await requireAuth(req, res);
  if (!me) return;

  if (!req.query.accept) {
    // Nuovo codice: leggibile, senza ambiguità (niente 0/O, 1/I).
    const alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
    const code = Array.from(randomBytes(8)).map((b) => alphabet[b % alphabet.length]).join("");
    await sql`INSERT INTO invites (code, inviter) VALUES (${code}, ${me.id})`;
    return res.status(200).json({ code });
  }

  // Riscatto.
  const code = ((req.body || {}).code || "").trim().toUpperCase();
  const { rows } = await sql`SELECT * FROM invites WHERE code = ${code}`;
  const invite = rows[0];
  if (!invite || invite.status === "used") {
    return res.status(404).json({ error: "codice non valido" });
  }
  if (invite.inviter === me.id) {
    return res.status(400).json({ error: "non puoi invitare te stesso" });
  }
  const [a, b] = pair(invite.inviter, me.id);
  const { rows: existing } = await sql`SELECT 1 FROM friendships WHERE a = ${a} AND b = ${b}`;
  if (existing.length) {
    await sql`UPDATE invites SET status = 'used', used_by = ${me.id} WHERE code = ${code}`;
    return res.status(200).json({ seated: true, already: true });
  }
  // La MIA tavola deve avere posto; se quella dell'invitante è piena,
  // l'invito resta in sospeso e scatterà quando una sedia si libera.
  if ((await friendCount(me.id)) >= RULES.maxFriends) {
    return res.status(409).json({ error: "la tua tavola è piena" });
  }
  if ((await friendCount(invite.inviter)) >= RULES.maxFriends) {
    await sql`UPDATE invites SET status = 'pending_seat', used_by = ${me.id} WHERE code = ${code}`;
    return res.status(200).json({ seated: false, pending: true });
  }
  await sql`INSERT INTO friendships (a, b) VALUES (${a}, ${b}) ON CONFLICT DO NOTHING`;
  await sql`UPDATE invites SET status = 'used', used_by = ${me.id} WHERE code = ${code}`;
  res.status(200).json({ seated: true });
}
