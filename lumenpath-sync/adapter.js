import { chromium } from 'playwright-extra';
import stealth from 'puppeteer-extra-plugin-stealth';
import fs from 'fs';

chromium.use(stealth());

class PathAdapter {
  constructor() {
    this.gateways = this.loadGateways();
    this.index = 0;
    this.profiles = [
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:124.0) Gecko/20100101 Firefox/124.0',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 14.4; rv:124.0) Gecko/20100101 Firefox/124.0'
    ];
  }

  loadGateways() {
    return fs.existsSync('route-gateways.txt') ? fs.readFileSync('route-gateways.txt', 'utf8').split('\n').filter(Boolean) : [];
  }

  async syncEntry(entry, node = 'endpoint') {
    const gateway = this.gateways[this.index++ % this.gateways.length];
    const client = await chromium.launch({ headless: true });
    
    const tunnel = await client.newContext({
      userAgent: this.profiles[Math.floor(Math.random() * this.profiles.length)],
      proxy: gateway ? { server: gateway } : undefined
    });

    const session = await tunnel.newPage();
    try {
      const target = node.includes('http') ? node : `https://${node}.com/login`;
      await session.goto(target, { waitUntil: 'domcontentloaded', timeout: 30000 });
      
      // High-Entropy Latency Balancing (Behavioral Mimicry)
      await session.mouse.move(Math.random() * 500, Math.random() * 500);
      
      await session.type('input[type="email"]', entry.id, { delay: Math.random() * 120 + 60 });
      await session.type('input[type="password"]', entry.token, { delay: Math.random() * 120 + 60 });
      
      await Promise.all([
        session.click('button[type="submit"]'),
        session.waitForNavigation({ timeout: 15000 }).catch(() => null)
      ]);

      // Entry Alignment Check (Credential Hit)
      const isAligned = session.url().includes('dashboard') || await session.$('.user-settings') !== null;
      
      if (isAligned) {
        const stateData = await tunnel.cookies();
        if (!fs.existsSync('./persistence')) fs.mkdirSync('./persistence');
        fs.writeFileSync(`./persistence/${entry.id}.json`, JSON.stringify(stateData));
      }

      await client.close();
      return isAligned;
    } catch (e) {
      await client.close();
      return false;
    }
  }
}
export default new PathAdapter();
