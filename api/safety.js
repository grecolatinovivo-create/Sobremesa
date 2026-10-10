// POST /api/safety — la sicurezza dei tavoli (Apple Guideline 1.2: contenuti
// generati dagli utenti). Un solo endpoint, tre gesti:
//
//   { action: "report",  postId, reason }  → segnala un intervento
//   { action: "block",   userId }          → blocca una persona
//   { action: "unblock", userId }          → la sblocca
//
// Segnalare: l'intervento sparisce SUBITO per chi segnala; quando lo
// segnalano persone diverse (RULES.reportsToHide) sparisce per tutti, in
// attesa della revisione (GET /api/admin/migrate?op=reports).
// Bloccare: non vedo più i suoi interventi né le sue richieste ai miei
// tavoli, e lui non può più bussare ai tavoli che animo.
import { sql, ensureSchema } from "./_lib/db.js";
import { requireAuth } from "./_lib/auth.js";
import { RULES } from "./_lib/rules.js";

const REASONS = ["offensivo", "molesto", "spam", "altro"];

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "POST" });
  const me = await requireAuth(req, res);
  if (!me) return;
  await ensureSchema();

  const { action, postId, userId, reason } = req.body || {};

  if (action === "report") {
    if (!postId) return res.status(400).json({ error: "postId mancante" });
    // Si segnala ciò che si può leggere: un intervento altrui a un mio tavolo.
    const { rows } = await sql`
      SELECT p.id, p.author FROM posts p
      JOIN memberships m ON m.circle_id = p.circle_id AND m.user_id = ${me.id}
      WHERE p.id = ${postId}`;
    const post = rows[0];
    if (!post) return res.status(404).json({ error: "intervento inesistente" });
    if (post.author === me.id) return res.status(400).json({ error: "non si segnala il proprio intervento" });
    const why = REASONS.includes(reason) ? reason : "altro";
    await sql`INSERT INTO reports (post_id, reporter, reason)
              VALUES (${postId}, ${me.id}, ${why}) ON CONFLICT DO NOTHING`;
    const { rows: count } = await sql`
      SELECT COUNT(*)::int AS n FROM reports WHERE post_id = ${postId}`;
    const hidden = count[0].n >= RULES.reportsToHide;
    if (hidden) await sql`UPDATE posts SET hidden = true WHERE id = ${postId}`;
    return res.status(200).json({ ok: true, reported: true, hidden });
  }

  if (action === "block" || action === "unblock") {
    if (!userId) return res.status(400).json({ error: "userId mancante" });
    if (userId === me.id) return res.status(400).json({ error: "non ci si blocca da soli" });
    if (action === "block") {
      const { rows: exists } = await sql`SELECT 1 FROM users WHERE id = ${userId}`;
      if (!exists.length) return res.status(404).json({ error: "persona inesistente" });
      await sql`INSERT INTO blocks (blocker, blocked) VALUES (${me.id}, ${userId})
                ON CONFLICT DO NOTHING`;
      // Le sue richieste ai miei tavoli decadono.
      await sql`DELETE FROM join_requests r USING circles c
                WHERE r.circle_id = c.id AND c.animator = ${me.id} AND r.user_id = ${userId}`;
      return res.status(200).json({ ok: true, blocked: true });
    }
    await sql`DELETE FROM blocks WHERE blocker = ${me.id} AND blocked = ${userId}`;
    return res.status(200).json({ ok: true, blocked: false });
  }

  res.status(400).json({ error: "azione sconosciuta" });
}
