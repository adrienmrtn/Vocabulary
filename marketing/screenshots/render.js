// Renders the App Store screenshots from shots.html into fastlane/screenshots,
// one folder per App Store Connect locale.
//
//   node marketing/screenshots/render.js            every language
//   node marketing/screenshots/render.js fr ja      only these
//
// Needs Playwright, and the network for the fonts loaded from Google Fonts.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const names = ['word-a-day', 'vocabulary', 'word-detail', 'games', 'widget', 'streak', 'topics'];
const source = fs.readFileSync(path.join(__dirname, 'data.js'), 'utf8');
const data = JSON.parse(source.slice(source.indexOf('{'), source.lastIndexOf('}') + 1));
const wanted = process.argv.slice(2);
const out = path.join(__dirname, '..', '..', 'fastlane', 'screenshots');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1290, height: 2796 } });
  const problems = [];
  page.on('console', (m) => { if (m.type() === 'error') problems.push(m.text()); });
  page.on('pageerror', (e) => problems.push(String(e)));
  page.on('requestfailed', (r) => problems.push('could not load ' + r.url()));
  for (const [code, entry] of Object.entries(data)) {
    if (wanted.length && !wanted.includes(code)) continue;
    await page.goto('file://' + path.join(__dirname, 'shots.html') + '?lang=' + code);
    await page.waitForSelector('body[data-ready]');
    await page.waitForLoadState('networkidle');
    for (let i = 0; i < names.length; i++) {
      const file = path.join(out, entry.locale, `0${i + 1}_${names[i]}.png`);
      await page.locator('#s' + (i + 1)).screenshot({ path: file });
    }
    console.log(code, '->', entry.locale);
  }
  await browser.close();
  if (problems.length) { console.error(problems.join('\n')); process.exit(1); }
})();
