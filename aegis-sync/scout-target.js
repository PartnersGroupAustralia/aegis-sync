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
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
    body: JSON.stringify({ url, extractorOptions: { mode: "llm", extractionSchema: { type: "object", properties: { email_selector: { type: "string" }, password_selector: { type: "string" }, submit_selector: { type: "string" } } } } })
  });
  const data = await response.json();
  console.log('[SCOUT] UI Map:', data.data?.llm_extraction);
}
scoutTarget(process.argv[2] || 'https://royalreels.com/login');
