// Captures the live web app (bluey.chiq.me) at every level and in every screen state, as
// reference for the native iOS port. Run from the repo root:
//
//   node "SwiftApp/Reference Material/capture-screenshots.ts"
//
// Each page gets a fresh browser context, so no real progress is touched. PNGs go to the
// screenshots/ folder next to this file.
import { chromium, devices, type Browser, type Page } from "@playwright/test";
import fs from "node:fs";
import path from "node:path";

const OUT = path.join(import.meta.dirname, "screenshots");
const URL = "https://bluey.chiq.me/";

// The chord-selector values, in order. Red alone is level 0 and is hidden in the selector.
const LEVELS: [string, string][] = [
  ["yellow", "white-01-amarillo"],
  ["blue", "white-02-azul"],
  ["black", "white-03-negro"],
  ["green", "white-04-verde"],
  ["orange", "white-05-naranja"],
  ["purple", "white-06-morado"],
  ["pink", "white-07-rosa"],
  ["brown", "white-08-cafe"],
  ["gray", "black-01-gris"],
  ["tan", "black-02-beige"],
  ["lightgreen", "black-03-verde-claro"],
  ["lightpurple", "black-04-lila"],
  ["skyblue", "black-05-celeste"],
];

// iPad mini (6th gen), the device Elisa uses, plus an iPhone for the compact layout.
const DEVICES = {
  "ipad-portrait": { viewport: { width: 744, height: 1133 } },
  "ipad-landscape": { viewport: { width: 1133, height: 744 } },
  "iphone-portrait": { viewport: { width: 393, height: 852 } },
};

async function open(browser: Browser, device: keyof typeof DEVICES, opts: {
  level?: string; streak?: number; firstRun?: boolean;
} = {}): Promise<Page> {
  const context = await browser.newContext({
    userAgent: devices["iPad Mini"].userAgent,
    deviceScaleFactor: 2,
    isMobile: true,
    hasTouch: true,
    ...DEVICES[device],
  });
  const page = await context.newPage();
  await page.addInitScript((firstRun: boolean) => {
    (window as any).__bsharp_test_deterministic_color = "red";
    if (sessionStorage.getItem("seeded")) return;
    sessionStorage.setItem("seeded", "1");
    localStorage.clear();
    // A past identification skips the first-session hints.
    if (!firstRun) {
      // A few finished sessions over the last days, so the stats history has real rows.
      const day = 86400, now = Date.now() / 1000;
      const session = (chord: string, ago: number, correct: number, identifications: number) => ({
        current_chord: chord, start_time: now - ago, updated_time: now - ago + 180,
        correct, identifications, confusion_matrix: {},
        notes: { correct: 0, identifications: 0, confusion_matrix: {} }, done: true,
      });
      localStorage.setItem("bsharp_session_history", JSON.stringify({ "100": {
        yellow: [session("yellow", 3 * day, 18, 25), session("yellow", 2 * day, 22, 25),
                 session("yellow", day, 24, 25), session("yellow", 3600, 25, 25)],
      } }));
    }
  }, opts.firstRun ?? false);
  await page.goto(URL);
  if (opts.level || opts.streak !== undefined) {
    await page.evaluate(({ level, streak }) => {
      const state = JSON.parse(localStorage.getItem("bsharp_state")!);
      const profile = state.profiles[state.current_profile];
      if (level) { state.current_chord = level; profile.current_chord = level; profile.stats.current_chord = level; }
      if (streak !== undefined) profile.streak = streak;
      localStorage.setItem("bsharp_state", JSON.stringify(state));
    }, { level: opts.level, streak: opts.streak });
    await page.reload();
  }
  if (!opts.firstRun) {
    await page.locator("#onboarding-overlay").evaluate((el) => el.classList.remove("visible"));
  }
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(1200); // streak outline transition
  return page;
}

async function shot(page: Page, name: string): Promise<void> {
  await page.screenshot({ path: path.join(OUT, `${name}.png`) });
  console.log(`  ${name}.png`);
  await page.context().close();
}

// Plays the chord and answers it correctly (red is forced), leaving the character on screen.
async function answerCorrectly(page: Page): Promise<void> {
  await page.locator("#play-button").click();
  await page.waitForTimeout(1500);
  await page.locator("#red-flag .flag").click();
  await page.locator("#character-reveal.visible").waitFor();
  await page.waitForTimeout(600);
}

async function openPanel(page: Page, trigger: string): Promise<void> {
  await page.locator("div.hamburger a").click();
  if (trigger) await page.locator(trigger).click();
  await page.waitForTimeout(500);
}

async function main(): Promise<void> {
  fs.rmSync(OUT, { recursive: true, force: true });
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch();
  try {
    console.log("Levels");
    for (const device of Object.keys(DEVICES) as (keyof typeof DEVICES)[]) {
      for (const [level, name] of LEVELS) {
        await shot(await open(browser, device, { level }), `level-${name}-${device}`);
      }
    }

    console.log("Game states (iPad portrait)");
    const d = "ipad-portrait";
    await shot(await open(browser, d, { firstRun: true }), "state-01-first-run-play-hint");

    let page = await open(browser, d);
    await page.locator("#play-button").click();
    await page.waitForTimeout(1500);
    await shot(page, "state-02-chord-playing");

    page = await open(browser, d);
    await page.locator("#play-button").click();
    await page.waitForTimeout(1500);
    await page.locator("#yellow-flag .flag").click();
    await page.waitForTimeout(400);
    await shot(page, "state-03-wrong-answer");

    page = await open(browser, d);
    await answerCorrectly(page);
    await shot(page, "state-04-correct-character-reveal");

    page = await open(browser, d);
    await answerCorrectly(page);
    await page.locator("#character-reveal:not(.visible)").waitFor({ timeout: 6000 });
    await page.waitForTimeout(400);
    await shot(page, "state-05-awaiting-play-after-reveal");

    for (const streak of [5, 10, 15, 19]) {
      await shot(await open(browser, d, { streak }), `state-06-streak-${String(streak).padStart(2, "0")}-of-20`);
    }

    page = await open(browser, d, { streak: 19 });
    await answerCorrectly(page);
    await page.locator("#character-reveal:not(.visible)").waitFor({ timeout: 6000 });
    await page.waitForTimeout(1200);
    await shot(page, "state-07-after-level-up-to-azul");

    console.log("Menu and panels (iPad portrait)");
    page = await open(browser, d); await openPanel(page, ""); await shot(page, "menu-01-gear-open");
    page = await open(browser, d); await openPanel(page, "#trainer-infobox-trigger"); await shot(page, "menu-02-piano-trainer");
    page = await open(browser, d); await openPanel(page, "#i-infobox-trigger"); await shot(page, "menu-03-info");
    page = await open(browser, d); await openPanel(page, "#stats-history-trigger"); await shot(page, "menu-04-stats-history");
    page = await open(browser, d); await openPanel(page, "#profile-infobox-trigger"); await shot(page, "menu-05-profile-settings");
    page = await open(browser, d);
    await openPanel(page, "#profile-infobox-trigger");
    await page.locator("#profile-info-container").evaluate((el) => el.scrollTo(0, el.scrollHeight));
    await shot(page, "menu-06-profile-settings-scrolled");
  } finally {
    await browser.close();
  }
}

main().catch((err) => { console.error(err); process.exit(1); });
