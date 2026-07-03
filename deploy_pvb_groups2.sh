#!/bin/bash
set -e
BACK=/opt/bvp-app/backend
echo "Backing up..."
cp -r "$BACK" "$BACK.backup-groups2-$(date +%F-%H%M)"
echo "Writing backend/src/routes/auth.js..."
cat > "$BACK/src/routes/auth.js" << 'PVBEOF'
const express = require('express');
const { Issuer, generators } = require('openid-client');
const db = require('../db');
const router = express.Router();
let client;
async function initOIDC() {
  try {
    const issuer = await Issuer.discover(process.env.AUTHENTIK_ISSUER);
    client = new issuer.Client({
      client_id: process.env.AUTHENTIK_CLIENT_ID,
      client_secret: process.env.AUTHENTIK_CLIENT_SECRET,
      redirect_uris: [process.env.APP_URL + '/api/auth/callback'],
      post_logout_redirect_uris: [process.env.APP_URL],
      response_types: ['code'],
    });
    console.log('OIDC client aangemaakt');
  } catch (err) {
    console.error('OIDC init fout:', err);
    setTimeout(initOIDC, 5000);
  }
}
initOIDC();
router.get('/login', (req, res) => {
  if (!client) return res.status(503).json({ error: 'Auth niet beschikbaar' });
  const codeVerifier = generators.codeVerifier();
  const codeChallenge = generators.codeChallenge(codeVerifier);
  const state = generators.state();
  req.session.codeVerifier = codeVerifier;
  req.session.state = state;
  req.session.save((err) => {
    if (err) console.error('Session save fout:', err);
    const authUrl = client.authorizationUrl({
      scope: 'openid email profile groups',
      code_challenge: codeChallenge,
      code_challenge_method: 'S256',
      state,
    });
    res.redirect(authUrl);
  });
});
router.get('/callback', async (req, res) => {
  try {
    const params = client.callbackParams(req);
    const tokenSet = await client.callback(
      process.env.APP_URL + '/api/auth/callback',
      params,
      {
        code_verifier: req.session.codeVerifier,
        state: req.session.state,
      }
    );
    const userinfo = await client.userinfo(tokenSet.access_token);
    console.log('USERINFO:', JSON.stringify(userinfo));
    // Rol wordt bepaald door Authentik-groepslidmaatschap ('PVB Docenten'),
    // niet meer handmatig in de database gezet. Zo blijft het altijd kloppen.
    const DOCENT_GROEP = process.env.AUTHENTIK_DOCENT_GROEP || 'PVB Docenten';
    const groepen = userinfo.groups || [];
    const rol = groepen.includes(DOCENT_GROEP) ? 'docent' : 'student';
    console.log('Afgeleide rol:', rol, '| groepen:', groepen);

    let result = await db.query(
      'SELECT * FROM users WHERE authentik_id = $1',
      [userinfo.sub]
    );
    let user;
    if (result.rows.length === 0) {
      const insertResult = await db.query(
        'INSERT INTO users (authentik_id, email, naam, rol) VALUES ($1, $2, $3, $4) RETURNING *',
        [userinfo.sub, userinfo.email, userinfo.name || userinfo.preferred_username || userinfo.email, rol]
      );
      user = insertResult.rows[0];
    } else {
      const updateResult = await db.query(
        'UPDATE users SET email = $1, naam = $2, rol = $3, updated_at = NOW() WHERE authentik_id = $4 RETURNING *',
        [userinfo.email, userinfo.name || userinfo.preferred_username || userinfo.email, rol, userinfo.sub]
      );
      user = updateResult.rows[0];
    }
    req.session.user = {
      id: user.id,
      email: user.email,
      naam: user.naam,
      rol: user.rol,
    };
    req.session.save((err) => {
      if (err) {
        console.error('Session save fout:', err);
        return res.redirect(process.env.APP_URL + '/?error=session_failed');
      }
      // Docenten gaan naar het docent-overzicht, studenten naar hun eigen dashboard.
      const bestemming = user.rol === 'docent' ? '/docent' : '/dashboard';
      res.redirect(process.env.APP_URL + bestemming);
    });
  } catch (err) {
    console.error('Callback fout:', err);
    res.redirect(process.env.APP_URL + '/?error=auth_failed');
  }
});
router.get('/me', (req, res) => {
  if (!req.session || !req.session.user) {
    return res.status(401).json({ error: 'Niet ingelogd' });
  }
  res.json(req.session.user);
});
router.get('/logout', (req, res) => {
  req.session.destroy();
  if (client) {
    const logoutUrl = client.endSessionUrl({
      post_logout_redirect_uri: process.env.APP_URL,
    });
    res.redirect(logoutUrl);
  } else {
    res.redirect(process.env.APP_URL);
  }
});
router.post('/backchannel-logout', (req, res) => {
  res.status(200).send('OK');
});
module.exports = router;

PVBEOF
echo "Verifying write..."
grep -n "DOCENT_GROEP" "$BACK/src/routes/auth.js" || echo "WAARSCHUWING: DOCENT_GROEP niet gevonden na schrijven!"
echo "Klaar. Volgende stap:"
echo "cd /opt/bvp-app && docker compose build backend && docker compose up -d backend"
