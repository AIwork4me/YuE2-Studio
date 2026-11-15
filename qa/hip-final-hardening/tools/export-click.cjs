// export-click.cjs — attach to the running app, open the Library row's overflow
// menu, click the Download item, then watch the FilesPanel chip (studio:saving
// events surface there) and the export directory for up to 90 s. A UIA driver
// (uia-save-dialog.ps1) must already be running to answer the native dialog.
const { chromium } = require('playwright-core');
const fs = require('fs');
const path = require('path');
const sleep = (ms) => new Promise(r => setTimeout(r, ms));
const log = (...a) => console.log('[X]', ...a, new Date().toISOString().slice(11, 19));
const out = 'C:\\dev\\yue2-hip-nightly\\qa\\gui-final-run\\shots-phase2';
const exportDir = 'C:\\dev\\yue2-hip-nightly\\qa\\gui-final-run\\export';
const V = { rowTitle: null, menuItem: null, chipStates: [], newFiles: [] };
(async () => {
  const port = process.env.CDP_PORT || 9227;
  const browser = await chromium.connectOverCDP('http://127.0.0.1:' + port);
  const page = browser.contexts()[0].pages()[0] || await browser.contexts()[0].newPage();
  await page.bringToFront(); await sleep(1500);
  fs.mkdirSync(exportDir, { recursive: true });
  const before = fs.readdirSync(exportDir);

  // make sure Library view is open
  const lib = page.locator('button[title="Library"], nav button:has-text("Library")').first();
  if (await lib.count()) { await lib.click({ timeout: 8000 }).catch(() => { }); await sleep(2000); }
  await page.screenshot({ path: path.join(out, 'X1-library.png') });

  // overflow button on the first song row (proven heuristic from p2-menu.cjs)
  const cands = await page.evaluate(() => {
    const titled = [...document.querySelectorAll('div,li')].filter(e => /Small steps, bright heart|Morning light/i.test(e.innerText || '') && e.children.length > 3);
    const row = titled.sort((a, b) => b.getBoundingClientRect().width - a.getBoundingClientRect().width)[0];
    if (!row) return null;
    const btns = [...row.querySelectorAll('button')].map(b => {
      const r = b.getBoundingClientRect();
      return { x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height), t: (b.innerText || '').trim().slice(0, 12), title: b.getAttribute('title') || '' };
    }).filter(b => b.w > 0 && b.h > 0);
    return { rowText: row.innerText.slice(0, 100), btns };
  });
  V.rowTitle = cands && cands.rowText;
  log('row:', JSON.stringify(cands && cands.rowText));
  if (!cands || !cands.btns.length) { log('no row buttons'); fs.writeFileSync(path.join(out, 'export-verdict.json'), JSON.stringify(V, null, 2)); process.exit(2); }
  const sorted = cands.btns.slice().sort((a, b) => b.x - a.x);
  const ov = sorted.find(b => !b.t) || sorted[0];
  await page.keyboard.press('Escape'); await sleep(400);
  await page.mouse.click(ov.x + ov.w / 2, ov.y + (ov.h || 16) / 2);
  log('overflow clicked at', ov.x, ov.y);
  await sleep(1600);
  await page.screenshot({ path: path.join(out, 'X2-overflow.png') });

  const item = await page.evaluate(() => {
    const els = [...document.querySelectorAll('button, [role=menuitem]')];
    const el = els.find(e => /^download( audio)?$/i.test((e.innerText || '').trim()) || /^下载/.test((e.innerText || '').trim()));
    if (!el) return null;
    const r = el.getBoundingClientRect();
    return { t: el.innerText.trim(), x: r.x, y: r.y, w: r.width, h: r.height };
  });
  if (!item) { log('no Download item in menu'); V.error = 'no-download-item'; fs.writeFileSync(path.join(out, 'export-verdict.json'), JSON.stringify(V, null, 2)); process.exit(3); }
  V.menuItem = item.t;
  await page.mouse.click(item.x + item.w / 2, item.y + item.h / 2);
  log('Download clicked:', item.t);

  // watch: FilesPanel chip text + export dir (dialog answered by the UIA driver meanwhile)
  for (let i = 0; i < 45; i++) {
    await sleep(2000);
    const chip = await page.evaluate(() => {
      const t = document.body.innerText;
      const m = t.match(/(saving|downloading|saving file|exporting)[^\n]{0,60}/i);
      const done = /saved|done|complete/i.test(t) && /flac|file/i.test(t);
      return { snippet: m ? m[0] : null, hasDone: done, body: t.slice(0, 400) };
    }).catch(() => null);
    if (chip && (chip.snippet || chip.hasDone)) V.chipStates.push({ t: i * 2, s: chip.snippet, done: chip.hasDone });
    const after = fs.readdirSync(exportDir);
    V.newFiles = after.filter(f => !before.includes(f));
    if (V.newFiles.length) { log('NEW FILES:', V.newFiles); break; }
    if (i % 10 === 9) { log('waiting...', i * 2, 's chip:', JSON.stringify(chip && (chip.snippet || chip.hasDone))); await page.screenshot({ path: path.join(out, `X3-wait-${i}.png`) }).catch(() => { }); }
  }
  await sleep(1500);
  await page.screenshot({ path: path.join(out, 'X4-end-state.png') });
  fs.writeFileSync(path.join(out, 'export-verdict.json'), JSON.stringify(V, null, 2));
  log('verdict:', JSON.stringify(V));
  await browser.close();
})().catch(e => { console.error('FATAL', e.message); fs.writeFileSync(path.join(out, 'export-verdict.json'), JSON.stringify({ ...V, fatal: e.message }, null, 2)); process.exit(1); });
