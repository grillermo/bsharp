import { test, expect } from "@playwright/test";

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => localStorage.clear());
  await page.addInitScript(() => {
    (window as any).__bsharp_test_deterministic_color = "red";
    (window as any).__played = [] as string[];
    (window as any).__pauses = [] as string[];
    const origPause = HTMLAudioElement.prototype.pause;
    HTMLAudioElement.prototype.pause = function () {
      if (!this.ended) (window as any).__pauses.push(this.getAttribute("src") ?? "");
      return origPause.call(this);
    };
    const origPlay = HTMLAudioElement.prototype.play;
    HTMLAudioElement.prototype.play = function () {
      (window as any).__played.push(this.getAttribute("src") ?? "");
      if ((this.getAttribute("src") ?? "").includes("/chords/")) (window as any).__lastEl = this;
      return origPlay.call(this);
    };
  });
  await page.goto("/");
});

// Reward sounds are primed silently on first touch; only chord files count here.
const played = (page: any) =>
  page.evaluate(() => ((window as any).__played as string[]).filter((s) => s.includes("/chords/")));

test("tapping a flag before play plays its chord, no stats", async ({ page }) => {
  await page.locator("#red-flag .flag").click();
  const log = await played(page);
  expect(log).toHaveLength(1);
  expect(log[0]).toMatch(/_red_/);
  await expect(page.locator("#stats-total")).toHaveText("0");
  await expect(page.locator("#red-flag .flag")).not.toHaveClass(/flag-correct|flag-incorrect/);
  // chord remains audible after click-phase audio stops
  await page.waitForTimeout(100);
  const state = await page.evaluate(() => {
    const el = (window as any).__lastEl as HTMLAudioElement;
    const src = el.getAttribute("src");
    return { ok: !el.paused || el.ended, pausedMidway: (window as any).__pauses.slice(1).includes(src) };
  });
  expect(state.ok).toBe(true);
  expect(state.pausedMidway).toBe(false);
});

test("a piano chord does not unlock answering", async ({ page }) => {
  await page.locator("#red-flag .flag").click();
  await page.waitForTimeout(4000);
  await page.locator("#red-flag .flag").click();
  await expect(page.locator("#stats-total")).toHaveText("0");
});

test("answering tap records stats and plays tapped chord; later taps play chords", async ({ page }) => {
  await page.locator("#play-button").click();
  await page.waitForTimeout(1000);
  await page.evaluate(() => ((window as any).__played = []));
  await page.locator("#red-flag .flag").click();
  expect((await played(page))[0]).toMatch(/_red_/);
  await expect(page.locator("#stats-total")).toHaveText("1");

  await page.locator("#yellow-flag .flag").click();
  const log = await played(page);
  expect(log.length).toBeGreaterThanOrEqual(2);
  expect(log[log.length - 1]).toMatch(/_yellow_/);
  await expect(page.locator("#stats-total")).toHaveText("1");
});
