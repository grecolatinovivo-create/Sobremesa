// POST /api/posts { text, category, circleId? } — pubblicare (+2).
// Pubblicare in un circolo azzera il silenzio della propria brace.
import { sql, applyScore } from "../_lib/db.js";
import { requireAuth } from "../_lib/auth.js";
import { RULES } from "../_lib/rules.js";

const CATEGORIES = ["libro", "film", "musica", "arte", "teatro", "idea"];

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "POST" });
  const me = await requireAuth(req, res);
  if (!me) return;

  const { text, category = "idea", circleId = null } = req.body || {};
  const clean = (text || "").trim().slice(0, 2000);
  if (!clean) return res.status(400).json({ error: "testo mancante" });

  if (circleId) {
    const { rows } = await sql`
      SELECT 1 FROM memberships WHERE user_id = ${me.id} AND circle_id = ${circleId}`;
    if (!rows.length) return res.status(403).json({ error: "non abiti questo circolo" });
  }
  const cat = CATEGORIES.includes(category) ? category : "idea";
  const { rows } = await sql`
    INSERT INTO posts (author, circle_id, category, text)
    VALUES (${me.id}, ${circleId}, ${cat}, ${clean}) RETURNING id`;
  await applyScore(me.id, circleId, "pubblicazione", RULES.pointsPost);
  if (circleId) {
    await sql`UPDATE memberships SET last_activity = now(), penalty_applied = false
              WHERE user_id = ${me.id} AND circle_id = ${circleId}`;
  }
  res.status(200).json({ id: rows[0].id });
}
