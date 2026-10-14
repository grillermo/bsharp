import { test, expect, Page } from "@playwright/test";

async function answer(page: Page, first: boolean): Promise<void> {
  // The next button auto-plays the following chord; the play button starts the first one.
  await page.locator(first ? "#play-button" : "#next-chord").click();
  await page.waitForTimeout(1000);
  await page.locator("#red-flag").click();
}

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => localStorage.clear());
});

test("every fifth answer, right or wrong, uncovers one poster tile", async ({ page }) => {
  await page.goto("/");
  for (let i = 0; i < 4; i++) {
    await answer(page, i === 0);
    await expect(page.locator("#poster-overlay")).not.toHaveClass(/visible/);
  }
  await answer(page, false);

  await expect(page.locator("#poster-overlay")).toHaveClass(/visible/);
  await expect(page.locator("#poster-message")).toHaveText("¡Muy bien, Elisa!");
  await expect(page.locator("#poster-tiles .poster-tile.revealed")).toHaveCount(1);
  const saved = await page.evaluate(() => JSON.parse(localStorage.getItem("elisa_poster")!));
  expect(saved.revealed).toHaveLength(1);
  expect(saved.triesTowardNext).toBe(0);
});

test("a wrong answer shows encouragement", async ({ page }) => {
  await page.addInitScript(() => {
    (window as any).__bsharp_test_deterministic_color = "yellow";
  });
  await page.goto("/");
  await answer(page, true);
  await expect(page.locator("#answer-feedback")).toHaveText("¡Inténtalo otra vez!");
});

test("the last tile throws a party and the next poster starts covered", async ({ page }) => {
  await page.addInitScript(() => {
    localStorage.setItem("elisa_poster", JSON.stringify({
      posterIndex: 0,
      revealed: Array.from({ length: 107 }, (_, i) => i),
      triesTowardNext: 4,
    }));
  });
  await page.goto("/");
  await answer(page, true);

  await expect(page.locator("#poster-overlay")).toHaveClass(/party/);
  await expect(page.locator("#poster-message")).toHaveText("¡Lo lograste, Elisa! ¡Terminaste el póster!");

  await page.locator("#poster-overlay").click();
  await expect(page.locator("#poster-overlay")).not.toHaveClass(/visible/);
  const saved = await page.evaluate(() => JSON.parse(localStorage.getItem("elisa_poster")!));
  expect(saved.revealed).toEqual([]);
});

test("tapping the thumbnail shows the poster so far", async ({ page }) => {
  await page.addInitScript(() => {
    localStorage.setItem("elisa_poster", JSON.stringify({ posterIndex: 0, revealed: [0, 1, 2], triesTowardNext: 0 }));
  });
  await page.goto("/");
  await page.locator("#poster-thumb").click();
  await expect(page.locator("#poster-overlay")).toHaveClass(/visible/);
  await expect(page.locator("#poster-tiles .poster-tile.revealed")).toHaveCount(3);
});
