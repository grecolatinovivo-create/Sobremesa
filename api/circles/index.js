// POST /api/circles — fonda un circolo (chi crea è l'animatore).
import { sql, myCircleIds } from "../_lib/db.js";
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
  if ((await myCircleIds(me.id)).length >= RULES.maxCircles) {
    return res.status(409).json({ error: "abiti già il massimo dei circoli" });
  }
  const cat = CATEGORIES.includes(category) ? category : "idea";
  const { rows } = await sql`
    INSERT INTO circles (name, theme, category, is_open, animator)
    VALUES (${cleanName}, ${(theme || "").trim().slice(0, 120)}, ${cat}, ${!!isOpen}, ${me.id})
    RETURNING id`;
  await sql`INSERT INTO memberships (user_id, circle_id) VALUES (${me.id}, ${rows[0].id})`;
  res.status(200).json({ id: rows[0].id });
}
