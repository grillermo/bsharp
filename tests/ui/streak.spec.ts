import { test, expect, Page } from "@playwright/test";

// Red is forced as the answer, so red is always correct and yellow always wrong.
test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => {
    (window as any).__bsharp_test_deterministic_color = "red";
  });
});

const fill = (page: Page) => page.locator("#streak-outline .streak-fill");
const offset = (page: Page) =>
  fill(page).evaluate((el) => Number((el as SVGPathElement).style.strokeDashoffset));

/** Start from a clean profile whose streak is already `streak` at level `chord`. */
async function seed(page: Page, streak: number, chord = "yellow") {
  await page.goto("/");
  await page.evaluate(
    ([streak, chord]) => {
      localStorage.clear();
      const state = {
        profiles: {
          100: {
            id: 100, name: "Elisa", icon: "fa-paw", target_number: 20,
            show_chord_mode: "never", reveal_chord_mode: "always", chord_display_mode: "shapes_and_letters",
            single_note_mode: "off", single_note_correctness_mode: "exact",
            persist_reaction_face: false, enable_onboarding_hints: false, color_scheme: "light",
            chord_selection_mode: "random", current_chord: chord, current_instrument: "piano_1",
            streak,
            stats: {
              current_chord: chord, start_time: Date.now() / 1000, updated_time: Date.now() / 1000,
              correct: 0, identifications: 0, confusion_matrix: {}, notes: {}, done: false,
            },
          },
        },
        current_chord: chord,
        current_profile: 100,
      };
      localStorage.setItem("bsharp_state", JSON.stringify(state));
    },
    [streak, chord] as const,
  );
  await page.reload();
}

async function answer(page: Page, flag: "red" | "yellow") {
  await page.locator("#play-button").click();
  await page.waitForTimeout(1000);
  await page.locator(`#${flag}-flag`).click();
}

test("the outline starts empty and a right answer fills one twentieth", async ({ page }) => {
  await seed(page, 0);
  await expect.poll(() => offset(page)).toBe(1);

  await answer(page, "red");
  await expect.poll(() => offset(page)).toBeCloseTo(0.95, 5);
});

test("a wrong answer empties the outline", async ({ page }) => {
  await seed(page, 7);
  await expect.poll(() => offset(page)).toBeCloseTo(1 - 7 / 20, 5);

  await answer(page, "yellow");
  await expect.poll(() => offset(page)).toBe(1);
});

test("the streak survives a reload", async ({ page }) => {
  await seed(page, 0);
  await answer(page, "red");
  await expect.poll(() => offset(page)).toBeCloseTo(0.95, 5);
  await page.reload();
  await expect.poll(() => offset(page)).toBeCloseTo(0.95, 5);
});

test("the 20th correct answer in a row moves to the next level by itself", async ({ page }) => {
  await seed(page, 19, "yellow");
  await answer(page, "red");

  // The outline is full while the character shows...
  await expect.poll(() => offset(page)).toBeCloseTo(0, 5);
  await expect(page.locator("#character-reveal")).toHaveClass(/visible/);
  // ...then the level changes and the outline starts over.
  await expect(page.locator("#chord-selector")).toHaveValue("blue", { timeout: 6000 });
  await expect.poll(() => offset(page)).toBe(1);
  await expect(page.locator("#blue-flag")).toBeVisible();
});

test("changing the level by hand resets the streak", async ({ page }) => {
  await seed(page, 9, "yellow");
  await page.locator("#chord-selector").evaluate((el) => {
    (el as HTMLSelectElement).value = "blue";
    (window as any).change_selector();
  });
  await expect.poll(() => offset(page)).toBe(1);
});

test("at the last level the streak just starts over", async ({ page }) => {
  await seed(page, 19, "skyblue");
  await answer(page, "red");
  await expect(page.locator("#character-reveal")).not.toHaveClass(/visible/, { timeout: 6000 });
  await expect(page.locator("#chord-selector")).toHaveValue("skyblue");
  await expect.poll(() => offset(page)).toBe(1);
});
