// POST /api/friends/request  { userId } — "Proponi una sedia": dalla stanza
// di un circolo si propone a un membro di sedersi alla propria tavola.
// Se l'altro aveva già proposto a me, le due volontà si incontrano: amicizia.
import { sql, pair, friendCount } from "../_lib/db.js";
import { requireAuth } from "../_lib/auth.js";
import { RULES } from "../_lib/rules.js";

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "POST" });
  const me = await requireAuth(req, res);
  if (!me) return;

  const { userId } = req.body || {};
  if (!userId || userId === me.id) return res.status(400).json({ error: "destinatario non valido" });

  const { rows: target } = await sql`SELECT id FROM users WHERE id = ${userId}`;
  if (!target.length) return res.status(404).json({ error: "persona inesistente" });

  const [a, b] = pair(me.id, userId);
  const { rows: existing } = await sql`SELECT 1 FROM friendships WHERE a = ${a} AND b = ${b}`;
  if (existing.length) return res.status(409).json({ error: "già alla tua tavola" });

  if ((await friendCount(me.id)) >= RULES.maxFriends) {
    return res.status(409).json({ error: "la tua tavola è piena" });
  }

  // Se l'altro mi aveva già proposto una sedia, è un sì reciproco.
  const { rows: reverse } = await sql`
    SELECT id FROM friend_requests WHERE from_user = ${userId} AND to_user = ${me.id}`;
  if (reverse.length) {
    if ((await friendCount(userId)) >= RULES.maxFriends) {
      return res.status(409).json({ error: "la sua tavola è piena" });
    }
    await sql`DELETE FROM friend_requests
              WHERE (from_user = ${userId} AND to_user = ${me.id})
                 OR (from_user = ${me.id} AND to_user = ${userId})`;
    await sql`INSERT INTO friendships (a, b) VALUES (${a}, ${b}) ON CONFLICT DO NOTHING`;
    return res.status(200).json({ seated: true });
  }

  await sql`INSERT INTO friend_requests (from_user, to_user)
            VALUES (${me.id}, ${userId}) ON CONFLICT DO NOTHING`;
  res.status(200).json({ requested: true });
}
