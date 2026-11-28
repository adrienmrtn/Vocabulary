// Renders the App Store screenshots from shots.html into fastlane/screenshots.
// Run: node marketing/screenshots/render.js   (needs Playwright and the Inter font)
const { chromium } = require('playwright');
const path = require('path');

const names = ['word-a-day', 'vocabulary', 'literature', 'games', 'widget', 'streak', 'topics'];
const locales = { 'en-US': 'en', 'fr-FR': 'fr' };

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1290, height: 2796 } });
  const problems = [];
  page.on('console', (m) => { if (m.type() === 'error') problems.push(m.text()); });
  page.on('pageerror', (e) => problems.push(String(e)));
  for (const [locale, lang] of Object.entries(locales)) {
    await page.goto('file://' + path.join(__dirname, 'shots.html') + '?lang=' + lang);
    await page.waitForLoadState('networkidle');
    await page.evaluate(() => document.fonts.ready);
    for (let i = 0; i < names.length; i++) {
      const file = path.join(__dirname, '..', '..', 'fastlane', 'screenshots', locale, `0${i + 1}_${names[i]}.png`);
      await page.locator('#s' + (i + 1)).screenshot({ path: file });
    }
  }
  await browser.close();
  if (problems.length) { console.error(problems.join('\n')); process.exit(1); }
})();
