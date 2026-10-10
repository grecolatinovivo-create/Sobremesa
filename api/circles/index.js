// POST /api/circles — fonda un tavolo (chi lo fonda è l'animatore e ci siede).
import { sql, myTableIds, seat } from "../_lib/db.js";
import { requireAuth } from "../_lib/auth.js";
import { RULES } from "../_lib/rules.js";

const CATEGORIES = ["libro", "film", "musica", "arte", "teatro", "idea"];

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "POST" });
  const me = await requireAuth(req, res);
  if (!me) return;

  const { name, theme = "", category = "idea", isOpen = true } = req.body || {};
  const cleanName = (name || "").trim().slice(0, 60);
  if (!cleanName) return res.status(400).json({ error: "nome mancante" });
  if ((await myTableIds(me.id)).length >= RULES.maxCircles) {
    return res.status(409).json({ error: "siedi già al massimo dei tavoli" });
  }
  const cat = CATEGORIES.includes(category) ? category : "idea";
  const { rows } = await sql`
    INSERT INTO circles (name, theme, category, is_open, animator)
    VALUES (${cleanName}, ${(theme || "").trim().slice(0, 120)}, ${cat}, ${!!isOpen}, ${me.id})
    RETURNING id`;
  const result = await seat(me.id, rows[0].id);
  if (!result.ok) {
    // Un tavolo senza il suo animatore non deve esistere.
    await sql`DELETE FROM circles WHERE id = ${rows[0].id}`;
    return res.status(result.status).json({ error: result.error });
  }
  res.status(200).json({ id: rows[0].id });
}
