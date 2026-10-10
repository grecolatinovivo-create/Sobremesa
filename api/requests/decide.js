// POST /api/requests/decide { requestId, accept: bool } — solo l'animatore.
import { sql, seat } from "../_lib/db.js";
import { requireAuth } from "../_lib/auth.js";

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

  // La richiesta, comunque vada, è decisa: non resta appesa.
  await sql`DELETE FROM join_requests WHERE id = ${requestId}`;
  if (accept) {
    // Anche chi entra siede al massimo a 5 tavoli, e il tavolo ha 12 sedie:
    // lo garantisce il database (v. seat()).
    const result = await seat(request.user_id, request.circle_id);
    if (!result.ok) return res.status(result.status).json({ error: result.error });
  }
  res.status(200).json({ ok: true, accepted: !!accept });
}
