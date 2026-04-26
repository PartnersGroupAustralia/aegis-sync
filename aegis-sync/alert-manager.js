import fetch from 'node-fetch';
import dotenv from 'dotenv';

dotenv.config();

export async function sendAlert(message) {
  const { TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID } = process.env;
  if (!TELEGRAM_BOT_TOKEN || !TELEGRAM_CHAT_ID) return;

  const url = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`;
  try {
    await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: TELEGRAM_CHAT_ID,
        text: `🛡️ [AEGIS-SYNC ALERT]\n\n${message}`,
        parse_mode: 'Markdown'
      })
    });
  } catch (e) {
    console.error('[ALERTER] Fault:', e.message);
  }
}
