import { test, expect, Page } from "@playwright/test";

// Controls row, hint and flags together, to show the arrow-to-button relationship.
async function hintArea(page: Page) {
  const controls = (await page.locator(".control-wrapper").boundingBox())!;
  const flags = (await page.locator("#flag-holder").boundingBox())!;
  return {
    x: 0,
    y: controls.y,
    width: controls.width,
    height: flags.y + flags.height - controls.y,
  };
}

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => {
    localStorage.clear();
    // Set before app code runs so selectNewColor() picks it up during init
    (window as any).__bsharp_test_deterministic_color = "red";
  });
  await page.goto("/");
});

const ORIENTATIONS = [
  { name: "portrait", viewport: { width: 744, height: 1133 } },
  { name: "landscape", viewport: { width: 1133, height: 744 } },
];

for (const { name, viewport } of ORIENTATIONS) {
test.describe(name, () => {
test.use({ viewport });

test("play overlay with arrow pointing to play button", async ({ page }) => {
  const overlay = page.locator("#onboarding-overlay");
  await expect(overlay).toBeVisible();

  await expect(page).toHaveScreenshot(`play-overlay-${name}.png`, { clip: await hintArea(page) });
});

test("guess overlay appearance", async ({ page }) => {
  await page.locator("#play-button").click();

  const overlay = page.locator("#onboarding-overlay");
  await expect(overlay).toBeVisible({ timeout: 5000 });
  await expect(overlay.locator(".onboarding-text")).toHaveText(
    "Adivina el color",
  );

  await expect(page).toHaveScreenshot(`guess-overlay-${name}.png`, { clip: await hintArea(page) });
});
});
}
