import { test, expect, type Page } from "@playwright/test";

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => localStorage.clear());
  await page.goto("/");
  await page.locator("#next-chord").evaluate((element) => {
    element.classList.remove("deactivated");
  });
});

async function startFill(page: Page, durationMs: number): Promise<void> {
  await page.evaluate((duration) => {
    (window as any).__bsharp_start_next_arrow_fill(duration);
  }, durationMs);
}

test("starts the next-arrow fill with the requested duration", async ({ page }) => {
  await startFill(page, 1000);

  const state = await page.locator("#next-chord > i").evaluate((element) => {
    const arrow = element as HTMLElement;
    const styles = getComputedStyle(arrow, "::after");
    return {
      hasAnimationClass: arrow.classList.contains("next-arrow-fill"),
      animationName: styles.animationName,
      animationDuration: styles.animationDuration,
      initialClipPath: styles.clipPath,
    };
  });

  expect(state.hasAnimationClass).toBe(true);
  expect(state.animationName).toBe("next-arrow-fill");
  expect(state.animationDuration).toBe("1s");
  expect(state.initialClipPath).toMatch(/100%/);
});

test("the fill completes and reset removes the fill state", async ({ page }) => {
  await startFill(page, 100);
  await page.waitForTimeout(180);

  const completedClipPath = await page.locator("#next-chord > i").evaluate((element) =>
    getComputedStyle(element, "::after").clipPath,
  );
  expect(completedClipPath).not.toMatch(/100%/);

  await page.evaluate(() => {
    (window as any).__bsharp_reset_next_arrow_fill();
  });

  const resetState = await page.locator("#next-chord > i").evaluate((element) => {
    const arrow = element as HTMLElement;
    const styles = getComputedStyle(arrow, "::after");
    return {
      hasAnimationClass: arrow.classList.contains("next-arrow-fill"),
      animationName: styles.animationName,
      clipPath: styles.clipPath,
    };
  });

  expect(resetState.hasAnimationClass).toBe(false);
  expect(resetState.animationName).toBe("none");
  expect(resetState.clipPath).toMatch(/100%/);
});

test("starting again restarts the fill animation", async ({ page }) => {
  await startFill(page, 1000);
  await page.waitForTimeout(700);
  await startFill(page, 1000);
  await page.waitForTimeout(40);

  const clipPath = await page.locator("#next-chord > i").evaluate((element) =>
    getComputedStyle(element, "::after").clipPath,
  );

  const rightInset = Number(clipPath.match(/inset\([^ ]+ ([\d.]+)%/)?.[1]);
  expect(rightInset).toBeGreaterThan(90);
});

test("uses a fill color in the always-light Elisa theme", async ({ page }) => {
  await expect(page.locator("body")).toHaveClass(/colorscheme-light/);
  const fill = await page.locator("#next-chord > i").evaluate((element) =>
    getComputedStyle(element as HTMLElement).getPropertyValue("--next-arrow-fill-color"),
  );

  expect(fill.trim()).not.toBe("");
});
