import { test, expect } from "@playwright/test";

test("main screen", async ({ page }) => {
  await page.addInitScript(() => {
    localStorage.clear();
    localStorage.setItem(
      "bsharp_session_history",
      JSON.stringify({ "100": { chord: [{ identifications: 1 }] } }),
    );
    (window as any).__bsharp_test_deterministic_color = "red";
  });
  await page.goto("/");
  await page.locator("#onboarding-overlay").evaluate((el) => el.classList.remove("visible"));
  await expect(page).toHaveScreenshot("main.png", { fullPage: true });
});
