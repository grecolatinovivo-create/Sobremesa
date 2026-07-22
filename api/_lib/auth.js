// Autenticazione: verifica server-side del token di Sign in with Apple
// (firma RS256 contro le JWKS di Apple, audience = bundle id) e sessioni
// firmate HS256 con SESSION_SECRET (env di Vercel, mai nel repo).
import { createRemoteJWKSet, jwtVerify, SignJWT } from "jose";
import { sql } from "./db.js";
import { RULES } from "./rules.js";

const APPLE_JWKS = createRemoteJWKSet(new URL("https://appleid.apple.com/auth/keys"));
const BUNDLE_ID = "app.sobremesa";
const SESSION_DAYS = 90;

function secret() {
  const s = process.env.SESSION_SECRET;
  if (!s) throw new Error("SESSION_SECRET mancante nelle env");
  return new TextEncoder().encode(s);
}

/// Verifica l'identity token di Apple e restituisce il suo `sub`.
export async function verifyAppleIdentityToken(identityToken) {
  const { payload } = await jwtVerify(identityToken, APPLE_JWKS, {
    issuer: "https://appleid.apple.com",
    audience: BUNDLE_ID,
  });
  return payload.sub;
}

/// Trova o crea l'utente per un Apple sub; il nome si aggiorna solo se fornito.
export async function upsertUser(appleSub, name) {
  const clean = (name || "").trim().slice(0, 80);
  const { rows } = await sql`
    INSERT INTO users (apple_sub, name, score)
    VALUES (${appleSub}, ${clean || "…"}, ${RULES.initialScore})
    ON CONFLICT (apple_sub)
    DO UPDATE SET name = COALESCE(NULLIF(${clean}, ''), users.name)
    RETURNING id, name, score`;
  return rows[0];
}

export async function issueSession(userId) {
  return await new SignJWT({ uid: userId })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime(`${SESSION_DAYS}d`)
    .sign(secret());
}

/// Middleware: risolve l'utente dalla sessione o risponde 401.
export async function requireAuth(req, res) {
  try {
    const header = req.headers.authorization || "";
    const token = header.startsWith("Bearer ") ? header.slice(7) : null;
    if (!token) throw new Error("no token");
    const { payload } = await jwtVerify(token, secret());
    const { rows } = await sql`SELECT id, name, score FROM users WHERE id = ${payload.uid}`;
    if (!rows.length) throw new Error("utente inesistente");
    return rows[0];
  } catch {
    res.status(401).json({ error: "non autenticato" });
    return null;
  }
}

/// Protezione del cron e delle rotte di amministrazione (CRON_SECRET env).
export function requireCronSecret(req, res) {
  const header = req.headers.authorization || "";
  if (header === `Bearer ${process.env.CRON_SECRET}`) return true;
  res.status(401).json({ error: "non autorizzato" });
  return false;
}
