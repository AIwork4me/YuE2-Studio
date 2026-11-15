// export-launch.cjs — fresh detached app instance on CDP port 9228, wait for
// the service (not necessarily the engine: export works from the library even
// when the engine cannot start), leave the app running.
const { chromium } = require('playwright-core');
const { spawn } = require('child_process');
const sleep = (ms) => new Promise(r => setTimeout(r, ms));
const log = (...a) => console.log('[L]', ...a, new Date().toISOString().slice(11, 19));
(async () => {
  const env = { ...process.env, WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS: '--remote-debugging-port=9228' };
  delete env.HIP_PATH; delete env.ROCM_PATH; delete env.HIP_DEVICE_LIB_PATH;
  env.YUE_STUDIO_DATA_ROOT = 'C:\\dev\\yue2-hip-nightly\\qa\\gui-final-run\\dataroot';
  const app = spawn('C:\\dev\\yue2-hip-nightly\\qa\\gui-final-run\\app\\YuE2-Studio.exe', [], { env, detached: true, stdio: 'ignore' });
  app.unref();
  log('app spawned');
  let browser = null;
  for (let i = 0; i < 90 && !browser; i++) { await sleep(1000); try { browser = await chromium.connectOverCDP('http://127.0.0.1:9228'); } catch (e) { } }
  if (!browser) { log('no CDP after 90 s'); process.exit(2); }
  const page = browser.contexts()[0].pages()[0] || await browser.contexts()[0].newPage();
  await page.bringToFront();
  let ok = false;
  for (let i = 0; i < 60 && !ok; i++) {
    await sleep(2000);
    try { const t = await page.evaluate(() => document.body.innerText.slice(0, 800)); if (/library|songs|create|生成|歌曲/i.test(t)) ok = true; } catch (e) { }
  }
  log('ui ready:', ok);
  const text = await page.evaluate(() => document.body.innerText.slice(0, 1500)).catch(() => '');
  log('UI TEXT:', text.replace(/\n/g, ' | ').slice(0, 400));
  await browser.close();
})().catch(e => { console.error('FATAL', e.message); process.exit(1); });
