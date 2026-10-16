import { test, expect } from "@playwright/test";
import { createProfile, openProfilePanel } from "./helpers";

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => localStorage.clear());
  await page.goto("/");
});

test("play overlay visible on page load with arrow", async ({ page }) => {
  const overlay = page.locator("#onboarding-overlay");
  await expect(overlay).toBeVisible();
  await expect(overlay).toHaveAttribute("data-step", "play");
  // Should contain arrow and text
  await expect(overlay.locator(".onboarding-arrow")).toBeVisible();
  await expect(overlay.locator(".onboarding-text")).toHaveText(
    "Toca el botón ▶ para escuchar",
  );
});

test("play overlay dismissed after clicking play", async ({ page }) => {
  const overlay = page.locator("#onboarding-overlay");
  await expect(overlay).toBeVisible();

  await page.locator("#play-button").click();
  await expect(overlay).not.toBeVisible();
});

test("guess overlay appears after audio finishes on first session", async ({
  page,
}) => {
  const overlay = page.locator("#onboarding-overlay");

  await page.locator("#play-button").click();
  await expect(overlay).not.toBeVisible();

  // Wait for audio to finish and guess overlay to appear
  await expect(overlay).toBeVisible({ timeout: 5000 });
  await expect(overlay.locator(".onboarding-text")).toHaveText(
    "Adivina el color",
  );
  await expect(overlay).toHaveAttribute("data-step", "guess");
});

test("a correct guess clears the hint on first identification", async ({
  page,
}) => {
  const overlay = page.locator("#onboarding-overlay");

  await page.locator("#play-button").click();
  await expect(overlay).toBeVisible({ timeout: 5000 });

  const correctColor = await page.evaluate(() => {
    return (window as any).__bsharp_correct_color?.() ?? null;
  });
  await page.locator(`#${correctColor}-flag .flag`).click();

  await expect(overlay).not.toBeVisible();
});

test("a wrong guess keeps the guess hint so she can try again", async ({
  page,
}) => {
  const overlay = page.locator("#onboarding-overlay");

  await page.locator("#play-button").click();
  await expect(overlay).toBeVisible({ timeout: 5000 });

  const correctColor = await page.evaluate(() => {
    return (window as any).__bsharp_correct_color?.() ?? null;
  });
  const wrongColor = correctColor === "red" ? "yellow" : "red";
  await page.locator(`#${wrongColor}-flag .flag`).click();

  await expect(overlay).toBeVisible();
  await expect(overlay).toHaveAttribute("data-step", "guess");
});

test("guess overlay does NOT appear after first identification", async ({
  page,
}) => {
  const overlay = page.locator("#onboarding-overlay");

  await page.locator("#play-button").click();
  await expect(overlay).toBeVisible({ timeout: 5000 });
  const correctColor = await page.evaluate(() => {
    return (window as any).__bsharp_correct_color?.() ?? null;
  });
  await page.locator(`#${correctColor}-flag .flag`).click();
  await expect(overlay).not.toBeVisible();

  // The character shows, the next chord plays by itself and its audio ends.
  await page.waitForTimeout(5500);

  await expect(overlay).not.toBeVisible();
});

test("guess overlay does NOT appear for profile with existing history", async ({
  page,
}) => {
  const overlay = page.locator("#onboarding-overlay");

  // Play, answer, creating session history
  await page.locator("#play-button").click();
  await expect(overlay).toBeVisible({ timeout: 5000 });
  await page.locator("#red-flag .flag").click();

  // Reset to save session history
  await page.locator("#reset-button").evaluate((el) => (el as HTMLElement).click()); // hidden from the child

  // Reload the page
  await page.reload();
  await expect(overlay).toBeVisible();
  await expect(overlay.locator(".onboarding-text")).toHaveText(
    "Toca el botón ▶ para escuchar",
  );

  // Play and wait for audio to finish
  await page.locator("#play-button").click();
  await page.waitForTimeout(1500);

  // Guess overlay should NOT appear since profile has history
  await expect(overlay).not.toBeVisible();
});

test("overlay reappears when switching to a new profile", async ({ page }) => {
  const overlay = page.locator("#onboarding-overlay");

  // Play and answer to create history for default profile
  await page.locator("#play-button").click();
  await expect(overlay).toBeVisible({ timeout: 5000 });
  await page.locator("#red-flag .flag").click();
  await page.locator("#reset-button").evaluate((el) => (el as HTMLElement).click()); // hidden from the child

  // Create a new profile via helper (handles hamburger menu)
  await createProfile(page, "Test Child", "fa-truck");

  // New profile should show the play overlay
  await expect(overlay).toBeVisible();
  await expect(overlay.locator(".onboarding-text")).toHaveText(
    "Toca el botón ▶ para escuchar",
  );

  // Play and wait — guess overlay should appear for new profile (no history)
  await page.locator("#play-button").click();
  await expect(overlay).toBeVisible({ timeout: 5000 });
  await expect(overlay.locator(".onboarding-text")).toHaveText(
    "Adivina el color",
  );
});

test("no overlays when onboarding hints disabled in profile settings", async ({
  page,
}) => {
  const overlay = page.locator("#onboarding-overlay");

  // Disable onboarding hints for the Guest profile
  await openProfilePanel(page);
  await page.locator("#enable_onboarding_hints_setting").uncheck();
  await page.locator("#submit-changes-button").click();

  // Reset stats to trigger initOnboarding flow
  await page.locator("#reset-button").evaluate((el) => (el as HTMLElement).click()); // hidden from the child

  // Play overlay should NOT appear
  await expect(overlay).not.toBeVisible();
});
