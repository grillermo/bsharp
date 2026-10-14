# Elisa aprende música Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn this BSharp clone into "Elisa aprende música": Spanish, styled like bluey.tv, rewarding every 5 answers with a newly uncovered tile of a Bluey poster, running full-screen in Safari on an iPad mini 6 from `https://bluey.chiq.me`.

**Architecture:** The chord trainer stays as is. A new pure module `poster.ts` owns the reveal rules (tested with vitest), a new DOM module `reward.ts` renders the thumbnail, reveal overlay and party, and `game.ts` calls `onAnswer()` once per answer. Strings are translated in place; a new `_bluey.scss` restyles the always-on light theme. The built `dist/` is rsynced to the macmini and served by Caddy behind a Cloudflare tunnel route.

**Tech Stack:** TypeScript + esbuild (IIFE bundle), SCSS via sass, vitest (unit), Playwright (UI + screenshot), ImageMagick, ffmpeg, macOS `say`, Caddy, cloudflared routes tool in `~/c/server`.

**Spec:** `docs/superpowers/specs/2026-10-14-bluey-edition-design.md`

**Repo:** `/Users/grillermo/c/bbsharp` (branch `master`). All paths below are relative to it unless absolute. Do not run `make android-deploy`; Android is out of scope in this repo (the inherited CLAUDE.md rule is updated in Task 8).

---

## File map

| File | Status | Responsibility |
|---|---|---|
| `static/posters/posters.json` | create | Ordered poster list `{file, title}` |
| `static/posters/bluey-todos.jpg` | create | Poster 1 (the character poster) |
| `static/fonts/hello-headline.woff2`, `open-sans-regular.woff2`, `open-sans-bold.woff2` | create | bluey.tv fonts |
| `static/sounds/muy-bien.mp3`, `poster-completo.mp3` | create | Chime + Spanish voice for tile reveal and completion |
| `static/icons/apple-touch-icon.png`, `icon-512.png` | create | Home-screen icons |
| `static/manifest.webmanifest` | create | Web app manifest |
| `src/ts/poster.ts` | create | Pure reveal rules and state parsing |
| `tests/unit/poster.test.ts` | create | Unit tests for `poster.ts` |
| `src/ts/reward.ts` | create | DOM: thumbnail, overlay, tile flip, feedback text, party, sounds |
| `tests/ui/reward.spec.ts` | create | UI behavior of the reward flow |
| `src/scss/_bluey.scss` | create | bluey.tv theme |
| `tests/screenshot/elisa.spec.ts` | create | Screenshots of main screen, reveal, party |
| `src/index.html` | modify | Spanish, title card, gear, reward markup, PWA meta |
| `src/ts/game.ts` | modify | Call `onAnswer(isCorrect)` |
| `src/ts/main.ts` | modify | Init rewards, expose `open_poster`/`close_poster`, prime audio |
| `src/ts/onboarding.ts`, `src/ts/ui.ts`, `src/ts/state.ts`, `src/ts/stats.ts` | modify | Spanish strings, default profile "Elisa", no sad faces, light theme only |
| `src/scss/style.scss` | modify | Import `_bluey.scss` last |
| `tests/device.ts` | modify | iPad mini viewport |
| `tests/ui/onboarding.spec.ts`, `profile.spec.ts`, `theme.spec.ts`, `settings.spec.ts` | modify | Spanish text, removed theme feature |
| `Makefile` | modify | `deploy` target |
| `CLAUDE.md`, `README.md`, `TODO.md` | modify | Describe this fork |
| `/Users/grillermo/c/server/Caddyfile`, `routes.yml` | modify | Serve and publish on the macmini |

---

### Task 1: Assets (poster, fonts, sounds, icons)

**Files:**
- Create: `static/posters/bluey-todos.jpg`, `static/posters/posters.json`, `static/fonts/hello-headline.woff2`, `static/fonts/open-sans-regular.woff2`, `static/fonts/open-sans-bold.woff2`, `static/sounds/muy-bien.mp3`, `static/sounds/poster-completo.mp3`, `static/icons/apple-touch-icon.png`, `static/icons/icon-512.png`

Downloads go to a fresh temp dir (untrusted data); nothing in it is executed.

- [ ] **Step 1: Download the poster and fonts**

```bash
cd /Users/grillermo/c/bbsharp
DL=$(mktemp -d)
curl -fsSL -o "$DL/poster.png" https://www.bluey.tv/wp-content/uploads/2024/10/full.png
curl -fsSL -A "Mozilla/5.0" -o "$DL/hello-headline.woff2" https://www.bluey.tv/wp-content/themes/bbc-bluey/assets/fonts/hello-headline/hello-headline.woff2
curl -fsSL -A "Mozilla/5.0" -o "$DL/open-sans-regular.woff2" https://www.bluey.tv/wp-content/themes/bbc-bluey/assets/fonts/open-sans/open-sans-regular.woff2
curl -fsSL -A "Mozilla/5.0" -o "$DL/open-sans-bold.woff2" https://www.bluey.tv/wp-content/themes/bbc-bluey/assets/fonts/open-sans/open-sans-bold.woff2
file "$DL"/*
echo "$DL"
```

Expected: `poster.png: PNG image data, 2000 x 1508`, and the three fonts reported as `Web Open Font Format (Version 2)`. If a font is HTML (a 403 page), stop and report.

- [ ] **Step 2: Install them into `static/`**

```bash
cd /Users/grillermo/c/bbsharp
mkdir -p static/posters static/sounds static/icons
magick "$DL/poster.png" -strip -quality 85 static/posters/bluey-todos.jpg
cp "$DL/hello-headline.woff2" "$DL/open-sans-regular.woff2" "$DL/open-sans-bold.woff2" static/fonts/
cat > static/posters/posters.json <<'EOF'
[
  { "file": "bluey-todos.jpg", "title": "Todos los amigos de Bluey" }
]
EOF
magick identify static/posters/bluey-todos.jpg
```

Expected: `bluey-todos.jpg JPEG 2000x1508 ...`, roughly 0.5–1 MB.

- [ ] **Step 3: Generate the reward sounds (chime + Spanish voice)**

```bash
cd /Users/grillermo/c/bbsharp
SND=$(mktemp -d)
ffmpeg -y -loglevel error \
  -f lavfi -i "sine=frequency=523.25:duration=0.15" \
  -f lavfi -i "sine=frequency=659.25:duration=0.15" \
  -f lavfi -i "sine=frequency=783.99:duration=0.15" \
  -f lavfi -i "sine=frequency=1046.5:duration=0.45" \
  -filter_complex "[0][1][2][3]concat=n=4:v=0:a=1,afade=t=out:st=0.6:d=0.3,volume=0.5,aresample=44100,aformat=channel_layouts=mono" \
  "$SND/chime.wav"
say -v Paulina -o "$SND/muy-bien.aiff" "¡Muy bien, Elisa!"
say -v Paulina -o "$SND/completo.aiff" "¡Lo lograste, Elisa! ¡Terminaste el póster!"
for pair in "muy-bien:muy-bien" "completo:poster-completo"; do
  in=${pair%%:*}; out=${pair##*:}
  ffmpeg -y -loglevel error -i "$SND/chime.wav" -i "$SND/$in.aiff" \
    -filter_complex "[1:a]aresample=44100,aformat=channel_layouts=mono[v];[0:a][v]concat=n=2:v=0:a=1" \
    -codec:a libmp3lame -b:a 96k "static/sounds/$out.mp3"
done
ffprobe -v error -show_entries format=duration -of csv=p=0 static/sounds/muy-bien.mp3 static/sounds/poster-completo.mp3
```

Expected: two durations, about 2 s and 4 s. If `say -v Paulina` fails, list voices with `say -v '?' | grep es_MX` and use the first es_MX voice. Play both to check: `afplay static/sounds/muy-bien.mp3`.

- [ ] **Step 4: Make the home-screen icons from the poster's center logo**

```bash
cd /Users/grillermo/c/bbsharp
magick static/posters/bluey-todos.jpg -crop 560x560+720+470 +repage -resize 512x512 static/icons/icon-512.png
magick static/icons/icon-512.png -resize 180x180 static/icons/apple-touch-icon.png
```

Open `static/icons/icon-512.png` (Read tool) and check that the white "BLUEY" logo with characters around it fills the square. If it is off-center, adjust the `+X+Y` offsets (the logo sits near the poster center, about x=850–1150, y=690–810) and rerun.

- [ ] **Step 5: Commit**

```bash
cd /Users/grillermo/c/bbsharp
git add static/posters static/fonts/hello-headline.woff2 static/fonts/open-sans-regular.woff2 static/fonts/open-sans-bold.woff2 static/sounds static/icons
git commit -m "Add Bluey poster, fonts, reward sounds and icons"
```

---

### Task 2: Poster reveal rules (`poster.ts`, TDD)

**Files:**
- Create: `src/ts/poster.ts`
- Test: `tests/unit/poster.test.ts`

- [ ] **Step 1: Write the failing tests**

`tests/unit/poster.test.ts`:

```ts
import { describe, it, expect } from 'vitest';
import {
    TILE_COUNT, TRIES_PER_TILE, newPosterState, recordTry, startNextPoster, parsePosterState,
    PosterState,
} from '../../src/ts/poster';

function tryTimes(state: PosterState, times: number) {
    let result = { state, revealedTile: null as number | null, completed: false };
    for (let i = 0; i < times; i++) result = recordTry(result.state);
    return result;
}

describe('recordTry', () => {
    it('reveals nothing before the 5th try and one tile on it', () => {
        const before = tryTimes(newPosterState(), TRIES_PER_TILE - 1);
        expect(before.revealedTile).toBeNull();
        expect(before.state.revealed).toEqual([]);

        const fifth = recordTry(before.state);
        expect(fifth.revealedTile).not.toBeNull();
        expect(fifth.state.revealed).toEqual([fifth.revealedTile]);
        expect(fifth.state.triesTowardNext).toBe(0);
    });

    it('uncovers every tile exactly once and reports completion on the last', () => {
        let state = newPosterState();
        const seen: number[] = [];
        for (let tile = 0; tile < TILE_COUNT; tile++) {
            const result = tryTimes(state, TRIES_PER_TILE);
            seen.push(result.revealedTile!);
            expect(result.completed).toBe(tile === TILE_COUNT - 1);
            state = result.state;
        }
        expect(new Set(seen).size).toBe(TILE_COUNT);
        expect(seen.every(t => t >= 0 && t < TILE_COUNT)).toBe(true);
    });

    it('reveals nothing more once the poster is complete', () => {
        const full: PosterState = {
            posterIndex: 0, triesTowardNext: TRIES_PER_TILE - 1,
            revealed: Array.from({ length: TILE_COUNT }, (_, i) => i),
        };
        const result = recordTry(full);
        expect(result.revealedTile).toBeNull();
        expect(result.completed).toBe(true);
    });
});

describe('startNextPoster', () => {
    it('moves to the next poster with nothing revealed, wrapping after the last', () => {
        const done: PosterState = { posterIndex: 1, revealed: [3, 4], triesTowardNext: 2 };
        expect(startNextPoster(done, 3)).toEqual({ posterIndex: 2, revealed: [], triesTowardNext: 0 });
        expect(startNextPoster(done, 2)).toEqual({ posterIndex: 0, revealed: [], triesTowardNext: 0 });
    });
});

describe('parsePosterState', () => {
    it('starts fresh when nothing is stored or the JSON is corrupt', () => {
        expect(parsePosterState(null, 1)).toEqual(newPosterState());
        expect(parsePosterState('{not json', 1)).toEqual(newPosterState());
        expect(parsePosterState('"a string"', 1)).toEqual(newPosterState());
    });

    it('drops unknown and duplicate tiles and out-of-range counters', () => {
        const raw = JSON.stringify({ posterIndex: 0, revealed: [5, 5, -1, TILE_COUNT, 2.5, 'x', 7], triesTowardNext: 99 });
        expect(parsePosterState(raw, 1)).toEqual({ posterIndex: 0, revealed: [5, 7], triesTowardNext: 0 });
    });

    it('starts fresh when the stored poster no longer exists', () => {
        const raw = JSON.stringify({ posterIndex: 4, revealed: [1, 2], triesTowardNext: 3 });
        expect(parsePosterState(raw, 2)).toEqual(newPosterState());
    });
});
```

- [ ] **Step 2: Run them to verify they fail**

Run: `npx vitest run tests/unit/poster.test.ts`
Expected: FAIL, `Failed to resolve import "../../src/ts/poster"`.

- [ ] **Step 3: Implement `src/ts/poster.ts`**

```ts
// Poster reveal rules for Elisa: every TRIES_PER_TILE answers uncover one random tile.
// Pure functions only; reward.ts owns the DOM and localStorage.

export const GRID_COLS = 12;
export const GRID_ROWS = 9;
export const TILE_COUNT = GRID_COLS * GRID_ROWS;
export const TRIES_PER_TILE = 5;

export interface PosterState {
    posterIndex: number;
    revealed: number[];
    triesTowardNext: number;
}

export interface TryResult {
    state: PosterState;
    revealedTile: number | null;
    completed: boolean;
}

export function newPosterState(posterIndex = 0): PosterState {
    return { posterIndex, revealed: [], triesTowardNext: 0 };
}

function isTile(value: unknown): value is number {
    return Number.isInteger(value) && (value as number) >= 0 && (value as number) < TILE_COUNT;
}

export function recordTry(state: PosterState, rng: () => number = Math.random): TryResult {
    const revealed = new Set(state.revealed);
    if (revealed.size >= TILE_COUNT) {
        return { state, revealedTile: null, completed: true };
    }

    const tries = state.triesTowardNext + 1;
    if (tries < TRIES_PER_TILE) {
        return { state: { ...state, triesTowardNext: tries }, revealedTile: null, completed: false };
    }

    const covered: number[] = [];
    for (let i = 0; i < TILE_COUNT; i++) {
        if (!revealed.has(i)) covered.push(i);
    }
    const tile = covered[Math.floor(rng() * covered.length)];
    const next = { ...state, revealed: [...state.revealed, tile], triesTowardNext: 0 };
    return { state: next, revealedTile: tile, completed: next.revealed.length === TILE_COUNT };
}

export function startNextPoster(state: PosterState, posterCount: number): PosterState {
    return newPosterState((state.posterIndex + 1) % posterCount);
}

export function parsePosterState(raw: string | null, posterCount: number): PosterState {
    let data: unknown;
    try {
        data = raw === null ? null : JSON.parse(raw);
    } catch {
        return newPosterState();
    }
    if (data === null || typeof data !== 'object') return newPosterState();

    const d = data as Record<string, unknown>;
    const index = d.posterIndex;
    if (!Number.isInteger(index) || (index as number) < 0 || (index as number) >= posterCount) {
        return newPosterState();
    }

    const revealed = Array.isArray(d.revealed) ? [...new Set(d.revealed.filter(isTile))] : [];
    const tries = d.triesTowardNext;
    const triesTowardNext = Number.isInteger(tries) && (tries as number) >= 0 && (tries as number) < TRIES_PER_TILE
        ? tries as number
        : 0;
    return { posterIndex: index as number, revealed, triesTowardNext };
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npx vitest run tests/unit/poster.test.ts && npx tsc --noEmit`
Expected: 7 tests pass; `tsc` prints nothing.

- [ ] **Step 5: Commit**

```bash
git add src/ts/poster.ts tests/unit/poster.test.ts
git commit -m "Add poster reveal rules"
```

---

### Task 3: Spanish UI, default profile "Elisa", no sad faces

**Files:**
- Modify: `src/index.html`, `src/ts/onboarding.ts:18-20,86-88`, `src/ts/ui.ts:582-658,700`, `src/ts/state.ts:131,141`, `src/ts/stats.ts:85-96`
- Test: `tests/ui/onboarding.spec.ts`, `tests/ui/profile.spec.ts`

- [ ] **Step 1: Update the UI tests to the Spanish behavior (they will fail)**

In `tests/ui/onboarding.spec.ts`, replace every expected string (use `sd -F`):

```bash
sd -F '"Click the play button to hear the sound"' '"Toca el botón ▶ para escuchar"' tests/ui/onboarding.spec.ts
sd -F '"Guess the color"' '"Adivina el color"' tests/ui/onboarding.spec.ts
sd -F '"Great job! Click the arrow to continue"' '"¡Muy bien! Toca la flecha para seguir"' tests/ui/onboarding.spec.ts
sd -F '"Click the arrow to try again"' '"Toca la flecha para intentarlo otra vez"' tests/ui/onboarding.spec.ts
```

In `tests/ui/profile.spec.ts`:

```bash
sd -F 'dialog.message().includes("already exists")' 'dialog.message().includes("Ya existe")' tests/ui/profile.spec.ts
sd -F 'test("deleting profile switches back to Guest"' 'test("deleting profile switches back to Elisa"' tests/ui/profile.spec.ts
sd -F 'await expect(page.locator("#profile-text")).toHaveText("Guest");' 'await expect(page.locator("#profile-text")).toHaveText("Elisa");' tests/ui/profile.spec.ts
```

- [ ] **Step 2: Run them to verify they fail**

Run: `make build && npx playwright test --config tests/playwright.config.ts tests/ui/onboarding.spec.ts tests/ui/profile.spec.ts`
Expected: the text assertions FAIL (received the English strings / "Guest").

- [ ] **Step 3: Translate the TS strings**

`src/ts/onboarding.ts`:

```ts
const STEP_CONFIG: Record<string, { text: string; arrow: boolean }> = {
    play: { text: 'Toca el botón ▶ para escuchar', arrow: true },
    guess: { text: 'Adivina el color', arrow: false },
    goNext: { text: '', arrow: false },
};
```

and

```ts
        const text = isCorrect
            ? '¡Muy bien! Toca la flecha para seguir'
            : 'Toca la flecha para intentarlo otra vez';
```

`src/ts/ui.ts` — replace each string exactly:

| Old | New |
|---|---|
| `'Must specify a profile name and icon.'` | `'Escribe un nombre y elige un ícono.'` |
| `'A profile with the name ' + newProfileValues.name + ' already exists.'` | `'Ya existe un perfil llamado ' + newProfileValues.name + '.'` |
| `'Target number must be a valid integer, got ' + newProfileValues.target_number` | `'La meta debe ser un número entero; recibí: ' + newProfileValues.target_number` |
| `'The name ' + profileValues.name + ' is taken, please choose another one.'` | `'El nombre ' + profileValues.name + ' ya está en uso; elige otro.'` |
| `'Must specify an icon!'` | `'¡Elige un ícono!'` |
| `'Must specify a valid target number, got: ' + profileValues.target_number` | `'La meta debe ser un número válido; recibí: ' + profileValues.target_number` |
| `'Deleting the guest user is not allowed.'` | `'No se puede borrar el perfil principal.'` |
| `'Are you sure you want to delete the profile ' + STATE.profiles[profileId].name + '?'` | `'¿Seguro que quieres borrar el perfil ' + STATE.profiles[profileId].name + '?'` |
| `'No sessions recorded yet.'` | `'Todavía no hay sesiones.'` |

`src/ts/state.ts` lines 131 and 141 — the default profile is Elisa:

```ts
        newProfiles[GUEST_USER_ID] = newProfile('Elisa', 'fa-paw', GUEST_USER_ID);
```

`src/ts/stats.ts` — no sad or scared faces (5 = wrong answer, 6 = right answer, 0–4 = session average):

```ts
export function getCatEmoji(level: number): string {
    const emojiLevels: Record<number, string> = {
        0: '\u{1F436}',
        1: '\u{1F436}',
        2: '\u{1F436}',
        3: '\u{1F415}',
        4: '\u{1F60A}',
        5: '\u{1F914}',
        6: '\u{1F973}',
    };
    return emojiLevels[level];
}
```

- [ ] **Step 4: Translate `src/index.html`**

Head:

```html
<html lang="es">
    <head>
        <title>Elisa aprende música</title>
```

and `<meta http-equiv="Content-Language" content="es">`, `<meta name="description" content="Elisa aprende a reconocer acordes por color.">`.

Replace the whole `#i-infobox` contents (keep both `href`s; `tests/integration/links.spec.ts` checks them):

```html
                <p>Esta app usa el <a href="https://www.ganbar.us/documents/sakakibara_2012_chord_identification.pdf">método de identificación de acordes de Eguchi</a>. Ver también <a href="https://ichionkai.co.jp/english3.html">Ichionkai Music School</a>.</p>
                <p><a href="https://youtu.be/kNfkm6PQC20">Video corto (en inglés) de cómo se usa</a>.</p>
                <p>Es un método para enseñar oído absoluto a niños de 2 a 6 años. Practiquen unas 5 veces al día, 2–3 minutos cada vez (unas 20–25 respuestas). Los acordes siempre se identifican con colores, en este orden: <span onclick="trigger_easter_egg()">rojo</span> (Do Mi Sol), amarillo (Do Fa La), azul (Si Re Sol), negro (La Do Fa), verde (Re Sol Si), naranja (Mi Sol Do), morado (Fa La Do), rosa (Sol Si Re), café (Sol Do Mi).</p>
                <p>Presenten los acordes uno por uno, con al menos 2 semanas entre cada acorde nuevo. No agreguen un acorde nuevo hasta que identifique todos los actuales con 100% de aciertos.</p>
```

Settings panel labels and options:

| Old | New |
|---|---|
| `Profile Name:` | `Nombre:` |
| `Icon:` | `Ícono:` |
| `Show chord names:` | `Mostrar notas del acorde:` |
| `>Always<` (show chord names) / `>Black chords only<` / `>Never<` | `>Siempre<` / `>Solo acordes negros<` / `>Nunca<` |
| `Reveal mode:` | `Mostrar notas:` |
| `>Always on<` / `>Reveal after guess<` | `>Siempre<` / `>Después de adivinar<` |
| `Chord name display:` | `Formato de notas:` |
| `>Shapes and Letters<` / `>Shapes only<` / `>Letters only<` | `>Figuras y letras<` / `>Solo figuras<` / `>Solo letras<` |
| `Persist Reaction Face:` | `Mantener carita:` |
| `Enable Onboarding Hints:` | `Mostrar ayudas:` |
| `Target Number:` | `Meta por sesión:` |
| `Color scheme:` | `Tema:` |
| `Chord selection:` | `Elección de acordes:` |
| `>Random<` / `>Adaptive<` | `>Al azar<` / `>Adaptativa<` |
| `Pin screen:` | `Fijar pantalla:` |
| `>Delete Profile<` / `>Save Changes<` / `>Add Profile<` | `>Borrar perfil<` / `>Guardar<` / `>Agregar perfil<` |

Chord level selector (`#chord-selector`), whole contents:

```html
            <optgroup label="Acordes blancos">
                <option value="red" hidden>Nivel 0: Rojo (Do Mi Sol)</option>
                <option value="yellow">Nivel 1: Amarillo (Do Fa La)</option>
                <option value="blue">Nivel 2: Azul (Si Re Sol)</option>
                <option value="black">Nivel 3: Negro (La Do Fa)</option>
                <option value="green">Nivel 4: Verde (Re Sol Si)</option>
                <option value="orange">Nivel 5: Naranja (Mi Sol Do)</option>
                <option value="purple">Nivel 6: Morado (Fa La Do)</option>
                <option value="pink">Nivel 7: Rosa (Sol Si Re)</option>
                <option value="brown">Nivel 8: Café (Sol Do Mi)</option>
            </optgroup>
            <optgroup label="Acordes negros">
                <option value="gray">Nivel 1: Gris (La Do&#x266F; Mi)</option>
                <option value="tan">Nivel 2: Beige (Re Fa&#x266F; La)</option>
                <option value="lightgreen">Nivel 3: Verde claro (Mi Sol&#x266F; Si)</option>
                <option value="lightpurple">Nivel 4: Lila (Si&#x266D; Re Fa)</option>
                <option value="skyblue">Nivel 5: Celeste (Mi&#x266D; Sol Si&#x266D;)</option>
            </optgroup>
```

Replace the screen-pinning modal's paragraphs and lists (Android instructions) with iPad Guided Access, keeping the OK button:

```html
            <p><strong>Acceso guiado</strong> deja el iPad fijo en esta app para que Elisa no pueda salirse.</p>
            <p><strong>Actívalo:</strong></p>
            <ol>
                <li>Abre <strong>Ajustes &gt; Accesibilidad &gt; Acceso guiado</strong> y actívalo.</li>
                <li>En <strong>Ajustes de código</strong>, define un código.</li>
            </ol>
            <p><strong>Úsalo:</strong></p>
            <ol>
                <li>Abre la app y presiona tres veces el botón superior.</li>
                <li>Toca <strong>Iniciar</strong>.</li>
            </ol>
            <p><strong>Para salir:</strong> presiona tres veces el botón superior e ingresa el código.</p>
```

Then check nothing English is left that a user sees:

Run: `grep -nE '>[^<]*\b(the|and|Profile|Level|Settings|Click)\b[^<]*<' src/index.html`
Expected: no output (HTML comments are fine).

- [ ] **Step 5: Run the tests to verify they pass**

Run: `make build && npx playwright test --config tests/playwright.config.ts && npx vitest run`
Expected: all pass. `theme.spec.ts` still passes here; it changes in Task 4.

- [ ] **Step 6: Commit**

```bash
git add src tests/ui
git commit -m "Translate UI to Spanish and default profile to Elisa"
```

---

### Task 4: bluey.tv theme, title card, gear menu

**Files:**
- Create: `src/scss/_bluey.scss`
- Modify: `src/scss/style.scss`, `src/index.html`, `src/ts/ui.ts:302-311`, `src/ts/state.ts:24`
- Test: `tests/ui/theme.spec.ts`, `tests/ui/settings.spec.ts`

The app is always in the light theme, which `_bluey.scss` restyles. The dark/light setting is gone, so its tests are deleted.

- [ ] **Step 1: Remove the tests for the removed theme setting**

In `tests/ui/theme.spec.ts`, delete the tests `app starts in dark mode` and `color scheme setting persists across profile switch`; keep `download button hidden by default`. In `tests/ui/settings.spec.ts`, delete the test that selects `#color-scheme-selector` (around line 125–140). Then add to `tests/ui/theme.spec.ts`:

```ts
test("shows Elisa's title", async ({ page }) => {
  await expect(page.locator(".title-card h1")).toHaveText("Elisa aprende música");
});
```

Run: `make build && npx playwright test --config tests/playwright.config.ts tests/ui/theme.spec.ts`
Expected: FAIL, `.title-card h1` not found.

- [ ] **Step 2: Force the light theme**

`src/ts/ui.ts`:

```ts
export function applyColorScheme(_scheme: string): void {
    // Elisa edition: always the bluey.tv light theme.
    document.body.classList.remove('colorscheme-dark');
    document.body.classList.add('colorscheme-light');
}
```

`src/ts/state.ts`: `export const DEFAULT_COLOR_SCHEME = 'light';`

`src/index.html`: `<body class="colorscheme-light">`, and hide the theme row (ui.ts still reads the select) by changing its wrapper to `<div class="entry-row" hidden>`.

- [ ] **Step 3: Title card, gear icon, level selector in settings**

In `src/index.html`:

1. Right after `<div class="cim-container">` and before `<div class="menu-container" ...>`, add:

```html
        <header class="title-card"><h1>Elisa aprende música</h1></header>
```

2. In `#hamburger-link`, change `<i class="fa fa-bars"></i>` to `<i class="fa fa-cog"></i>`.

3. Move the whole `<div class="selectors">…</div>` block (the `#chord-selector`) from the main screen into `#profile-info-container`, directly after `<div id="profile-switcher"></div>`, wrapped as a settings row:

```html
                <div class="entry-row">
                    <label for="chord-selector">Nivel:</label>
                    <div class="selectors">
                        <!-- the unchanged <select id="chord-selector"> … </select> -->
                    </div>
                </div>
```

(Paste the real `<select>` from Task 3; the comment only marks where it goes.) `tests/ui/chord-selector.spec.ts` uses `#chord-selector` directly; if it now fails because the select is hidden, add `await openProfilePanel(page);` from `./helpers` before the interaction in each failing test.

- [ ] **Step 4: Write `src/scss/_bluey.scss` and import it**

`src/scss/style.scss` — add as the last line: `@import "bluey";`

`src/scss/_bluey.scss`:

```scss
// Elisa aprende música: bluey.tv look. Imported last so it wins over _theme/_cim.

@font-face {
    font-family: "hello";
    src: url("static/fonts/hello-headline.woff2") format("woff2");
    font-display: swap;
}
@font-face {
    font-family: "open-sans";
    font-weight: normal;
    src: url("static/fonts/open-sans-regular.woff2") format("woff2");
}
@font-face {
    font-family: "open-sans";
    font-weight: bold;
    src: url("static/fonts/open-sans-bold.woff2") format("woff2");
}

$bluey-ink: #5a5a87;
$bluey-ink-pressed: #4e4e7a;
$bluey-lavender: #d8d7f8;
$bluey-edge: #abe0fa;
$bluey-sky-top: #8fd3fb;
$bluey-sky-bottom: #c2e3fe;
$bluey-grass: #dbe98a;
$bluey-yellow: #ffca3a;
$bluey-coral: #f86468;
$bluey-mint: #77e0c7;
$headline: "hello", "open-sans", "arial", sans-serif;

body.colorscheme-light {
    font-family: "open-sans", "arial", sans-serif;
    color: $bluey-ink;
    min-height: 100vh;
    background:
        radial-gradient(ellipse 22% 6% at 18% 9%, #fff 60%, transparent 62%),
        radial-gradient(ellipse 18% 5% at 80% 18%, #fff 60%, transparent 62%),
        radial-gradient(ellipse 14% 4% at 55% 4%, #fff 60%, transparent 62%),
        linear-gradient(to bottom, $bluey-sky-top 0%, $bluey-sky-bottom 78%, $bluey-grass 78%, darken($bluey-grass, 12%) 100%);
    background-attachment: fixed;
}

body.colorscheme-light a { color: $bluey-ink; }

.title-card {
    width: fit-content;
    max-width: 90%;
    margin: 4px auto 20px;
    padding: 10px 28px 14px;
    background: #fff;
    border-radius: 28px;
    box-shadow: 0 0 0 8px $bluey-edge;
    transform: rotate(-3deg);
    text-align: center;

    h1 {
        margin: 0;
        font-family: $headline;
        font-weight: normal;
        font-size: clamp(30px, 7vw, 56px);
        line-height: 1.1;
        color: $bluey-ink;
    }
}

// Round play / next buttons.
body.colorscheme-light div.controls a {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 104px;
    height: 104px;
    margin: 0 14px;
    border-radius: 50%;
    background: $bluey-ink;
    box-shadow: 0 6px 0 $bluey-ink-pressed, 0 12px 20px rgba(0, 0, 0, 0.15);
    transition: transform 0.08s, box-shadow 0.08s;

    &:active {
        transform: translateY(4px);
        box-shadow: 0 2px 0 $bluey-ink-pressed;
    }
    &.deactivated { opacity: 0.35; }
}
body.colorscheme-light div.controls i.fa,
body.colorscheme-light div.controls a.deactivated i.fa {
    color: #fff;
    font-size: 48px;
}

// Flags: rounded, chunky.
#flag-holder .flag {
    border-radius: 22px;
    box-shadow: 0 5px 0 rgba(0, 0, 0, 0.15);
}

// Gear (settings) button: white circle.
div.hamburger a {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 56px;
    height: 56px;
    border-radius: 50%;
    background: #fff;
    color: $bluey-ink;
    box-shadow: 0 4px 10px rgba(0, 0, 0, 0.15);
}

// Panels (settings, info, history) as white cards.
#panel-area > .panel {
    background: #fff;
    color: $bluey-ink;
    border-radius: 28px;
    box-shadow: 0 0 0 6px $bluey-edge;
    padding: 20px;
}

// Pill buttons.
body.colorscheme-light .button {
    font-family: $headline;
    font-size: 20px;
    color: #fff;
    background: $bluey-ink;
    border: none;
    border-radius: 999px;
    padding: 10px 24px;

    &:active { background: $bluey-ink-pressed; }
}

// Things a 4-year-old should not see on the main screen.
#stats-container .percent,
#stats-container .stats-divider,
#stats-container #stats-total,
#reset-button,
.mode-toggle-container {
    display: none;
}

#onboarding-overlay {
    font-family: $headline;
    color: $bluey-ink;
}
```

If a rule has no visible effect because `_cim.scss` uses a more specific selector (check in the browser devtools), raise specificity by prefixing `body.colorscheme-light` rather than adding `!important`.

- [ ] **Step 5: Check it visually at iPad mini size**

```bash
cd /Users/grillermo/c/bbsharp && make build
npx http-server dist -p 8080 -c-1 --silent &
SERVER=$!
sleep 1
npx playwright screenshot --viewport-size=744,1133 http://localhost:8080 /tmp/elisa-main.png
npx playwright screenshot --viewport-size=1133,744 http://localhost:8080 /tmp/elisa-landscape.png
kill $SERVER
```

Open both PNGs with the Read tool. Check: sky background, tilted white title card in the hello font, two slate round buttons, rounded flags fully on screen in both orientations, a white gear button. Fix and rerun until true.

- [ ] **Step 6: Run the tests and commit**

Run: `make build && npx playwright test --config tests/playwright.config.ts && npx vitest run`
Expected: all pass.

```bash
git add src tests/ui
git commit -m "Add bluey.tv theme, title card and gear menu"
```

---

### Task 5: Reward flow (`reward.ts`)

**Files:**
- Create: `src/ts/reward.ts`, `tests/ui/reward.spec.ts`
- Modify: `src/index.html`, `src/ts/game.ts:1-12,135`, `src/ts/main.ts`, `src/scss/_bluey.scss`

- [ ] **Step 1: Write the failing UI tests**

`tests/ui/reward.spec.ts`:

```ts
import { test, expect, Page } from "@playwright/test";

async function answer(page: Page, first: boolean): Promise<void> {
  // The next button auto-plays the following chord; the play button starts the first one.
  await page.locator(first ? "#play-button" : "#next-chord").click();
  await page.waitForTimeout(1000);
  await page.locator("#red-flag").click();
}

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => localStorage.clear());
});

test("every fifth answer, right or wrong, uncovers one poster tile", async ({ page }) => {
  await page.goto("/");
  for (let i = 0; i < 4; i++) {
    await answer(page, i === 0);
    await expect(page.locator("#poster-overlay")).not.toHaveClass(/visible/);
  }
  await answer(page, false);

  await expect(page.locator("#poster-overlay")).toHaveClass(/visible/);
  await expect(page.locator("#poster-message")).toHaveText("¡Muy bien, Elisa!");
  await expect(page.locator("#poster-tiles .poster-tile.revealed")).toHaveCount(1);
  const saved = await page.evaluate(() => JSON.parse(localStorage.getItem("elisa_poster")!));
  expect(saved.revealed).toHaveLength(1);
  expect(saved.triesTowardNext).toBe(0);
});

test("a wrong answer shows encouragement", async ({ page }) => {
  await page.addInitScript(() => {
    (window as any).__bsharp_test_deterministic_color = "yellow";
  });
  await page.goto("/");
  await answer(page, true);
  await expect(page.locator("#answer-feedback")).toHaveText("¡Inténtalo otra vez!");
});

test("the last tile throws a party and the next poster starts covered", async ({ page }) => {
  await page.addInitScript(() => {
    localStorage.setItem("elisa_poster", JSON.stringify({
      posterIndex: 0,
      revealed: Array.from({ length: 107 }, (_, i) => i),
      triesTowardNext: 4,
    }));
  });
  await page.goto("/");
  await answer(page, true);

  await expect(page.locator("#poster-overlay")).toHaveClass(/party/);
  await expect(page.locator("#poster-message")).toHaveText("¡Lo lograste, Elisa! ¡Terminaste el póster!");

  await page.locator("#poster-overlay").click();
  await expect(page.locator("#poster-overlay")).not.toHaveClass(/visible/);
  const saved = await page.evaluate(() => JSON.parse(localStorage.getItem("elisa_poster")!));
  expect(saved.revealed).toEqual([]);
});

test("tapping the thumbnail shows the poster so far", async ({ page }) => {
  await page.addInitScript(() => {
    localStorage.setItem("elisa_poster", JSON.stringify({ posterIndex: 0, revealed: [0, 1, 2], triesTowardNext: 0 }));
  });
  await page.goto("/");
  await page.locator("#poster-thumb").click();
  await expect(page.locator("#poster-overlay")).toHaveClass(/visible/);
  await expect(page.locator("#poster-tiles .poster-tile.revealed")).toHaveCount(3);
});
```

- [ ] **Step 2: Run them to verify they fail**

Run: `make build && npx playwright test --config tests/playwright.config.ts tests/ui/reward.spec.ts`
Expected: FAIL, `#poster-overlay` / `#poster-thumb` not found.

- [ ] **Step 3: Add the markup to `src/index.html`**

Inside `#stats-container`, as its first child (before `.emoji-container`):

```html
            <button type="button" id="poster-thumb" class="poster-thumb" onclick="open_poster()" aria-label="Ver el póster">
                <div class="poster-frame">
                    <img id="poster-thumb-img" alt="">
                    <div id="poster-thumb-tiles" class="poster-tiles"></div>
                </div>
                <svg class="progress-ring" viewBox="0 0 36 36" aria-hidden="true">
                    <circle class="ring-bg" cx="18" cy="18" r="16" pathLength="100"></circle>
                    <circle id="progress-ring-fill" class="ring-fill" cx="18" cy="18" r="16" pathLength="100"></circle>
                </svg>
            </button>
```

Just before `<script src="bsharp.js"></script>`:

```html
    <div id="answer-feedback" class="answer-feedback" aria-live="polite"></div>
    <div id="poster-overlay" class="poster-overlay" onclick="close_poster()">
        <div class="poster-card">
            <p id="poster-message" class="poster-message"></p>
            <div class="poster-frame">
                <img id="poster-img" alt="">
                <div id="poster-tiles" class="poster-tiles"></div>
            </div>
        </div>
        <div id="confetti" class="confetti"></div>
    </div>
    <audio id="cheer-audio" src="static/sounds/muy-bien.mp3" preload="auto"></audio>
    <audio id="party-audio" src="static/sounds/poster-completo.mp3" preload="auto"></audio>
```

- [ ] **Step 4: Implement `src/ts/reward.ts`**

```ts
// DOM side of Elisa's poster rewards: thumbnail + progress ring, reveal overlay,
// answer feedback, completion party. Rules live in poster.ts.
import {
    PosterState, GRID_COLS, GRID_ROWS, TILE_COUNT, TRIES_PER_TILE,
    recordTry, startNextPoster, parsePosterState,
} from './poster';

export const POSTER_STATE_KEY = 'elisa_poster';
const POSTERS_URL = 'static/posters/posters.json';
const FLIP_DELAY_MS = 500;
const FEEDBACK_MS = 1500;
const CONFETTI_PIECES = 80;
const CONFETTI_COLORS = ['#ffca3a', '#f86468', '#77e0c7', '#5a5a87', '#8fd3fb', '#ffffff'];

interface PosterInfo { file: string; title: string; }

let _posters: PosterInfo[] = [];
let _state: PosterState | null = null;
let _feedbackTimer: ReturnType<typeof setTimeout> | null = null;

function el<T extends HTMLElement = HTMLElement>(id: string): T {
    return document.getElementById(id) as T;
}

function saveState(): void {
    localStorage.setItem(POSTER_STATE_KEY, JSON.stringify(_state));
}

function posterUrl(): string {
    return 'static/posters/' + _posters[_state!.posterIndex].file;
}

function renderTiles(container: HTMLElement, flipTile: number | null): void {
    container.innerHTML = '';
    container.style.gridTemplateColumns = `repeat(${GRID_COLS}, 1fr)`;
    container.style.gridTemplateRows = `repeat(${GRID_ROWS}, 1fr)`;
    const revealed = new Set(_state!.revealed);
    for (let i = 0; i < TILE_COUNT; i++) {
        const tile = document.createElement('div');
        tile.className = 'poster-tile';
        if (revealed.has(i) && i !== flipTile) tile.classList.add('revealed');
        container.appendChild(tile);
        if (i === flipTile) {
            tile.classList.add('flipping');
            setTimeout(() => tile.classList.add('revealed'), FLIP_DELAY_MS);
        }
    }
}

function renderThumb(): void {
    el<HTMLImageElement>('poster-thumb-img').src = posterUrl();
    renderTiles(el('poster-thumb-tiles'), null);
    const percent = (_state!.triesTowardNext / TRIES_PER_TILE) * 100;
    el('progress-ring-fill').setAttribute('stroke-dasharray', `${percent} 100`);
}

function playSound(id: string): void {
    const audio = el<HTMLAudioElement>(id);
    audio.currentTime = 0;
    audio.play().catch(() => { /* iOS refused: audio not primed yet */ });
}

function showPoster(message: string, flipTile: number | null): void {
    el('poster-message').textContent = message;
    el<HTMLImageElement>('poster-img').src = posterUrl();
    renderTiles(el('poster-tiles'), flipTile);
    el('poster-overlay').classList.add('visible');
}

function throwConfetti(): void {
    const confetti = el('confetti');
    confetti.innerHTML = '';
    for (let i = 0; i < CONFETTI_PIECES; i++) {
        const piece = document.createElement('span');
        piece.style.left = `${Math.random() * 100}%`;
        piece.style.background = CONFETTI_COLORS[i % CONFETTI_COLORS.length];
        piece.style.animationDelay = `${Math.random() * 1.5}s`;
        piece.style.animationDuration = `${2.5 + Math.random() * 2}s`;
        confetti.appendChild(piece);
    }
}

function showFeedback(isCorrect: boolean): void {
    const feedback = el('answer-feedback');
    feedback.textContent = isCorrect ? '¡Muy bien!' : '¡Inténtalo otra vez!';
    feedback.classList.add('visible');
    if (_feedbackTimer !== null) clearTimeout(_feedbackTimer);
    _feedbackTimer = setTimeout(() => feedback.classList.remove('visible'), FEEDBACK_MS);
}

export async function initRewards(): Promise<void> {
    try {
        const response = await fetch(POSTERS_URL);
        _posters = await response.json() as PosterInfo[];
    } catch {
        return; // No posters: the trainer still works, just without rewards.
    }
    if (_posters.length === 0) return;
    _state = parsePosterState(localStorage.getItem(POSTER_STATE_KEY), _posters.length);
    if (_state.revealed.length >= TILE_COUNT) {
        _state = startNextPoster(_state, _posters.length);
    }
    saveState();
    renderThumb();
}

export function onAnswer(isCorrect: boolean): void {
    showFeedback(isCorrect);
    if (_state === null) return;

    const result = recordTry(_state);
    _state = result.state;
    saveState();
    renderThumb();
    if (result.revealedTile === null) return;

    if (result.completed) {
        el('poster-overlay').classList.add('party');
        showPoster('¡Lo lograste, Elisa! ¡Terminaste el póster!', result.revealedTile);
        throwConfetti();
        playSound('party-audio');
    } else {
        showPoster('¡Muy bien, Elisa!', result.revealedTile);
        playSound('cheer-audio');
    }
}

export function openPoster(): void {
    if (_state === null) return;
    showPoster(_posters[_state.posterIndex].title, null);
}

export function closePoster(): void {
    const overlay = el('poster-overlay');
    overlay.classList.remove('visible', 'party');
    el('confetti').innerHTML = '';
    if (_state !== null && _state.revealed.length >= TILE_COUNT) {
        _state = startNextPoster(_state, _posters.length);
        saveState();
        renderThumb();
    }
}

// iOS only plays audio started from a user gesture. Call this from the first tap
// so the reward sounds can play later without one.
export function primeRewardAudio(): void {
    for (const id of ['cheer-audio', 'party-audio']) {
        const audio = el<HTMLAudioElement>(id);
        audio.muted = true;
        audio.play()
            .then(() => { audio.pause(); audio.currentTime = 0; audio.muted = false; })
            .catch(() => { audio.muted = false; });
    }
}
```

- [ ] **Step 5: Hook it into the game and page**

`src/ts/game.ts` — add the import with the others:

```ts
import { onAnswer } from './reward';
```

and in `selectFlagWrapper()`, right after `const isCorrect = chosenColor === _CORRECT_COLOR;`:

```ts
    onAnswer(isCorrect);
```

`src/ts/main.ts` — add to the imports:

```ts
import { initRewards, openPoster, closePoster, primeRewardAudio } from './reward';
```

with the other window assignments:

```ts
w.open_poster = openPoster;
w.close_poster = closePoster;
```

and at the end of the `DOMContentLoaded` handler:

```ts
    void initRewards();
    document.getElementById('play-button')?.addEventListener('click', primeRewardAudio, { once: true });
```

- [ ] **Step 6: Style it — append to `src/scss/_bluey.scss`**

```scss
// --- Rewards ---

.poster-frame {
    position: relative;
    line-height: 0;

    img { width: 100%; height: auto; display: block; }
}

.poster-tiles {
    position: absolute;
    inset: 0;
    display: grid;
}

.poster-tile {
    background: $bluey-lavender;
    border: 1px solid #fff;
    transition: opacity 0.7s ease, transform 0.7s ease;

    &.flipping { background: $bluey-yellow; }
    &.revealed { opacity: 0; transform: rotateY(90deg) scale(0.6); }
}

.poster-thumb {
    position: relative;
    width: 120px;
    padding: 6px;
    border: none;
    border-radius: 18px;
    background: #fff;
    box-shadow: 0 0 0 5px $bluey-edge;
    transform: rotate(2deg);

    .poster-frame { border-radius: 10px; overflow: hidden; }
}

.progress-ring {
    position: absolute;
    right: -18px;
    top: -18px;
    width: 44px;
    height: 44px;
    transform: rotate(-90deg);

    circle { fill: none; stroke-width: 5; }
    .ring-bg { stroke: #fff; }
    .ring-fill { stroke: $bluey-coral; stroke-linecap: round; transition: stroke-dasharray 0.4s; }
}

.poster-overlay {
    position: fixed;
    inset: 0;
    z-index: 1000;
    display: none;
    align-items: center;
    justify-content: center;
    background: rgba(90, 90, 135, 0.55);

    &.visible { display: flex; }
}

.poster-card {
    width: min(92vw, 92vh * 1.33);
    padding: 16px;
    background: #fff;
    border-radius: 28px;
    box-shadow: 0 0 0 8px $bluey-edge;
    transform: rotate(-2deg);
    animation: poster-pop 0.4s ease-out;

    .poster-frame { border-radius: 16px; overflow: hidden; }
}

.poster-message {
    margin: 0 0 12px;
    font-family: $headline;
    font-size: clamp(28px, 6vw, 48px);
    text-align: center;
    color: $bluey-ink;
}

@keyframes poster-pop {
    from { transform: rotate(-2deg) scale(0.6); opacity: 0; }
    to { transform: rotate(-2deg) scale(1); opacity: 1; }
}

.answer-feedback {
    position: fixed;
    left: 50%;
    top: 22%;
    z-index: 900;
    padding: 10px 26px;
    font-family: $headline;
    font-size: 36px;
    color: $bluey-ink;
    background: #fff;
    border-radius: 999px;
    box-shadow: 0 0 0 6px $bluey-edge;
    transform: translateX(-50%) rotate(-3deg);
    opacity: 0;
    pointer-events: none;
    transition: opacity 0.2s;

    &.visible { opacity: 1; }
}

.confetti {
    position: absolute;
    inset: 0;
    overflow: hidden;
    pointer-events: none;

    span {
        position: absolute;
        top: -20px;
        width: 12px;
        height: 18px;
        border-radius: 3px;
        animation-name: confetti-fall;
        animation-timing-function: linear;
        animation-iteration-count: infinite;
    }
}

@keyframes confetti-fall {
    to { transform: translateY(110vh) rotate(720deg); }
}
```

- [ ] **Step 7: Run all tests**

Run: `npx tsc --noEmit && make build && npx playwright test --config tests/playwright.config.ts && npx vitest run`
Expected: all pass, including the 4 new reward tests.

- [ ] **Step 8: Commit**

```bash
git add src tests/ui/reward.spec.ts
git commit -m "Reveal a poster tile every 5 answers"
```

---

### Task 6: iPad home-screen web app + iPad test device + screenshots

**Files:**
- Create: `static/manifest.webmanifest`, `tests/screenshot/elisa.spec.ts`
- Modify: `src/index.html` (head), `src/scss/_bluey.scss`, `tests/device.ts`

- [ ] **Step 1: Manifest**

`static/manifest.webmanifest`:

```json
{
  "name": "Elisa aprende música",
  "short_name": "Elisa",
  "lang": "es",
  "start_url": "/",
  "scope": "/",
  "display": "standalone",
  "background_color": "#8fd3fb",
  "theme_color": "#8fd3fb",
  "icons": [
    { "src": "icons/apple-touch-icon.png", "sizes": "180x180", "type": "image/png" },
    { "src": "icons/icon-512.png", "sizes": "512x512", "type": "image/png" }
  ]
}
```

- [ ] **Step 2: Head tags in `src/index.html`**

Replace the viewport meta and add the rest after it:

```html
        <meta name="viewport"
              content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=0, viewport-fit=cover">
        <meta name="apple-mobile-web-app-capable" content="yes">
        <meta name="mobile-web-app-capable" content="yes">
        <meta name="apple-mobile-web-app-status-bar-style" content="default">
        <meta name="apple-mobile-web-app-title" content="Elisa">
        <meta name="theme-color" content="#8fd3fb">
        <link rel="apple-touch-icon" href="static/icons/apple-touch-icon.png">
        <link rel="manifest" href="static/manifest.webmanifest">
        <link rel="preload" href="static/fonts/hello-headline.woff2" as="font" type="font/woff2" crossorigin="">
```

Change `<meta name="color-scheme" content="light dark">` to `content="light"`.

- [ ] **Step 3: No accidental zoom, selection or bounce — append to `_bluey.scss`**

```scss
// --- iPad: behave like an app ---
html {
    touch-action: manipulation;
    -webkit-text-size-adjust: 100%;
}
body {
    -webkit-user-select: none;
    user-select: none;
    -webkit-touch-callout: none;
    overscroll-behavior: none;
    padding-top: env(safe-area-inset-top);
}
input, select { -webkit-user-select: auto; user-select: auto; }
```

- [ ] **Step 4: Test as an iPad mini**

`tests/device.ts`:

```ts
import { devices } from "@playwright/test";

// iPad mini (6th gen) in portrait, run in Chromium (the projects are chromium-only).
export const DEVICE = {
  userAgent: devices["iPad Mini"].userAgent,
  viewport: { width: 744, height: 1133 },
  deviceScaleFactor: 2,
  isMobile: true,
  hasTouch: true,
};
```

Run: `make build && npx playwright test --config tests/playwright.config.ts`
Expected: all pass. If a test relied on the phone layout (for example the menu being collapsed), fix the test's setup, not the app.

- [ ] **Step 5: Screenshot tests**

`tests/screenshot/elisa.spec.ts` (init scripts rerun on every navigation, so each test registers its poster state before the single `goto`):

```ts
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
```

Run: `make test-screenshot-update`, then open the three PNGs under `tests/screenshot/elisa.spec.ts-snapshots/` with the Read tool and confirm each looks right (snapshots are gitignored; they are for local review). Then `make test-screenshot`. Expected: pass. Older screenshot specs (`flags`, `onboarding`, `stats`) get new baselines from the same update run.

- [ ] **Step 6: Commit**

```bash
git add static/manifest.webmanifest src tests/device.ts tests/screenshot/elisa.spec.ts
git commit -m "Make it an iPad home-screen app"
```

---

### Task 7: Deploy to bluey.chiq.me from the macmini

**Files:**
- Modify: `Makefile`, `/Users/grillermo/c/server/Caddyfile`, `/Users/grillermo/c/server/routes.yml` (via `./routes`)

Port 8096 was free on 2026-10-14; re-check in Step 2.

- [ ] **Step 1: `deploy` target in `Makefile`**

Add `deploy` to `.PHONY`, and below `serve`:

```make
DEPLOY_HOST := macmini
DEPLOY_DIR := c/elisa-www

deploy:
	rm -rf dist
	$(MAKE) build
	rsync -az --delete -e "ssh -o BatchMode=yes" dist/ $(DEPLOY_HOST):$(DEPLOY_DIR)/
```

Run: `command ssh -o BatchMode=yes -o ConnectTimeout=10 macmini 'mkdir -p ~/c/elisa-www' && make deploy && command ssh macmini 'ls ~/c/elisa-www'`
Expected: `bsharp.js  index.html  static  style.css`.

- [ ] **Step 2: Caddy site on the macmini**

Confirm the port is free: `grep -n ':8096' /Users/grillermo/c/server/Caddyfile /Users/grillermo/c/server/routes.yml` → no output. Then append to `/Users/grillermo/c/server/Caddyfile`:

```
# elisa — "Elisa aprende música" (~/c/bbsharp, deployed with `make deploy`). bluey.chiq.me points at :8096.
:8096 {
	root * /Users/grillermo/c/elisa-www
	file_server
	@html path / /index.html
	header @html Cache-Control "no-cache"
}
```

Commit it in `~/c/server` (git-sync carries it to the macmini), wait for it to arrive, then reload Caddy there:

```bash
cd /Users/grillermo/c/server && git add Caddyfile && git commit -m "Serve elisa-www on :8096"
command ssh macmini 'cd ~/c/server && grep -q ":8096" Caddyfile && ./reload'
command ssh macmini 'curl -sS -o /dev/null -w "%{http_code}\n" http://localhost:8096/'
```

Expected: `200`. If the grep fails, git-sync hasn't delivered yet; wait a minute and retry.

- [ ] **Step 3: Publish the route**

```bash
cd /Users/grillermo/c/server
./routes create bluey.chiq.me 8096 --tunnel macmini-production --dry-run
./routes create bluey.chiq.me 8096 --tunnel macmini-production
git add routes.yml && git commit -m "Route bluey.chiq.me to elisa on the macmini"
curl -sS -o /dev/null -w '%{http_code}\n' https://bluey.chiq.me/
```

Expected: the dry run lists only `bluey.chiq.me` changes, then `Done.`, then `200`. Stop and ask if the dry run shows any other change or `already has DNS A`.

- [ ] **Step 4: Commit the Makefile**

```bash
cd /Users/grillermo/c/bbsharp && git add Makefile && git commit -m "Add make deploy"
```

---

### Task 8: Docs for this fork

**Files:**
- Modify: `CLAUDE.md`, `README.md`, `TODO.md`, `docs/superpowers/specs/2026-10-14-bluey-edition-design.md`

- [ ] **Step 1: `CLAUDE.md`**

Change the title to `# Elisa aprende música (BSharp fork)` and add right under it:

```markdown
Private fork of BSharp for Elisa (age 4–5): Spanish UI, bluey.tv look, a Bluey poster revealed one
tile per 5 answers. Runs in Safari on an iPad mini at https://bluey.chiq.me (macmini, Caddy :8096).
Spec: docs/superpowers/specs/2026-10-14-bluey-edition-design.md. Upstream: `upstream` remote.
Bluey art and fonts are Ludo Studio / BBC property — never publish this to an app store.
```

In **Build**, replace the `make android-deploy` line with `make deploy  # Build + rsync dist/ to the macmini (bluey.chiq.me)`. In **Conventions**, replace "After any code change, run `make android-deploy`…" with "After a change Elisa should get, run `make deploy`." Delete the **Releases** section. In **Project Structure**, add `poster.ts  # Poster reveal rules (pure)` and `reward.ts  # Poster thumbnail, overlay, party` under `ts/`, and `_bluey.scss  # bluey.tv theme` under `scss/`, and `posters/  # posters.json + poster images` and `sounds/` under `static/`.

- [ ] **Step 2: `README.md`**

Replace the top (title through the first Play Store block) with:

```markdown
# Elisa aprende música

A private, Spanish, Bluey-themed fork of [BSharp](https://github.com/paytonjjones/bsharp), the
perfect-pitch chord trainer. Every 5 answers uncovers one tile of a Bluey poster.

To add a poster: put the image in `static/posters/`, add `{ "file": "...", "title": "..." }` to
`static/posters/posters.json`, and run `make deploy`.
```

Keep the "About the Eguchi Method" section and attribution.

- [ ] **Step 3: `TODO.md`**

Replace the whole file with:

```markdown
# Elisa aprende música TODO

## Features
- Add more posters to static/posters/ (one starts when the current one is finished)
```

- [ ] **Step 4: Spec signature fix**

In the spec's Architecture section, change `recordTry(state, posterCount, rng)` to `recordTry(state, rng)` (it never needed the poster count).

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md README.md TODO.md docs
git commit -m "Document the Elisa fork"
```

---

### Task 9: Try it on the iPad

- [ ] **Step 1:** On the iPad mini, open `https://bluey.chiq.me` in Safari → Share → **Agregar a pantalla de inicio**. Open it from the Home Screen: it must be full-screen with no Safari bars.
- [ ] **Step 2:** Tap ▶, answer 5 times. Expect the chime + "¡Muy bien, Elisa!" voice and one tile flipping. Rotate the iPad: the layout must still fit.
- [ ] **Step 3:** Report anything off to the user with a photo or screenshot; fixes follow the same TDD loop.
