# Reference Material

What the web app (https://bluey.chiq.me) looks like and does, for the native iOS port in
`SwiftApp/`. The screenshots were taken from the live site on 2026-10-30. The deployed build
doesn't include the uncommitted safe-area and title-card changes that were in `src/` that day.

Re-capture with (from the repo root; needs Playwright's Chromium 1208):

```bash
node --disable-warning=MODULE_TYPELESS_PACKAGE_JSON "SwiftApp/Reference Material/capture-screenshots.ts"
```

Every page runs in a fresh browser context with chord red forced as the answer, so the captures
are repeatable and never touch real progress.

## screenshots/

Sizes: iPad mini 6 portrait 744×1133 and landscape 1133×744, iPhone 393×852, all at 2×.

| Files | What |
|-------|------|
| `level-white-01-amarillo-*` … `level-white-08-cafe-*` | White-key levels 1–8: 2 to 9 flags, no note shapes |
| `level-black-01-gris-*` … `level-black-05-celeste-*` | Black-key levels 1–5: 10 to 14 flags, note shapes and letters on every flag |
| `state-01-first-run-play-hint` | First run: arrow under the play button, no text (she can't read yet) |
| `state-02-chord-playing` | Chord played, waiting for an answer |
| `state-03-wrong-answer` | After a wrong tap: nothing marked, keeps waiting (the tapped chord sounds) |
| `state-04-correct-character-reveal` | Correct: green outline and check on the flag, a Bluey character with its name |
| `state-05-awaiting-play-after-reveal` | After the reveal: next chord loaded, flags dimmed until play is pressed |
| `state-06-streak-NN-of-20` | Streak outline filling clockwise round the screen at 5, 10, 15 and 19 of 20 |
| `state-07-after-level-up-to-azul` | 20 in a row moves to the next level (here Azul, 3 flags) |
| `menu-01-gear-open` | Gear opens the icon bar: home, piano, info, stats, profile |
| `menu-02-piano-trainer` | Piano: all 14 colors, tap to hear each chord |
| `menu-03-info` | About the Eguchi method (Spanish) |
| `menu-04-stats-history` | Past sessions: color, date, correct/total, % and face |
| `menu-05/06-profile-settings` | Profile switcher and settings form (level, instrument, name, icon, display options, goal) |

## Behavior the screenshots can't show

- **Chords** (`src/ts/data.ts`): red C, yellow F/C, blue G/B, black F/A, green G/D, orange C/E,
  purple F, pink G, brown C/G, then gray A, tan D, light green E, light purple B♭, sky blue E♭.
  Level N shows the first N+1 colors.
- **Flag colors** (`src/scss/_cim.scss`): red `#FF0000`, yellow `#FFFF00`, blue `#0000FF`, black
  `#000000`, green `#008000`, orange `#FF8200`, purple `#800080`, pink `#FC0FC0`, brown `#81613C`,
  gray `#808080`, tan `#F0E68C`, light green `#7FFF00`, light purple `#DCD0FF`, sky blue `#87CEFA`.
- **Theme** (`src/scss/_bluey.scss`): ink `#5A5A87`, sky gradient `#8FD3FB` → `#C2E3FE`, edge
  `#ABE0FA`, grass at the bottom; Hello Headline font for titles, Open Sans for text.
- **Audio**: 3 piano recordings per chord (short/medium/long, one picked at random), plus guitar
  and strummed-guitar sets, in `static/chords/`. Any flag tap plays that flag's chord.
- **Flow** (`src/ts/game.ts`): a flag only counts as an answer once the question chord has
  played. A wrong answer resets the streak and isn't marked. A correct one shows the
  character for 3 s (`REVEAL_MS`), then loads the next chord without playing it.
- **Streak** (`src/ts/streak.ts`): 20 correct in a row (`STREAK_TARGET`) moves up one level; any
  miss drops it to 0. The outline fills in 0.9 s and empties in 0.35 s.
- **Characters** (`src/ts/characters.ts`): 25 PNGs in `static/characters/`, dealt like a
  shuffled deck so each one shows once per round, never the same one twice in a row.
- **Adaptive mode** (`src/ts/stats.ts`): weights chords by the confusion matrix of recent
  sessions; the unit tests in `tests/unit/` pin its math.
