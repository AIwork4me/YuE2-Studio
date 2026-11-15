// export-trace.cjs — instrument the live page: hook window.fetch and the
// studio:saving CustomEvent, click Download on the first song row, then report
// every captured request/response and saving event. Leaves nothing modified.
const { chromium } = require('playwright-core');
const sleep = (ms) => new Promise(r => setTimeout(r, ms));
const log = (...a) => console.log('[T]', ...a, new Date().toISOString().slice(11, 19));
(async () => {
  const port = process.env.CDP_PORT || 9227;
  const browser = await chromium.connectOverCDP('http://127.0.0.1:' + port);
  const page = browser.contexts()[0].pages()[0] || await browser.contexts()[0].newPage();
  await page.bringToFront(); await sleep(1200);

  await page.evaluate(() => {
    window.__trace = { fetches: [], saving: [], errors: [] };
    const of = window.fetch;
    window.fetch = async function (...args) {
      const url = String(args[0] && args[0].url || args[0]);
      const method = (args[1] && args[1].method) || (args[0] && args[0].method) || 'GET';
      const entry = { method, url: url.slice(0, 160), status: null, body: null };
      window.__trace.fetches.push(entry);
      try {
        const res = await of.apply(this, args);
        entry.status = res.status;
        if (!res.ok) { try { entry.body = (await res.text()).slice(0, 200); } catch (e) { } }
        return res;
      } catch (e) { entry.status = 'throw'; entry.body = String(e).slice(0, 160); throw e; }
    };
    window.addEventListener('studio:saving', e => window.__trace.saving.push(JSON.stringify(e.detail).slice(0, 200)));
    window.addEventListener('error', e => window.__trace.errors.push(String(e.message).slice(0, 160)));
    const oe = window.onerror; window.onerror = function (...a) { window.__trace.errors.push(String(a[0]).slice(0, 160)); return oe && oe.apply(this, a); };
    return Object.keys(window.__trace);
  });
  log('hooks installed');

  // open Library if needed, then the first row's overflow menu -> Download
  const lib = page.locator('button[title="Library"], nav button:has-text("Library")').first();
  if (await lib.count()) { await lib.click({ timeout: 8000 }).catch(() => { }); await sleep(1800); }
  const cands = await page.evaluate(() => {
    const titled = [...document.querySelectorAll('div,li')].filter(e => /Small steps, bright heart|Morning light/i.test(e.innerText || '') && e.children.length > 3);
    const row = titled.sort((a, b) => b.getBoundingClientRect().width - a.getBoundingClientRect().width)[0];
    if (!row) return null;
    const btns = [...row.querySelectorAll('button')].map(b => {
      const r = b.getBoundingClientRect();
      return { x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height), t: (b.innerText || '').trim().slice(0, 12) };
    }).filter(b => b.w > 0 && b.h > 0);
    return { btns };
  });
  if (!cands) { log('no row'); process.exit(2); }
  const sorted = cands.btns.slice().sort((a, b) => b.x - a.x);
  const ov = sorted.find(b => !b.t) || sorted[0];
  await page.mouse.click(ov.x + ov.w / 2, ov.y + ov.h / 2);
  await sleep(1500);
  const item = await page.evaluate(() => {
    const els = [...document.querySelectorAll('button, [role=menuitem]')];
    const el = els.find(e => /^download( audio)?$/i.test((e.innerText || '').trim()));
    if (!el) return null;
    const r = el.getBoundingClientRect();
    return { x: r.x, y: r.y, w: r.width, h: r.height };
  });
  if (!item) { log('no Download item'); process.exit(3); }
  await page.mouse.click(item.x + item.w / 2, item.y + item.h / 2);
  log('Download clicked; observing 25 s (dialog NOT answered this run)');
  for (let i = 0; i < 25; i++) {
    await sleep(1000);
    const t = await page.evaluate(() => JSON.stringify(window.__trace));
    const tr = JSON.parse(t);
    if (tr.saving.length || tr.fetches.some(f => /files\/save/.test(f.url) && f.status)) { log('progress @' + i + 's:', t.slice(0, 600)); break; }
    if (i % 8 === 7) log('...' + i + 's', t.slice(0, 300));
  }
  const final = await page.evaluate(() => ({ ...window.__trace, desktop: Boolean(window.__TAURI__), ua: navigator.userAgent.slice(0, 80) }));
  console.log('FINAL TRACE:', JSON.stringify(final, null, 2));
  await page.screenshot({ path: 'C:\\dev\\yue2-hip-nightly\\qa\\gui-final-run\\shots-phase2\\T1-after.png' });
  await browser.close();
})().catch(e => { console.error('FATAL', e.message); process.exit(1); });
