// Postgres (Neon via Vercel Storage): la connessione arriva dalle env
// del progetto Vercel (POSTGRES_URL). Nessuna chiave nel repo, mai.
import { sql } from "@vercel/postgres";

export { sql };

/// Punteggio: unica via di mutazione, con clamp ed evento registrato.
export async function applyScore(userId, tableId, action, points) {
  await sql`UPDATE users SET score = LEAST(100, GREATEST(0, score + ${points})) WHERE id = ${userId}`;
  await sql`INSERT INTO events (user_id, circle_id, action, points)
            VALUES (${userId}, ${tableId}, ${action}, ${points})`;
}

/// I tavoli a cui l'utente siede (in SQL la tabella si chiama ancora `circles`).
export async function myTableIds(userId) {
  const { rows } = await sql`SELECT circle_id FROM memberships WHERE user_id = ${userId}`;
  return rows.map((r) => r.circle_id);
}

/// Quante sedie sono occupate a un tavolo.
export async function seatCount(tableId) {
  const { rows } = await sql`
    SELECT COUNT(*)::int AS n FROM memberships WHERE circle_id = ${tableId}`;
  return rows[0].n;
}
