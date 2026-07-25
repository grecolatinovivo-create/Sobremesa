// POST /api/posts { tableId, text } — un messaggio al tavolo (+1,
// e la brace si ravviva). Nel modello v2 si parla SOLO ai tavoli.
import { sql, applyScore } from "../_lib/db.js";
import { requireAuth } from "../_lib/auth.js";
import { RULES } from "../_lib/rules.js";

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "POST" });
  const me = await requireAuth(req, res);
  if (!me) return;

  const { tableId, text } = req.body || {};
  const clean = (text || "").trim().slice(0, 2000);
  if (!clean) return res.status(400).json({ error: "testo mancante" });
  if (!tableId) return res.status(400).json({ error: "tableId mancante" });

  const { rows: seated } = await sql`
    SELECT 1 FROM memberships WHERE user_id = ${me.id} AND circle_id = ${tableId}`;
  if (!seated.length) return res.status(403).json({ error: "non siedi a questo tavolo" });

  const { rows } = await sql`
    INSERT INTO posts (author, circle_id, text)
    VALUES (${me.id}, ${tableId}, ${clean}) RETURNING id`;
  await applyScore(me.id, tableId, "messaggio", RULES.pointsComment);
  await sql`UPDATE memberships SET last_activity = now(), penalty_applied = false
            WHERE user_id = ${me.id} AND circle_id = ${tableId}`;
  res.status(200).json({ id: rows[0].id });
}
