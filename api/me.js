// GET /api/me — profilo. PATCH /api/me { name } — il nome è dell'utente.
// DELETE /api/me — cancella l'account e tutto ciò che ne dipende (GDPR
// e linee guida Apple 5.1.1(v): la cancellazione si fa dall'app).
import { sql } from "./_lib/db.js";
import { requireAuth } from "./_lib/auth.js";

export default async function handler(req, res) {
  const me = await requireAuth(req, res);
  if (!me) return;

  if (req.method === "GET") return res.status(200).json({ user: me });

  if (req.method === "PATCH") {
    const clean = (((req.body || {}).name) || "").trim().slice(0, 80);
    if (!clean) return res.status(400).json({ error: "nome mancante" });
    await sql`UPDATE users SET name = ${clean} WHERE id = ${me.id}`;
    return res.status(200).json({ ok: true });
  }

  if (req.method === "DELETE") {
    // Le foreign key sono tutte ON DELETE CASCADE: amicizie, circoli animati,
    // appartenenze, post, commenti, nutre, inviti ed eventi spariscono con l'utente.
    await sql`DELETE FROM users WHERE id = ${me.id}`;
    return res.status(200).json({ ok: true, deleted: true });
  }

  res.status(405).json({ error: "GET, PATCH o DELETE" });
}
