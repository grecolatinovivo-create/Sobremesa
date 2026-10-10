// Amministrazione, protetta da CRON_SECRET (header Authorization: Bearer …).
//
//   GET  /api/admin/migrate                 → migrazione dello schema (idempotente)
//   GET  /api/admin/migrate?op=reports      → segnalazioni da rivedere
//   POST /api/admin/migrate?op=moderate     { postId, decision: "remove" | "restore" }
//                                           { userId, decision: "ban" }
//
// La moderazione vive qui (e non in un file nuovo) per restare entro il
// limite di 12 funzioni serverless del piano Hobby di Vercel.
import { sql, ensureSchema } from "../_lib/db.js";
import { requireCronSecret } from "../_lib/auth.js";

async function reports(res) {
  await ensureSchema();
  const { rows } = await sql`
    SELECT p.id AS post_id, p.text, p.hidden, p.created_at AS posted_at,
           a.id AS author_id, a.name AS author_name, c.name AS table_name,
           COUNT(r.*)::int AS reports,
           ARRAY_AGG(DISTINCT r.reason) AS reasons,
           MAX(r.created_at) AS last_report_at
    FROM reports r
    JOIN posts p ON p.id = r.post_id
    JOIN users a ON a.id = p.author
    LEFT JOIN circles c ON c.id = p.circle_id
    GROUP BY p.id, a.id, c.name
    ORDER BY MAX(r.created_at) DESC
    LIMIT 200`;
  return res.status(200).json({ reports: rows });
}

async function moderate(req, res) {
  await ensureSchema();
  const { postId, userId, decision } = req.body || {};
  if (decision === "remove" && postId) {
    await sql`DELETE FROM posts WHERE id = ${postId}`;
    return res.status(200).json({ ok: true, removed: postId });
  }
  if (decision === "restore" && postId) {
    await sql`DELETE FROM reports WHERE post_id = ${postId}`;
    await sql`UPDATE posts SET hidden = false WHERE id = ${postId}`;
    return res.status(200).json({ ok: true, restored: postId });
  }
  if (decision === "ban" && userId) {
    // Espulsione da Sobremesa: l'account e tutto ciò che ne dipende.
    await sql`DELETE FROM users WHERE id = ${userId}`;
    return res.status(200).json({ ok: true, banned: userId });
  }
  return res.status(400).json({ error: "decisione non valida" });
}

export default async function handler(req, res) {
  if (!requireCronSecret(req, res)) return;
  if (req.query.op === "reports") return reports(res);
  if (req.query.op === "moderate") {
    if (req.method !== "POST") return res.status(405).json({ error: "POST" });
    return moderate(req, res);
  }

  await sql`CREATE EXTENSION IF NOT EXISTS pgcrypto`;

  // Pivot v2 "solo tavoli" (DECISIONI #36): il grafo di amicizia personale
  // e i commenti spariscono — restano tavoli, sedie, messaggi, nutre.
  await sql`DROP TABLE IF EXISTS friend_requests`;
  await sql`DROP TABLE IF EXISTS friendships`;
  await sql`DROP TABLE IF EXISTS comments`;
  await sql`CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apple_sub TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    score INT NOT NULL DEFAULT 50,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  )`;
  await sql`CREATE TABLE IF NOT EXISTS invites (
    code TEXT PRIMARY KEY,
    inviter UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'open',
    used_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  )`;
  await sql`CREATE TABLE IF NOT EXISTS circles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    theme TEXT NOT NULL DEFAULT '',
    category TEXT NOT NULL DEFAULT 'idea',
    is_open BOOLEAN NOT NULL DEFAULT false,
    animator UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  )`;
  await sql`CREATE TABLE IF NOT EXISTS memberships (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    circle_id UUID NOT NULL REFERENCES circles(id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_activity TIMESTAMPTZ NOT NULL DEFAULT now(),
    penalty_applied BOOLEAN NOT NULL DEFAULT false,
    PRIMARY KEY (user_id, circle_id)
  )`;
  await sql`CREATE TABLE IF NOT EXISTS join_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    circle_id UUID NOT NULL REFERENCES circles(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (circle_id, user_id)
  )`;
  await sql`CREATE TABLE IF NOT EXISTS posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    circle_id UUID REFERENCES circles(id) ON DELETE CASCADE,
    category TEXT NOT NULL DEFAULT 'idea',
    text TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  )`;
  await sql`CREATE TABLE IF NOT EXISTS nutre (
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (post_id, user_id)
  )`;
  await sql`CREATE TABLE IF NOT EXISTS events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    circle_id UUID REFERENCES circles(id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    points INT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  )`;
  // v2: l'invito porta a UN tavolo preciso.
  await sql`ALTER TABLE invites ADD COLUMN IF NOT EXISTS circle_id UUID REFERENCES circles(id) ON DELETE CASCADE`;
  await sql`CREATE INDEX IF NOT EXISTS idx_posts_circle ON posts (circle_id, created_at DESC)`;
  await sql`CREATE INDEX IF NOT EXISTS idx_posts_author ON posts (author, created_at DESC)`;
  await sql`CREATE INDEX IF NOT EXISTS idx_memberships_user ON memberships (user_id)`;
  // v3: moderazione, blocchi e vincoli delle sedie nel database.
  await ensureSchema();

  res.status(200).json({ ok: true, migrated: true });
}
