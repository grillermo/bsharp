import { test, expect } from "@playwright/test";

// Red is forced as the answer, so red is always correct and yellow always wrong.
test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => {
    localStorage.clear();
    (window as any).__bsharp_test_deterministic_color = "red";
  });
  await page.goto("/");
});

async function startQuestion(page: import("@playwright/test").Page) {
  await page.locator("#play-button").click();
  await page.waitForTimeout(1000);
}

test("play button is active after init", async ({ page }) => {
  const playButton = page.locator("#play-button");
  await expect(playButton).toBeVisible();
  await expect(playButton).not.toHaveClass(/deactivated/);
});

test("a wrong flag changes nothing and she can keep guessing", async ({ page }) => {
  await startQuestion(page);
  await page.locator("#yellow-flag").click();

  await expect(page.locator("#yellow-flag .flag")).not.toHaveClass(/flag-incorrect|flag-correct/);
  await expect(page.locator("#red-flag .flag")).not.toHaveClass(/flag-correct/);
  await expect(page.locator("#character-reveal")).not.toHaveClass(/visible/);
  await expect(page.locator("#next-chord")).toHaveClass(/deactivated/);

  // The miss still counts in the stats.
  await expect(page.locator("#stats-total")).toHaveText("1");
  await expect(page.locator("#stats-correct")).toHaveText("0");

  // A second guess is still accepted.
  await page.locator("#red-flag").click();
  await expect(page.locator("#red-flag .flag")).toHaveClass(/flag-correct/);
  await expect(page.locator("#stats-total")).toHaveText("2");
});

test("the right flag shows a named character, then the game advances by itself", async ({ page }) => {
  await startQuestion(page);
  await page.locator("#red-flag").click();

  const reveal = page.locator("#character-reveal");
  await expect(page.locator("#red-flag .flag")).toHaveClass(/flag-correct/);
  await expect(reveal).toHaveClass(/visible/);
  const name = (await reveal.locator(".character-name").textContent())!.trim();
  expect(name.length).toBeGreaterThan(0);
  await expect(reveal.locator("img")).toHaveAttribute("src", /static\/characters\/[a-z]+\.png/);
  await expect(reveal.locator("img")).toHaveJSProperty("complete", true);

  // Taps while the character shows are not counted as answers.
  await page.locator("#yellow-flag").click();
  await expect(page.locator("#stats-total")).toHaveText("1");

  // A few seconds later the character is gone and the next chord is up.
  await expect(reveal).not.toHaveClass(/visible/, { timeout: 5000 });
  await expect(page.locator("#red-flag .flag")).not.toHaveClass(/flag-correct/);
});

test("stats counter increments after answering", async ({ page }) => {
  await expect(page.locator("#stats-correct")).toHaveText("0");
  await expect(page.locator("#stats-total")).toHaveText("0");

  await startQuestion(page);
  await page.locator("#red-flag").click();

  await expect(page.locator("#stats-correct")).toHaveText("1");
  await expect(page.locator("#stats-total")).toHaveText("1");
});

test("reset clears stats to zero", async ({ page }) => {
  await startQuestion(page);
  await page.locator("#red-flag").click();

  await expect(page.locator("#stats-total")).toHaveText("1");

  // The reset button is hidden from the child; trigger it directly.
  await page.locator("#reset-button").evaluate((el) => (el as HTMLElement).click());

  await expect(page.locator("#stats-correct")).toHaveText("0");
  await expect(page.locator("#stats-total")).toHaveText("0");
});

test("every character image is fetched at page load", async ({ page }) => {
  await expect
    .poll(() =>
      page.evaluate(
        () =>
          performance
            .getEntriesByType("resource")
            .filter((e) => /static\/characters\/[a-z]+\.png/.test(e.name)).length,
      ),
    )
    .toBe(25);
});
