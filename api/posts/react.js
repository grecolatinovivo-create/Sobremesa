// POST /api/posts/react { postId, action: "nutre" | "comment", text? }
// Nutre: toggle reale per utente (mai doppio conteggio, per costruzione).
// Commento: +1, e azzera il silenzio se il post vive in un circolo abitato.
import { sql, applyScore } from "../_lib/db.js";
import { requireAuth } from "../_lib/auth.js";
import { RULES } from "../_lib/rules.js";

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "POST" });
  const me = await requireAuth(req, res);
  if (!me) return;

  const { postId, action, text } = req.body || {};
  const { rows: posts } = await sql`SELECT id, circle_id FROM posts WHERE id = ${postId}`;
  const post = posts[0];
  if (!post) return res.status(404).json({ error: "post inesistente" });

  if (action === "nutre") {
    const { rowCount } = await sql`
      DELETE FROM nutre WHERE post_id = ${postId} AND user_id = ${me.id}`;
    if (!rowCount) {
      await sql`INSERT INTO nutre (post_id, user_id) VALUES (${postId}, ${me.id})`;
    }
    return res.status(200).json({ nutrito: !rowCount });
  }

  if (action === "comment") {
    const clean = (text || "").trim().slice(0, 1000);
    if (!clean) return res.status(400).json({ error: "testo mancante" });
    const { rows } = await sql`
      INSERT INTO comments (post_id, author, text)
      VALUES (${postId}, ${me.id}, ${clean}) RETURNING id`;
    await applyScore(me.id, post.circle_id, "commento", RULES.pointsComment);
    if (post.circle_id) {
      await sql`UPDATE memberships SET last_activity = now(), penalty_applied = false
                WHERE user_id = ${me.id} AND circle_id = ${post.circle_id}`;
    }
    return res.status(200).json({ id: rows[0].id });
  }

  res.status(400).json({ error: "azione sconosciuta" });
}
