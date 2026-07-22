// GET /api/cron/embers — la brace, valutata dal server ogni ora (cron Vercel):
// le regole valgono per tutti, anche ad app chiusa. Penalità una sola volta
// per periodo di silenzio; espulsione al 7° giorno (mai l'animatore dal
// proprio circolo); tutto sospeso nei circoli con meno di 2 membri.
import { sql, applyScore } from "../_lib/db.js";
import { requireCronSecret } from "../_lib/auth.js";
import { RULES, daysOfSilence } from "../_lib/rules.js";

export default async function handler(req, res) {
  if (!requireCronSecret(req, res)) return;

  const { rows: memberships } = await sql`
    SELECT m.user_id, m.circle_id, m.last_activity, m.penalty_applied,
           c.animator,
           (SELECT COUNT(*)::int FROM memberships mm WHERE mm.circle_id = m.circle_id) AS member_count
    FROM memberships m JOIN circles c ON c.id = m.circle_id`;

  let penalties = 0, expulsions = 0;
  for (const m of memberships) {
    if (m.member_count < RULES.emberMinimumMembers) continue;
    const days = daysOfSilence(m.last_activity);

    if (days >= RULES.emberWarningAfterDays && !m.penalty_applied) {
      await sql`UPDATE memberships SET penalty_applied = true
                WHERE user_id = ${m.user_id} AND circle_id = ${m.circle_id}`;
      await applyScore(m.user_id, m.circle_id, "silenzio", RULES.pointsSilencePenalty);
      penalties++;
    }
    if (days >= RULES.emberExpulsionAfterDays && m.animator !== m.user_id) {
      await sql`DELETE FROM memberships
                WHERE user_id = ${m.user_id} AND circle_id = ${m.circle_id}`;
      await applyScore(m.user_id, m.circle_id, "espulsione", RULES.pointsExpulsionPenalty);
      expulsions++;
    }
  }
  res.status(200).json({ ok: true, penalties, expulsions, evaluated: memberships.length });
}
