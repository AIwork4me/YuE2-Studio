// menu-dump.cjs — open the first song row's overflow menu and dump EVERY item
// (text + aria + position), then Escape. Read-only reconnaissance.
const { chromium } = require('playwright-core');
const sleep = (ms) => new Promise(r => setTimeout(r, ms));
const log = (...a) => console.log('[M]', ...a, new Date().toISOString().slice(11, 19));
(async () => {
  const port = process.env.CDP_PORT || 9227;
  const browser = await chromium.connectOverCDP('http://127.0.0.1:' + port);
  const page = browser.contexts()[0].pages()[0] || await browser.contexts()[0].newPage();
  await page.bringToFront(); await sleep(1200);
  const lib = page.locator('button[title="Library"], nav button:has-text("Library")').first();
  if (await lib.count()) { await lib.click({ timeout: 8000 }).catch(() => { }); await sleep(1800); }
  const cands = await page.evaluate(() => {
    const titled = [...document.querySelectorAll('div,li')].filter(e => /Small steps, bright heart|Morning light/i.test(e.innerText || '') && e.children.length > 3);
    const row = titled.sort((a, b) => b.getBoundingClientRect().width - a.getBoundingClientRect().width)[0];
    if (!row) return null;
    const btns = [...row.querySelectorAll('button')].map(b => {
      const r = b.getBoundingClientRect();
      return { x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height), t: (b.innerText || '').trim().slice(0, 12), aria: b.getAttribute('aria-label') || '', title: b.getAttribute('title') || '' };
    }).filter(b => b.w > 0 && b.h > 0);
    return { btns };
  });
  log('row buttons:', JSON.stringify(cands && cands.btns, null, 1));
  const sorted = cands.btns.slice().sort((a, b) => b.x - a.x);
  const ov = sorted.find(b => !b.t) || sorted[0];
  await page.mouse.click(ov.x + ov.w / 2, ov.y + ov.h / 2);
  await sleep(1800);
  const items = await page.evaluate(() => {
    const els = [...document.querySelectorAll('[role=menuitem], [role=menu] *, [role=dialog] button, button')];
    return els.map(el => {
      const r = el.getBoundingClientRect();
      return { t: (el.innerText || '').trim().slice(0, 40), aria: el.getAttribute('aria-label') || '', x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) };
    }).filter(e => e.w > 0 && e.h > 0 && e.t);
  });
  console.log('MENU ITEMS:', JSON.stringify(items, null, 1));
  await page.screenshot({ path: 'C:\\dev\\yue2-hip-nightly\\qa\\gui-final-run\\shots-phase2\\M-dump.png' });
  await page.keyboard.press('Escape');
  await browser.close();
})().catch(e => { console.error('FATAL', e.message); process.exit(1); });
