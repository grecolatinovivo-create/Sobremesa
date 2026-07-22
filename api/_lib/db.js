// Postgres (Neon via Vercel Storage): la connessione arriva dalle env
// del progetto Vercel (POSTGRES_URL). Nessuna chiave nel repo, mai.
import { sql } from "@vercel/postgres";

export { sql };

/// Punteggio: unica via di mutazione, con clamp ed evento registrato.
import { clampScore } from "./rules.js";

export async function applyScore(userId, circleId, action, points) {
  await sql`UPDATE users SET score = LEAST(100, GREATEST(0, score + ${points})) WHERE id = ${userId}`;
  await sql`INSERT INTO events (user_id, circle_id, action, points)
            VALUES (${userId}, ${circleId}, ${action}, ${points})`;
}

/// Gli amici sono coppie non ordinate (a < b).
export function pair(u1, u2) {
  return u1 < u2 ? [u1, u2] : [u2, u1];
}

export async function friendIds(userId) {
  const { rows } = await sql`
    SELECT CASE WHEN a = ${userId} THEN b ELSE a END AS fid
    FROM friendships WHERE a = ${userId} OR b = ${userId}`;
  return rows.map((r) => r.fid);
}

export async function friendCount(userId) {
  const { rows } = await sql`
    SELECT COUNT(*)::int AS n FROM friendships WHERE a = ${userId} OR b = ${userId}`;
  return rows[0].n;
}

export async function myCircleIds(userId) {
  const { rows } = await sql`SELECT circle_id FROM memberships WHERE user_id = ${userId}`;
  return rows.map((r) => r.circle_id);
}
