#!/bin/bash
set -e
APP=/opt/bvp-app
echo "Writing backend/src/index.js (fix connect-redis import)..."
cat > "$APP/backend/src/index.js" << 'PVBEOF'
require('dotenv').config();
const express = require('express');
const session = require('express-session');
const RedisStore = require('connect-redis').default;
const { createClient } = require('redis');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const authRoutes = require('./routes/auth');
const opdrachtenRoutes = require('./routes/opdrachten');
const formulierenRoutes = require('./routes/formulieren');
const gebruikersRoutes = require('./routes/gebruikers');

const app = express();

app.set('trust proxy', 1);

app.use(helmet({ contentSecurityPolicy: false }));
app.use(morgan('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use(cors({
  origin: process.env.APP_URL,
  credentials: true,
}));

// Redis als sessie-store i.p.v. de standaard Express MemoryStore. MemoryStore
// lekt geheugen en verliest alle sessies bij een herstart — niet geschikt
// voor productie (zie documentatie v2.0, Open Punten #1).
const redisClient = createClient({ url: process.env.REDIS_URL || 'redis://redis:6379' });
redisClient.on('error', (err) => console.error('Redis fout:', err));
redisClient.connect()
  .then(() => console.log('Verbonden met Redis'))
  .catch((err) => console.error('Redis connectie mislukt:', err));

app.use(session({
  store: new RedisStore({ client: redisClient, prefix: 'pvb-sess:' }),
  secret: process.env.SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: false,
    httpOnly: true,
    maxAge: 8 * 60 * 60 * 1000,
    sameSite: 'lax',
  },
}));

app.use('/api/auth', authRoutes);
app.use('/api/opdrachten', opdrachtenRoutes);
app.use('/api/formulieren', formulierenRoutes);
app.use('/api/gebruikers', gebruikersRoutes);
const exportRoutes = require('./routes/export');
app.use('/api/formulieren', exportRoutes);

app.get('/api/health', (req, res) => res.json({ status: 'ok', timestamp: new Date().toISOString() }));

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log('Backend draait op poort ' + PORT));

PVBEOF
grep -n "connect-redis" "$APP/backend/src/index.js"
echo "Klaar. Volgende stap:"
echo "cd /opt/bvp-app && docker compose build backend && docker compose up -d backend"
