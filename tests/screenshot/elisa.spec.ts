import { test, expect, Page } from "@playwright/test";

async function open(page: Page, revealed: number[], triesTowardNext: number): Promise<void> {
  await page.addInitScript(([revealed, tries]) => {
    localStorage.clear();
    localStorage.setItem(
      "bsharp_session_history",
      JSON.stringify({ "100": { chord: [{ identifications: 1 }] } }),
    );
    localStorage.setItem("elisa_poster", JSON.stringify({ posterIndex: 0, revealed, triesTowardNext: tries }));
    (window as any).__bsharp_test_deterministic_color = "red";
  }, [revealed, triesTowardNext] as const);
  await page.goto("/");
  await page.locator("#onboarding-overlay").evaluate((el) => el.classList.remove("visible"));
}

const SOME_TILES = [0, 13, 26, 40, 55, 61, 77, 90, 100];

test("main screen", async ({ page }) => {
  await open(page, SOME_TILES, 3);
  await expect(page).toHaveScreenshot("main.png", { fullPage: true });
});

test("poster overlay", async ({ page }) => {
  await open(page, SOME_TILES, 3);
  await page.locator("#poster-thumb").click();
  await expect(page).toHaveScreenshot("poster.png");
});

test("completion party", async ({ page }) => {
  await open(page, Array.from({ length: 107 }, (_, i) => i), 4);
  await page.locator("#play-button").click();
  await page.waitForTimeout(1000);
  await page.locator("#red-flag").click();
  await expect(page.locator("#poster-overlay")).toHaveClass(/party/);
  await page.locator("#confetti").evaluate((el) => (el.innerHTML = ""));
  await page.waitForTimeout(800);
  await expect(page).toHaveScreenshot("party.png");
});
