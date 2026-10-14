import { test, expect } from "@playwright/test";

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => localStorage.clear());
  await page.goto("/");
});

test("download button hidden by default", async ({ page }) => {
  await expect(page.locator("#download-link")).not.toHaveClass(/visible/);
});

test("shows Elisa's title", async ({ page }) => {
  await expect(page.locator(".title-card h1")).toHaveText("Elisa aprende música");
});
