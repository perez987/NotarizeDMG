const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const htmlPath = path.resolve(
    process.argv[2] || 'AppIcon1.html'
  );

  const browser = await chromium.launch();

  // ── 2× render → 2048×2048 (Retina / @2x) ──────────────────────────────
  const ctx2x = await browser.newContext({
    viewport: { width: 1024, height: 1024 },
    deviceScaleFactor: 2
  });
  const page2x = await ctx2x.newPage();
  await page2x.goto('file://' + htmlPath);
  await page2x.waitForLoadState('networkidle');   // wait for Google Fonts
  await page2x.locator('.tile').screenshot({
    path: 'AppIcon1@2x.png',
    type: 'png',
    omitBackground: true
  });
  await ctx2x.close();
  console.log('Wrote AppIcon1@2x.png  (2048 × 2048 px)');

  // ── 1× render → 1024×1024 ──────────────────────────────────────────────
  const ctx1x = await browser.newContext({
    viewport: { width: 1024, height: 1024 },
    deviceScaleFactor: 1
  });
  const page1x = await ctx1x.newPage();
  await page1x.goto('file://' + htmlPath);
  await page1x.waitForLoadState('networkidle');
  await page1x.locator('.tile').screenshot({
    path: 'AppIcon1.png',
    type: 'png',
    omitBackground: true
  });
  await ctx1x.close();
  console.log('Wrote AppIcon1.png      (1024 × 1024 px)');

  await browser.close();
})();