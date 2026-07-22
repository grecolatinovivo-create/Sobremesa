// GET /api/sync — l'intero mondo dell'utente in una chiamata:
// profilo, tavola, circoli (abitati + catalogo), richieste, feed.
// Il client lo riversa in SwiftData e la UI resta reattiva com'era.
import { sql, friendIds } from "./_lib/db.js";
import { requireAuth } from "./_lib/auth.js";
import { RULES } from "./_lib/rules.js";

export default async function handler(req, res) {
  const me = await requireAuth(req, res);
  if (!me) return;

  const fids = await friendIds(me.id);
  const q = (req.query.q || "").trim();

  const friends = fids.length
    ? (await sql.query(
        `SELECT id, name, score FROM users WHERE id = ANY($1)`, [fids])).rows
    : [];

  // I miei circoli (con conteggio membri e la mia membership).
  const { rows: myCircles } = await sql`
    SELECT c.id, c.name, c.theme, c.category, c.is_open, c.animator,
           m.last_activity, m.joined_at,
           (SELECT COUNT(*)::int FROM memberships mm WHERE mm.circle_id = c.id) AS member_count
    FROM memberships m JOIN circles c ON c.id = m.circle_id
    WHERE m.user_id = ${me.id}
    ORDER BY m.joined_at`;

  // Catalogo: circoli aperti che non abito (con eventuale ricerca).
  const { rows: catalog } = await sql.query(
    `SELECT c.id, c.name, c.theme, c.category, c.is_open, c.animator,
            (SELECT COUNT(*)::int FROM memberships mm WHERE mm.circle_id = c.id) AS member_count
     FROM circles c
     WHERE c.is_open = true
       AND c.id NOT IN (SELECT circle_id FROM memberships WHERE user_id = $1)
       AND ($2 = '' OR c.name ILIKE '%' || $2 || '%' OR c.theme ILIKE '%' || $2 || '%')
     ORDER BY c.created_at DESC LIMIT 50`, [me.id, q]);

  // Richieste d'ingresso nei circoli che animo.
  const { rows: requests } = await sql`
    SELECT r.id, r.circle_id, r.created_at, u.id AS user_id, u.name, u.score
    FROM join_requests r
    JOIN circles c ON c.id = r.circle_id
    JOIN users u ON u.id = r.user_id
    WHERE c.animator = ${me.id}
    ORDER BY r.created_at`;

  // Inviti alla tavola in sospeso (tavola piena al momento del riscatto).
  const { rows: pendingInvites } = await sql`
    SELECT i.code, u.id AS user_id, u.name, u.score
    FROM invites i JOIN users u ON u.id = i.used_by
    WHERE i.inviter = ${me.id} AND i.status = 'pending_seat'
    ORDER BY i.created_at`;

  // Feed: post degli amici alla tavola + post dei circoli abitati.
  const circleIds = myCircles.map((c) => c.id);
  const authorIds = [...fids, me.id];
  const { rows: posts } = await sql.query(
    `SELECT p.id, p.author, p.circle_id, p.category, p.text, p.created_at,
            u.name AS author_name, u.score AS author_score,
            (SELECT COUNT(*)::int FROM nutre n WHERE n.post_id = p.id) AS nutre_count,
            EXISTS(SELECT 1 FROM nutre n WHERE n.post_id = p.id AND n.user_id = $3) AS nutrito_da_me
     FROM posts p JOIN users u ON u.id = p.author
     WHERE (p.circle_id IS NULL AND p.author = ANY($1))
        OR (p.circle_id = ANY($2))
     ORDER BY p.created_at DESC LIMIT 100`,
    [authorIds, circleIds.length ? circleIds : ["00000000-0000-0000-0000-000000000000"], me.id]);

  const postIds = posts.map((p) => p.id);
  const comments = postIds.length
    ? (await sql.query(
        `SELECT c.id, c.post_id, c.text, c.created_at, u.id AS author_id, u.name AS author_name
         FROM comments c JOIN users u ON u.id = c.author
         WHERE c.post_id = ANY($1) ORDER BY c.created_at`, [postIds])).rows
    : [];

  res.status(200).json({
    rules: RULES,
    me,
    friends,
    pendingInvites,
    myCircles,
    catalog,
    requests,
    posts,
    comments,
  });
}
