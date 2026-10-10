// GET /api/sync — il mondo dell'utente in una chiamata, modello "solo
// tavoli": profilo, i miei tavoli (con chi ci siede), il catalogo da
// scoprire, le richieste da decidere, i messaggi delle conversazioni.
//
// v3 (sicurezza): non arrivano gli interventi nascosti dalla moderazione,
// quelli che ho segnalato io, né quelli di chi ho bloccato. `blocked`
// elenca le persone bloccate (Tu → Persone bloccate); `hidden` gli id degli
// interventi da togliere anche dalla memoria locale del telefono.
import { sql, ensureSchema } from "./_lib/db.js";
import { requireAuth } from "./_lib/auth.js";
import { RULES } from "./_lib/rules.js";

export default async function handler(req, res) {
  const me = await requireAuth(req, res);
  if (!me) return;
  await ensureSchema();

  const q = (req.query.q || "").trim();

  // I miei tavoli (in SQL: `circles`), con la mia sedia (last_activity).
  const { rows: myTables } = await sql`
    SELECT c.id, c.name, c.theme, c.category, c.is_open, c.animator,
           m.last_activity, m.joined_at, m.penalty_applied,
           (SELECT COUNT(*)::int FROM memberships mm WHERE mm.circle_id = c.id) AS member_count
    FROM memberships m JOIN circles c ON c.id = m.circle_id
    WHERE m.user_id = ${me.id}
    ORDER BY m.joined_at`;

  // Chi siede ai miei tavoli.
  const tableIds = myTables.map((t) => t.id);
  const seats = tableIds.length
    ? (await sql.query(
        `SELECT m.circle_id, m.joined_at, u.id AS user_id, u.name, u.score
         FROM memberships m JOIN users u ON u.id = m.user_id
         WHERE m.circle_id = ANY($1)
         ORDER BY m.joined_at`, [tableIds])).rows
    : [];

  // Da scoprire: i tavoli dove non siedo (aperti e chiusi), con ricerca.
  // Non mi si propongono i tavoli animati da chi ho bloccato.
  const { rows: catalog } = await sql.query(
    `SELECT c.id, c.name, c.theme, c.category, c.is_open, c.animator,
            (SELECT COUNT(*)::int FROM memberships mm WHERE mm.circle_id = c.id) AS member_count
     FROM circles c
     WHERE c.id NOT IN (SELECT circle_id FROM memberships WHERE user_id = $1)
       AND c.animator NOT IN (SELECT blocked FROM blocks WHERE blocker = $1)
       AND ($2 = '' OR c.name ILIKE '%' || $2 || '%' OR c.theme ILIKE '%' || $2 || '%')
     ORDER BY c.created_at DESC LIMIT 50`, [me.id, q]);

  // Richieste d'ingresso ai tavoli che animo (non da chi ho bloccato).
  const { rows: requests } = await sql`
    SELECT r.id, r.circle_id, r.created_at, u.id AS user_id, u.name, u.score
    FROM join_requests r
    JOIN circles c ON c.id = r.circle_id
    JOIN users u ON u.id = r.user_id
    WHERE c.animator = ${me.id}
      AND r.user_id NOT IN (SELECT blocked FROM blocks WHERE blocker = ${me.id})
    ORDER BY r.created_at`;

  // Le conversazioni: i messaggi dei miei tavoli (in SQL: `posts`).
  const { rows: messages } = tableIds.length
    ? await sql.query(
        `SELECT p.id, p.author, p.circle_id, p.text, p.created_at,
                u.name AS author_name, u.score AS author_score,
                (SELECT COUNT(*)::int FROM nutre n WHERE n.post_id = p.id) AS nutre_count,
                EXISTS(SELECT 1 FROM nutre n WHERE n.post_id = p.id AND n.user_id = $2) AS nutrito_da_me
         FROM posts p JOIN users u ON u.id = p.author
         WHERE p.circle_id = ANY($1)
           AND NOT p.hidden
           AND p.author NOT IN (SELECT blocked FROM blocks WHERE blocker = $2)
           AND NOT EXISTS (SELECT 1 FROM reports r WHERE r.post_id = p.id AND r.reporter = $2)
         ORDER BY p.created_at DESC LIMIT 300`, [tableIds, me.id])
    : { rows: [] };

  // Ciò che va tolto anche dal telefono: nascosti, segnalati da me, di bloccati.
  const { rows: hiddenRows } = tableIds.length
    ? await sql.query(
        `SELECT p.id FROM posts p
         WHERE p.circle_id = ANY($1)
           AND (p.hidden
                OR p.author IN (SELECT blocked FROM blocks WHERE blocker = $2)
                OR EXISTS (SELECT 1 FROM reports r WHERE r.post_id = p.id AND r.reporter = $2))
         ORDER BY p.created_at DESC LIMIT 500`, [tableIds, me.id])
    : { rows: [] };

  const { rows: blocked } = await sql`
    SELECT u.id, u.name FROM blocks b JOIN users u ON u.id = b.blocked
    WHERE b.blocker = ${me.id} ORDER BY b.created_at`;

  res.status(200).json({
    rules: RULES,
    me,
    myTables,
    seats,
    catalog,
    requests,
    messages,
    hidden: hiddenRows.map((r) => r.id),
    blocked,
  });
}
