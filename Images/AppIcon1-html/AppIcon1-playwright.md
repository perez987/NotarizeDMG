# Rendering AppIcon1.html as a High-Quality PNG with Playwright

## Why Playwright instead of a screen capture?

`AppIcon1.html` defines a 1024 × 1024 px icon with:

- `border-radius: 232px` outer tile and `44px` card corners
- Multi-stop CSS `box-shadow` for glass highlights and inner shades
- A `drop-shadow` filter on the gradient "DMG" text
- A `text-shadow` white line under the gradient fill
- A green badge with a precise `0 0 0 10px` white ring

A plain macOS screen-grab at 1× resolution renders everything on a 1 px grid, producing:

| Issue | Cause |
|---|---|
| Staircase aliasing on rounded corners | 1 px integer steps |
| Soft glows look flat / hard-edged | Box-shadow blurs quantised |
| Font rendering depends on display DPI | Not deterministic |
| White ring on badge loses smoothness | 1 px precision |

Playwright solves all of this with `deviceScaleFactor: 2`, which instructs the headless Chromium engine to render at **2048 × 2048 physical pixels** (full sub-pixel precision) and save that as a lossless RGBA PNG — identical to a Retina / @2x capture but fully scripted and repeatable.

## Prerequisites — macOS with Node.js

Playwright's Node.js package is the easiest path on macOS because it bundles its own Chromium binary.

### 1. Install Node.js (via Homebrew)

```bash
brew install node
```

Verify:

```bash
node --version   # ≥ 18 recommended
npm --version
```

> **Python note:** Python is not required for Playwright itself. Node.js is the only runtime needed. 

### 2. Create a working folder and install Playwright

```bash
mkdir ~/render-icon && cd ~/render-icon
npm init -y
npm install playwright
```

Copy the base html file (`AppIcon1.html`) inside this folder.

### 3. Install the Chromium browser binary

```bash
npx playwright install chromium
```

This downloads a pinned Chromium build (~130 MB) to `~/.cache/ms-playwright/`. It is self-contained and does not affect your system Chrome.

## The render script

Create `render_icon.js` inside `~/render-icon/`:

```js
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
```

### Run it

```bash
# Pass the path to your AppIcon1.html file:
node render_icon.js AppIcon1.html
```

Output files appear in `~/render-icon/`:

| File | Size | Use |
|---|---|---|
| `AppIcon1.png` | 1024 × 1024 | Direct Xcode 1× asset |
| `AppIcon1@2x.png` | 2048 × 2048 | Xcode @2x / macOS App Store icon |

---

## What each option controls

| Playwright option | Value | Effect |
|---|---|---|
| `viewport` | 1024 × 1024 | Layout pixel canvas matches the HTML exactly |
| `deviceScaleFactor` | 2 | Physical pixels = 2048 × 2048; sub-pixel precision |
| `waitForLoadState('networkidle')` | — | Ensures Ubuntu font from Google Fonts is loaded |
| `.locator('.tile').screenshot()` | — | Clips to the icon element, no page padding |
| `type: 'png'` | — | Lossless, full-colour-depth RGBA output |
| `omitBackground: true` | — | Renders page background as transparent; areas outside the rounded corners become fully transparent instead of white |

## Troubleshooting

| Symptom | Fix |
|---|---|
| Font shows as fallback sans-serif | Internet access blocked; the script still works but Ubuntu font won't load. Open the HTML in a browser once to warm DNS, or embed the font as base64. |
| `Error: browserType.launch: Executable doesn't exist` | Run `npx playwright install chromium` again |
| Output PNG is all black / blank | Chromium sandbox issue; add `chromium.launch({ args: ['--no-sandbox'] })` |
| `networkidle` times out | Increase timeout: `page.waitForLoadState('networkidle', { timeout: 30000 })` |
