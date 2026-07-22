// Migrazione dello schema (idempotente). Protetta da CRON_SECRET:
// si lancia una volta dopo il deploy, e a ogni evoluzione dello schema.
import { sql } from "../_lib/db.js";
import { requireCronSecret } from "../_lib/auth.js";

export default async function handler(req, res) {
  if (!requireCronSecret(req, res)) return;

  await sql`CREATE EXTENSION IF NOT EXISTS pgcrypto`;
  await sql`CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apple_sub TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    score INT NOT NULL DEFAULT 50,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  )`;
  await sql`CREATE TABLE IF NOT EXISTS friendships (
    a UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    b UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (a, b),
    CHECK (a < b)
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
  await sql`CREATE TABLE IF NOT EXISTS comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    author UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
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
  await sql`CREATE INDEX IF NOT EXISTS idx_posts_circle ON posts (circle_id, created_at DESC)`;
  await sql`CREATE INDEX IF NOT EXISTS idx_posts_author ON posts (author, created_at DESC)`;
  await sql`CREATE INDEX IF NOT EXISTS idx_memberships_user ON memberships (user_id)`;

  res.status(200).json({ ok: true, migrated: true });
}
