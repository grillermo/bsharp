import { test, expect } from "@playwright/test";

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => localStorage.clear());
  await page.addInitScript(() => {
    (window as any).__audioSpy = {
      callLog: [] as string[],
      lastPlayedElement: null as HTMLAudioElement | null,
    };
    const origPlay = HTMLAudioElement.prototype.play;
    HTMLAudioElement.prototype.play = function () {
      (window as any).__audioSpy.callLog.push("play");
      (window as any).__audioSpy.lastPlayedElement = this;
      return origPlay.call(this);
    };
    const origPause = HTMLAudioElement.prototype.pause;
    HTMLAudioElement.prototype.pause = function () {
      (window as any).__audioSpy.callLog.push("pause");
      return origPause.call(this);
    };
  });
  await page.goto("/");
});

test("clicking play starts audio element", async ({ page }) => {
  await page.locator("#play-button").click();

  const paused = await page.evaluate(
    () => (window as any).__audioSpy.lastPlayedElement?.paused ?? null,
  );
  expect(paused).toBe(false);
});

test("rapid play clicks leave audio playing", async ({ page }) => {
  const playButton = page.locator("#play-button");
  await playButton.click();
  await playButton.click();
  await playButton.click();

  const state = await page.evaluate(() => {
    const { callLog, lastPlayedElement } = (window as any).__audioSpy;
    return {
      lastCall: callLog[callLog.length - 1],
      paused: lastPlayedElement?.paused ?? null,
    };
  });

  expect(state.lastCall).toBe("play");
  expect(state.paused).toBe(false);
});

test("answering correctly plays the next chord by itself", async ({ page }) => {
  await page.addInitScript(() => {
    (window as any).__bsharp_test_deterministic_color = "red";
  });
  await page.goto("/");
  await page.locator("#play-button").click();
  await page.waitForTimeout(1000);
  await page.locator("#red-flag .flag").click();

  // Reset spy log, then wait out the character reveal.
  await page.evaluate(() => {
    (window as any).__audioSpy.callLog = [];
  });
  await page.waitForTimeout(3500);

  const state = await page.evaluate(() => {
    const { callLog, lastPlayedElement } = (window as any).__audioSpy;
    return {
      played: callLog.includes("play"),
      paused: lastPlayedElement?.paused ?? null,
    };
  });

  expect(state.played).toBe(true);
  expect(state.paused).toBe(false);
});
