// POST /api/requests/decide { requestId, accept: bool } — solo l'animatore.
import { sql, myCircleIds } from "../_lib/db.js";
import { requireAuth } from "../_lib/auth.js";
import { RULES } from "../_lib/rules.js";

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "POST" });
  const me = await requireAuth(req, res);
  if (!me) return;

  const { requestId, accept } = req.body || {};
  const { rows } = await sql`
    SELECT r.*, c.animator FROM join_requests r
    JOIN circles c ON c.id = r.circle_id WHERE r.id = ${requestId}`;
  const request = rows[0];
  if (!request) return res.status(404).json({ error: "richiesta inesistente" });
  if (request.animator !== me.id) return res.status(403).json({ error: "non sei l'animatore" });

  if (accept) {
    // Anche chi entra abita al massimo 5 circoli.
    if ((await myCircleIds(request.user_id)).length >= RULES.maxCircles) {
      await sql`DELETE FROM join_requests WHERE id = ${requestId}`;
      return res.status(409).json({ error: "il richiedente non ha slot liberi" });
    }
    await sql`INSERT INTO memberships (user_id, circle_id)
              VALUES (${request.user_id}, ${request.circle_id}) ON CONFLICT DO NOTHING`;
  }
  await sql`DELETE FROM join_requests WHERE id = ${requestId}`;
  res.status(200).json({ ok: true, accepted: !!accept });
}
