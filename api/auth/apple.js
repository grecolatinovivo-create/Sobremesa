// POST /api/auth/apple  { identityToken, name? }
// Verifica il token di Apple, crea/ritrova l'utente, rilascia la sessione.
import { verifyAppleIdentityToken, upsertUser, issueSession } from "../_lib/auth.js";

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "POST" });
  try {
    const { identityToken, name } = req.body || {};
    if (!identityToken) return res.status(400).json({ error: "identityToken mancante" });
    const appleSub = await verifyAppleIdentityToken(identityToken);
    const user = await upsertUser(appleSub, name);
    const token = await issueSession(user.id);
    res.status(200).json({ token, user });
  } catch (e) {
    res.status(401).json({ error: "token Apple non valido" });
  }
}
