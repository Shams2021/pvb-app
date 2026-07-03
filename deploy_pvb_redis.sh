#!/bin/bash
set -e
APP=/opt/bvp-app
echo "Backing up..."
cp -r "$APP/backend" "$APP/backend.backup-redis-$(date +%F-%H%M)"
cp "$APP/docker-compose.yml" "$APP/docker-compose.yml.backup-redis-$(date +%F-%H%M)"

echo "Writing backend/src/index.js..."
cat > "$APP/backend/src/index.js" << 'PVBEOF'
require('dotenv').config();
const express = require('express');
const session = require('express-session');
const { RedisStore } = require('connect-redis');
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

echo "Writing backend/package.json..."
cat > "$APP/backend/package.json" << 'PVBEOF'
{
  "name": "pvb-backend",
  "version": "1.0.0",
  "type": "commonjs",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "express-session": "^1.17.3",
    "openid-client": "^5.6.4",
    "pg": "^8.11.3",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "helmet": "^7.1.0",
    "morgan": "^1.10.0",
    "uuid": "^9.0.0",
    "docx": "^8.5.0",
    "redis": "^4.6.13",
    "connect-redis": "^7.1.1"
  }
}

PVBEOF

echo "Writing docker-compose.yml..."
cat > "$APP/docker-compose.yml" << 'PVBEOF'
services:
  postgres:
    image: postgres:16-alpine
    container_name: pvb-postgres
    restart: unless-stopped
    env_file: .env
    environment:
      POSTGRES_DB: pvbapp
      POSTGRES_USER: pvbuser
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./database/init.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - pvb-network
  redis:
    image: redis:7-alpine
    container_name: pvb-redis
    restart: unless-stopped
    volumes:
      - redis_data:/data
    networks:
      - pvb-network
  backend:
    build: ./backend
    container_name: pvb-backend
    restart: unless-stopped
    env_file: .env
    environment:
      NODE_ENV: production
      PORT: 3001
      DATABASE_URL: postgresql://pvbuser:TCR-P%40l%212437%23@postgres:5432/pvbapp
      REDIS_URL: redis://redis:6379
    depends_on:
      - postgres
      - redis
    networks:
      - pvb-network
  frontend:
    build: ./frontend
    container_name: pvb-frontend
    restart: unless-stopped
    networks:
      - pvb-network
  nginx:
    image: nginx:alpine
    container_name: pvb-nginx
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - frontend
      - backend
    networks:
      - pvb-network
volumes:
  postgres_data:
  redis_data:
networks:
  pvb-network:
    driver: bridge

PVBEOF

echo "Verifying write..."
grep -n "RedisStore" "$APP/backend/src/index.js" || echo "WAARSCHUWING: RedisStore niet gevonden!"
grep -n "redis:" "$APP/docker-compose.yml" || echo "WAARSCHUWING: redis service niet gevonden!"
echo "Klaar. Volgende stap:"
echo "cd /opt/bvp-app && docker compose up -d redis && docker compose build backend && docker compose up -d backend"
