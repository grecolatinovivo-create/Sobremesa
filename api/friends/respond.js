// POST /api/friends/respond  { requestId, accept } — la risposta a una
// proposta di sedia. Accettare crea l'amicizia (se c'è posto per entrambi).
import { sql, pair, friendCount } from "../_lib/db.js";
import { requireAuth } from "../_lib/auth.js";
import { RULES } from "../_lib/rules.js";

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "POST" });
  const me = await requireAuth(req, res);
  if (!me) return;

  const { requestId, accept } = req.body || {};
  const { rows } = await sql`
    SELECT id, from_user FROM friend_requests
    WHERE id = ${requestId} AND to_user = ${me.id}`;
  if (!rows.length) return res.status(404).json({ error: "richiesta inesistente" });
  const other = rows[0].from_user;

  if (!accept) {
    await sql`DELETE FROM friend_requests WHERE id = ${requestId}`;
    return res.status(200).json({ declined: true });
  }

  if ((await friendCount(me.id)) >= RULES.maxFriends) {
    return res.status(409).json({ error: "la tua tavola è piena" });
  }
  if ((await friendCount(other)) >= RULES.maxFriends) {
    // Nel frattempo la tavola dell'altro si è riempita: la proposta decade.
    await sql`DELETE FROM friend_requests WHERE id = ${requestId}`;
    return res.status(409).json({ error: "la sua tavola nel frattempo si è riempita" });
  }

  const [a, b] = pair(me.id, other);
  await sql`DELETE FROM friend_requests
            WHERE (from_user = ${other} AND to_user = ${me.id})
               OR (from_user = ${me.id} AND to_user = ${other})`;
  await sql`INSERT INTO friendships (a, b) VALUES (${a}, ${b}) ON CONFLICT DO NOTHING`;
  res.status(200).json({ seated: true });
}
