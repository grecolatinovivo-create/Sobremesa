// POST /api/friends/remove { friendId } — "Libera sedia".
// Se c'è un invito in sospeso, l'invitato si siede automaticamente.
import { sql, pair, friendCount } from "../_lib/db.js";
import { requireAuth } from "../_lib/auth.js";
import { RULES } from "../_lib/rules.js";

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "POST" });
  const me = await requireAuth(req, res);
  if (!me) return;

  const { friendId } = req.body || {};
  if (!friendId) return res.status(400).json({ error: "friendId mancante" });
  const [a, b] = pair(me.id, friendId);
  await sql`DELETE FROM friendships WHERE a = ${a} AND b = ${b}`;

  // Auto-seduta: il più antico invito in sospeso occupa la sedia liberata.
  let seated = null;
  const { rows: pending } = await sql`
    SELECT code, used_by FROM invites
    WHERE inviter = ${me.id} AND status = 'pending_seat'
    ORDER BY created_at LIMIT 1`;
  if (pending.length && (await friendCount(me.id)) < RULES.maxFriends) {
    const guest = pending[0].used_by;
    if ((await friendCount(guest)) < RULES.maxFriends) {
      const [pa, pb] = pair(me.id, guest);
      await sql`INSERT INTO friendships (a, b) VALUES (${pa}, ${pb}) ON CONFLICT DO NOTHING`;
      await sql`UPDATE invites SET status = 'used' WHERE code = ${pending[0].code}`;
      const { rows } = await sql`SELECT id, name FROM users WHERE id = ${guest}`;
      seated = rows[0] || null;
    }
  }
  res.status(200).json({ ok: true, autoSeated: seated });
}
