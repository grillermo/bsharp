# Elisa aprende música — design

A private build of BSharp for one child, Elisa (age 4–5). It runs in Safari on an iPad mini
(6th gen), keeps BSharp's chord-color perfect-pitch training, is entirely in Spanish, looks like
bluey.tv, and rewards persistence by revealing a Bluey poster tile by tile.

Bluey characters, the poster, the "hello" font and the bluey.tv styling belong to Ludo Studio /
BBC. This build is for family use only and never ships to the Play Store.

## Decisions

- **Separate repo at `~/c/bbsharp`**, cloned from `~/c/third-parties/bsharp` with the GitHub repo
  as the `upstream` remote. Rationale: the user asked for it; the app is converted in place
  (no edition flags, no i18n layer) and upstream fixes can still be merged.
- **Subject: keep perfect-pitch chord training.** The adaptive engine and chord audio stay; Bluey
  is a reward and visual layer. Rationale: least new code; the method is the point.
- **Age 4–5.** Pre/early reader: short words plus icons, big touch targets, frequent rewards.
- **Rewards: celebration moments and effort over accuracy.** Every answer counts toward the next
  reward, including retries after a miss. No daily-streak mechanic. Rationale: reward persistence.
- **Rewards are a poster reveal**, not cut-out stickers: the poster is covered by tiles and each
  reward uncovers one. Rationale: user's choice; no segmentation work, one big visible goal.
- **Pace: 12×9 = 108 tiles, one tile per 5 answers.** About 4–5 tiles per 20–25-answer session;
  a poster takes about a month of daily practice.
- **When a poster is complete: a full-screen party, then the next poster starts.** Posters live in
  a folder; the user adds more images later. After the last poster it wraps to the first.
- **UI copies the bluey.tv look**: palette, tilted cards, pill buttons, clouds, headline font.
- **Headline font: bluey.tv's own "hello" font**, downloaded and bundled.
- **All UI in Spanish**, including chord color names (rojo, amarillo, azul, …).
- **Title shows her name: "Elisa aprende música".**
- **Hosting: the macmini, at a new Cloudflare route `bluey.chiq.me`.**
- **No access control on bluey.chiq.me.** The user chose to leave it open, accepting that the art
  is publicly reachable.

## Sources

- Poster: https://www.bluey.tv/wp-content/uploads/2024/10/full.png (2000×1508 PNG, ~300
  characters on a light-blue gradient).
- bluey.tv visual language, from its `theme-core.css` and a screenshot at iPad-mini size:
  - Sky-blue background with soft white clouds; garden/fence scene along the bottom.
  - Content sits in white cards rotated about -3°, border-radius 28px, with a pale-blue offset
    border acting as a shadow (`#abe0fa`, `#c2e3fe`).
  - Ink and primary pill buttons: slate purple `#5a5a87` (pressed `#4e4e7a`); lavender `#d8d7f8`.
  - Accents: yellow `#ffca3a`, coral `#f86468`, mint `#77e0c7`.
  - Headline font `hello` (chunky, hand-lettered); body font Open Sans.
  - Round icon buttons, white or slate, with a soft drop shadow.

## What Elisa sees

**Main screen** (portrait and landscape on the iPad mini, 744×1133 CSS px):

- Sky-blue background with clouds. A tilted white card at the top shows **Elisa aprende música**
  in the hello font, slate purple.
- The color flags remain the answer buttons, larger, with Spanish color names.
- One big round slate ▶ button plays the chord. Icons replace words wherever possible.
- A small poster thumbnail with a progress ring showing tries toward the next tile (for example
  3 of 5). Tapping it opens the poster view.
- Parent controls (settings, profiles, stats, level selector) sit behind a small gear icon in a
  corner, in Spanish.

**Reward moments:**

- **Every 5th answer**, right or wrong: the poster opens full-screen, one covered tile flips to
  reveal what is under it, a cheer plays and "¡Muy bien, Elisa!" appears. A tap closes it.
- **A wrong answer** shows a gentle "¡Inténtalo otra vez!", never a sad face.
- **Poster complete**: a full-screen party with confetti and the whole poster, then the next
  poster starts fully covered.
- **Poster view**: she can open the current poster at any time to look at what she has uncovered.

## Architecture

All changes are made in place in `~/c/bbsharp`.

- **`src/ts/poster.ts`** — pure logic, no DOM. Owns the poster state and the rules:
  - `PosterState = { posterIndex: number, revealed: number[], triesTowardNext: number }`
  - `recordTry(state, posterCount, rng) → { state, revealedTile: number | null, completed: boolean }`
    adds one try; on the 5th it picks a random still-covered tile (0–107), resets the counter, and
    reports whether the poster is now complete.
  - `startNextPoster(state, posterCount)` advances `posterIndex` (wrapping) and clears `revealed`.
  - `parsePosterState(raw)` returns a valid state from stored JSON, or a fresh one when the input
    is missing, corrupt or out of range (unknown tile numbers dropped, duplicates removed).
  - Constants: `GRID_COLS = 12`, `GRID_ROWS = 9`, `TRIES_PER_TILE = 5`.
- **Persistence**: localStorage key `elisa_poster`, separate from `bsharp_state`, so resetting
  BSharp stats or profiles never clears the poster.
- **Hook**: `selectFlagWrapper()` in `game.ts` already handles every answer; after `updateStats`
  it calls the reward layer, which calls `recordTry`, saves, and shows the reward when a tile was
  earned.
- **`src/ts/reward.ts`** — DOM side: poster thumbnail and progress ring, full-screen tile-flip
  overlay, cheer sound, completion party with confetti. CSS animations only (transform/opacity)
  to stay smooth on the iPad mini.
- **Posters**: `static/posters/` plus `static/posters/posters.json`, an ordered list of
  `{ "file": "...", "title": "..." }`. Poster 1 is the character poster. Adding a poster means
  dropping an image in the folder and adding one line.
- **Tiles**: the poster is one `<img>`; a 12×9 CSS grid of cover tiles sits on top of it. A revealed
  tile is transparent. No image slicing.
- **Spanish**: user-facing strings in `index.html` and TS are rewritten directly in Spanish.
- **Theme**: a new `_bluey.scss` holds the palette, cards, pill and round buttons and the cloud
  background; it replaces the dark/light theme toggle. The hello and Open Sans woff2 files go in
  `static/fonts/`.
- **Cheer sound**: one short MP3 in `static/sounds/`.

## iPad and hosting

- **Home-screen web app**: `manifest.json`, `apple-mobile-web-app-capable`, and an apple-touch-icon,
  so it opens full-screen without Safari chrome. The viewport and `touch-action` settings block
  accidental pinch and double-tap zoom.
- **Audio**: iOS plays audio only after a user gesture. The first ▶ tap also primes the cheer
  sound so later rewards can play it.
- **Deploy**: `make deploy` builds, then rsyncs `dist/` to the macmini at `~/c/elisa-www/`.
- **Serving**: a hand-added Caddy site block on the macmini (`root * /Users/grillermo/c/elisa-www`,
  `file_server`) on a free port, following the existing `staging_grillermo_com` pattern.
- **Route**: `./routes create bluey.chiq.me <port>` in `~/c/server`, committed there. Verified with
  `curl` returning 200.

## Out of scope / removed

- Android: the `android/` wrapper and Android make targets are no longer used. The directory
  stays (to keep upstream merges simple); the CLAUDE.md rule to run `make android-deploy` after
  each change no longer applies in this repo.
- Play Store release flow, onboarding hints for parents, single-note trainer.
- Offline service worker.

## Testing

- **Unit (`poster.test.ts`)**: a tile every 5 tries and none before; no tile revealed twice; the
  108th tile reports completion; `startNextPoster` wraps after the last poster;
  `parsePosterState` recovers from missing, corrupt and out-of-range data.
- **Screenshot (Playwright, 744×1133)**: main screen, reward overlay, completion party.
- Existing unit tests for stats and data must keep passing; tests that assert English UI text are
  updated to the Spanish strings.
