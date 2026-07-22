// POST /api/circles/membership { circleId, action: "join" | "leave" | "retake" }
// join: circolo aperto → si entra; chiuso → richiesta all'animatore.
import { sql, myCircleIds, applyScore } from "../_lib/db.js";
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
  if (!circle) return res.status(404).json({ error: "circolo inesistente" });

  if (action === "join") {
    if ((await myCircleIds(me.id)).length >= RULES.maxCircles) {
      return res.status(409).json({ error: "abiti già il massimo dei circoli" });
    }
    if (!circle.is_open) {
      await sql`INSERT INTO join_requests (circle_id, user_id)
                VALUES (${circleId}, ${me.id}) ON CONFLICT DO NOTHING`;
      return res.status(200).json({ requested: true });
    }
    await sql`INSERT INTO memberships (user_id, circle_id)
              VALUES (${me.id}, ${circleId}) ON CONFLICT DO NOTHING`;
    return res.status(200).json({ joined: true });
  }

  if (action === "leave") {
    // Uscita volontaria: nessuna penalità. L'animatore non abbandona il
    // proprio circolo: lo chiude (il circolo sparisce con lui).
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
