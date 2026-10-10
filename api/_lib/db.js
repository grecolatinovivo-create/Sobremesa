// Postgres (Neon via Vercel Storage): la connessione arriva dalle env
// del progetto Vercel (POSTGRES_URL). Nessuna chiave nel repo, mai.
import { sql } from "@vercel/postgres";
import { RULES } from "./rules.js";

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

// ---------------------------------------------------------------------------
// v3 — schema evolutivo, applicato da solo al primo uso di ogni istanza.
//
// Un solo statement (DO …) sotto un lock transazionale: due istanze che
// partono insieme non si pestano i piedi, e non serve ricordarsi di lanciare
// la migrazione dopo il deploy. Tutto idempotente, e senza lock pesanti
// quando lo schema è già a posto (si controlla prima di alterare).
//
//  • posts.hidden — un intervento nascosto dalla moderazione;
//  • reports      — le segnalazioni (una per persona e per intervento);
//  • blocks       — chi ho bloccato (non ne vedo più gli interventi);
//  • il TRIGGER delle sedie: è il database, non il client e nemmeno la
//    singola API, a garantire 12 sedie per tavolo e 5 tavoli a persona,
//    anche con due ingressi nello stesso millisecondo (lock sulla riga del
//    tavolo e poi su quella della persona, sempre in quest'ordine).
//    Se cambiano i numeri in rules.js: DROP TRIGGER memberships_guard e
//    la prossima istanza lo ricrea con i valori nuovi.
// ---------------------------------------------------------------------------
let schemaReady = null;

export function ensureSchema() {
  if (!schemaReady) {
    schemaReady = sql.query(`
DO $do$
BEGIN
  PERFORM pg_advisory_xact_lock(7311003);

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name = 'posts' AND column_name = 'hidden') THEN
    ALTER TABLE posts ADD COLUMN hidden BOOLEAN NOT NULL DEFAULT false;
  END IF;

  CREATE TABLE IF NOT EXISTS reports (
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    reporter UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason TEXT NOT NULL DEFAULT 'altro',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (post_id, reporter)
  );

  CREATE TABLE IF NOT EXISTS blocks (
    blocker UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blocked UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (blocker, blocked)
  );

  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'sobremesa_guard_seat') THEN
    CREATE FUNCTION sobremesa_guard_seat() RETURNS trigger AS $f$
    DECLARE
      max_seats INT := TG_ARGV[0]::int;
      max_tables INT := TG_ARGV[1]::int;
    BEGIN
      PERFORM 1 FROM circles WHERE id = NEW.circle_id FOR UPDATE;
      IF EXISTS (SELECT 1 FROM memberships
                 WHERE user_id = NEW.user_id AND circle_id = NEW.circle_id) THEN
        RETURN NULL; -- già seduto: nessun doppione, nessun errore
      END IF;
      IF (SELECT COUNT(*) FROM memberships WHERE circle_id = NEW.circle_id) >= max_seats THEN
        RAISE EXCEPTION 'tavolo_completo' USING ERRCODE = 'P0001';
      END IF;
      PERFORM 1 FROM users WHERE id = NEW.user_id FOR UPDATE;
      IF (SELECT COUNT(*) FROM memberships WHERE user_id = NEW.user_id) >= max_tables THEN
        RAISE EXCEPTION 'troppi_tavoli' USING ERRCODE = 'P0001';
      END IF;
      RETURN NEW;
    END
    $f$ LANGUAGE plpgsql;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'memberships_guard') THEN
    CREATE TRIGGER memberships_guard BEFORE INSERT ON memberships
      FOR EACH ROW EXECUTE FUNCTION sobremesa_guard_seat('${RULES.maxFriends}', '${RULES.maxCircles}');
  END IF;
END
$do$;`).catch((error) => {
      schemaReady = null; // si riproverà alla prossima richiesta
      throw error;
    });
  }
  return schemaReady;
}

/// Siede una persona a un tavolo, con i vincoli garantiti dal database.
/// Risponde { ok: true } oppure { status, error } già pronto per l'API.
export async function seat(userId, tableId) {
  await ensureSchema();
  try {
    await sql`INSERT INTO memberships (user_id, circle_id) VALUES (${userId}, ${tableId})`;
    return { ok: true };
  } catch (error) {
    const message = String(error && error.message);
    if (message.includes("tavolo_completo")) return { status: 409, error: "il tavolo è al completo" };
    if (message.includes("troppi_tavoli")) return { status: 409, error: "siedi già al massimo dei tavoli" };
    throw error;
  }
}
