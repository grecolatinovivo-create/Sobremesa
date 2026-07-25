// POST /api/posts/react { postId, action: "nutre" }
// Nutre: toggle reale per utente (mai doppio conteggio, per costruzione).
import { sql } from "../_lib/db.js";
import { requireAuth } from "../_lib/auth.js";

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "POST" });
  const me = await requireAuth(req, res);
  if (!me) return;

  const { postId, action } = req.body || {};
  if (action !== "nutre") return res.status(400).json({ error: "azione sconosciuta" });
  const { rows: posts } = await sql`SELECT id FROM posts WHERE id = ${postId}`;
  if (!posts.length) return res.status(404).json({ error: "messaggio inesistente" });

  const { rowCount } = await sql`
    DELETE FROM nutre WHERE post_id = ${postId} AND user_id = ${me.id}`;
  if (!rowCount) {
    await sql`INSERT INTO nutre (post_id, user_id) VALUES (${postId}, ${me.id})`;
  }
  return res.status(200).json({ nutrito: !rowCount });
}
