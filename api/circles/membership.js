// POST /api/circles/membership { circleId, action: "join" | "leave" | "retake" }
// join: tavolo aperto → ci si siede; chiuso → richiesta all'animatore.
// I vincoli (12 sedie, 5 tavoli) li garantisce il database (v. seat()).
import { sql, myTableIds, seatCount, applyScore, seat, ensureSchema } from "../_lib/db.js";
import { requireAuth } from "../_lib/auth.js";
import { RULES } from "../_lib/rules.js";

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "POST" });
  const me = await requireAuth(req, res);
  if (!me) return;

  const { circleId, action } = req.body || {};
  if (!circleId || !action) return res.status(400).json({ error: "parametri mancanti" });
  const { rows: circles } = await sql`SELECT * FROM circles WHERE id = ${circleId}`;
  const circle = circles[0];
  if (!circle) return res.status(404).json({ error: "tavolo inesistente" });

  if (action === "join") {
    const { rows: already } = await sql`
      SELECT 1 FROM memberships WHERE user_id = ${me.id} AND circle_id = ${circleId}`;
    if (already.length) return res.status(200).json({ joined: true });
    // Controlli rapidi per un messaggio chiaro; la garanzia vera è in seat().
    if ((await myTableIds(me.id)).length >= RULES.maxCircles) {
      return res.status(409).json({ error: "siedi già al massimo dei tavoli" });
    }
    if ((await seatCount(circleId)) >= RULES.maxFriends) {
      return res.status(409).json({ error: "il tavolo è al completo" });
    }
    if (!circle.is_open) {
      // Chi l'animatore ha bloccato non può bussare al suo tavolo.
      await ensureSchema();
      const { rows: blocked } = await sql`
        SELECT 1 FROM blocks WHERE blocker = ${circle.animator} AND blocked = ${me.id}`;
      if (blocked.length) return res.status(200).json({ requested: true });
      await sql`INSERT INTO join_requests (circle_id, user_id)
                VALUES (${circleId}, ${me.id}) ON CONFLICT DO NOTHING`;
      return res.status(200).json({ requested: true });
    }
    const result = await seat(me.id, circleId);
    if (!result.ok) return res.status(result.status).json({ error: result.error });
    return res.status(200).json({ joined: true });
  }

  if (action === "leave") {
    // Uscita volontaria: nessuna penalità. L'animatore non abbandona il
    // proprio tavolo: lo chiude (il tavolo sparisce con lui).
    if (circle.animator === me.id) {
      await sql`DELETE FROM circles WHERE id = ${circleId}`;
      return res.status(200).json({ closed: true });
    }
    await sql`DELETE FROM memberships WHERE user_id = ${me.id} AND circle_id = ${circleId}`;
    return res.status(200).json({ left: true });
  }

  if (action === "retake") {
    const { rowCount } = await sql`
      UPDATE memberships SET last_activity = now(), penalty_applied = false
      WHERE user_id = ${me.id} AND circle_id = ${circleId}`;
    if (rowCount) await applyScore(me.id, circleId, "ripresaParola", RULES.pointsRetake);
    return res.status(200).json({ ok: true });
  }

  res.status(400).json({ error: "azione sconosciuta" });
}
