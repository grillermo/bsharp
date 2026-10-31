# iOS Rewards Implementation Plan (Plan 3 of 5)

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A right answer shows a Bluey character with its name for 3 seconds, the streak fills an outline round the screen, and 20 in a row moves Elisa to the next level on the other instrument (piano → guitar → piano …), as in the web app plus the new instrument switch.

**Architecture:** Every rule stays in the tested `ElisaKit` package: `SavedProgress.levelUp` (next level + instrument switch + streak reset) and the `Game` value type, which now deals the character from a `CharacterDeck`, knows the streak, and ends the reveal with a level-up when one is due. The app target only draws it: a `StreakOutline` view (a trimmed path), a `CharacterReveal` view and the glue in `GameModel`/`HomeView`. XCUITests drive the flows through the launch arguments from Plan 2 plus a new `-ElisaStreak <n>`.

**Tech Stack:** Swift 6.2 / SwiftUI, iOS 17+, Swift Testing (ElisaKit), XCTest UI tests, XcodeGen, Xcode 26.3.

**Spec:** `SwiftApp/PLAN.md` step 8. Reference screenshots: `SwiftApp/Reference Material/screenshots/` (`state-04-correct-character-reveal`, `state-06-streak-05/10/15/19-of-20`, `state-07-after-level-up-to-azul`). The web app source (`src/ts/characters.ts`, `streak.ts`, `game.ts`, `src/scss/_bluey.scss`) is the behavior reference; where this plan and the TypeScript disagree, the TypeScript wins unless the plan says why.

**The five plans:**
1. Foundation (done): ElisaKit logic, skeleton app, OTA deploy, first install.
2. Playable game (done, shipped as 0.2.1): persistence and import, audio, game screen, note shapes.
3. **This plan — Rewards:** character reveal, streak outline, level-up with the instrument switch.
4. Menu and panels: gear menu, piano trainer, info text, stats history, profile settings (`PLAN.md` step 9).
5. iPad polish and switch-over: safe areas, idle timer, Guided Access, moving Elisa over (`PLAN.md` steps 10–11).

---

## Conventions for whoever executes this

- **Repo rules** (`dev/AGENTS_MASTER.md`): commit messages are one short line with **no** `Co-Authored-By` trailer. Work on `main`.
- **git-sync pushes every commit within seconds.** Run the checks *before* committing and never amend; fix forward with a new commit.
- **Never stage files outside `SwiftApp/` or `docs/superpowers/plans/`.** The user may have uncommitted web-app changes in `src/` and `tests/`; leave them alone. Always `git add` explicit paths, and check `git status --short` first so build output and the generated `ElisaMusica.xcodeproj` (both gitignored) are never staged.
- **A hook blocks any shell command that mentions `.env`** (even inside a heredoc). Don't read `SwiftApp/.env`.
- **`ls` is aliased to eza here**, so use `command ls` when output matters.
- **Swift Testing gotcha:** `#expect(...)` wraps its expression in a closure, so a *mutating* call on a local `var` inside it does not compile. Call it into a `let` first (`let outcome = g.tap("red")`), then `#expect(outcome == …)`.
- **Swift tests:** `cd ~/c/bsharp/SwiftApp/ElisaKit && swift test`. **App build:**
  `cd ~/c/bsharp/SwiftApp && xcodegen generate && xcodebuild -project ElisaMusica.xcodeproj -scheme ElisaMusica -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd build 2>&1 | tail -3`
  **UI tests:** `cd ~/c/bsharp/SwiftApp && xcodebuild test -project ElisaMusica.xcodeproj -scheme ElisaMusica -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' -derivedDataPath build/dd 2>&1 | grep -E "skipped|TEST (SUCCEEDED|FAILED)|error:" | tail -5`
- **SourceKit diagnostics in the editor** (`No such module 'Testing'`, `Cannot find 'Theme' in scope`) are noise from a stale index; trust `swift test` and `xcodebuild`.
- Simulators on this Mac: `iPad mini (A17 Pro)` and `iPhone 16e`. Run `xcrun simctl shutdown all` when a UI test or screenshot session is over.

## What Plans 1–2 left in place

- `ElisaKit`: `Characters.all` (25 names), `Characters.label`, `Characters.revealSeconds = 3.0`, `CharacterDeck` (a struct with `mutating next()`, takes a `random` closure); `Streak.target = 20`, `Streak.next`, `Streak.progress(_:)`; `Progression.nextLevel`, `Progression.levelUp(from:instrument:)` → `LevelUp(level:instrument:)`, `Instrument.afterLevelUp`; `SavedProgress` (`profile`, `changeLevel(to:now:)`, `recordAnswer`, `resetStats`, `launch`), `Profile.streak: Int?` and `Profile.currentInstrument: String`; `Game` (`tap`, `play`, `revealFinished`, `marked`, `awaitingPlay`, `showsPlayHint`, `level`, `chords`, `instrument`).
- App: `GameModel` (owns `Game`, `ProgressStore`, `ChordPlayer`; `scheduleRevealEnd()` runs `game.revealFinished()` after 3 s), `HomeView`, `FlagGrid`/`FlagView`/`CorrectCheck`, `Metrics` (the web app's `clamp()` sizes, `landscape`), `Theme` (`ink`, `edge`, `headline(_:)`), `TitleCard` (the white pill with the pale-blue ring, copied for the name pill), `LaunchOptions` (`-ElisaFreshState`, `-ElisaLevel`, `-ElisaAnswer`), `project.yml` (the chords folder resource).
- Tests: `GameTests.swift` defines `GameTestClock`, which this plan's new test file reuses; `ChordFilesTests.swift` finds `static/chords` by walking up from `#filePath` (five `deletingLastPathComponent()` calls reach the repo root), which the character-files test copies.
- UI tests (`UITests/GameFlowUITests.swift`) launch with `-ElisaFreshState YES -ElisaAnswer red` and read `accessibilityValue` (`correct`, `dimmed`, or empty) on `flag-<chord id>`; `play-button`, `play-hint` are the other ids. `UITests/ScreenshotTests.swift` is skipped unless `TEST_RUNNER_ELISA_SCREENSHOTS=1`.

## Behavior being ported (read once)

From `src/ts/game.ts`, `characters.ts`, `streak.ts` and `src/scss/_bluey.scss`:

- **A right answer** shows a character and its name pill for `Characters.revealSeconds` (3 s), together with the green check Plan 2 already draws. A wrong answer shows no character. The character comes from `CharacterDeck`: every one of the 25 once per round in random order, never the same one twice in a row across rounds.
- **Where it sits.** Portrait: top = 9 % of the screen height (below the safe area), 12 pt from the right edge, picture height `min(11 % of height, 130)`, at most 28 % of the width wide, name font 20.8 pt. Landscape: 12 pt from the top, 104 pt from the right (room for the gear Plan 4 adds), height `min(30 % of height, 220)`, at most 38 % of the width, name font 25.6 pt. The name pill is white, radius 20, padding 2/18/4/18, a 4 pt pale-blue ring, Hello Headline in ink. The picture has a drop shadow of ink at 35 %.
- **How it appears.** Opacity 0 → 1 in 0.25 s, and scale 0.6 → 1 with a rotation of −4° → 0 in 0.35 s on the curve `cubic-bezier(0.3, 1.5, 0.5, 1)` (it overshoots a little). It fades out in 0.25 s when the reveal ends.
- **The streak** (`profile.streak`, +1 per right answer, back to 0 on a wrong one, already kept by `recordAnswer`) fills a 5 pt outline round the whole screen, starting at the top centre and going clockwise, over a track of white at 55 %. The path sits 3 pt inside the screen edge, with round joins. A hit fills it over 0.9 s, a miss unwinds it in 0.35 s, both ease-in-out. It is drawn from the saved streak at launch.
- **Level-up.** When a right answer makes the streak reach 20, the reveal ends with the next level instead of the next question at the same level. The next level starts like any level change (new session, the play hint, a new unplayed question) **and** the flags stay dimmed until play is pressed (the web app calls `setAwaitingPlay(true)` after `advanceLevel()`). The streak starts at 0 at the new level. **New in this app:** the instrument switches too, piano → guitar → piano …; strummed guitar goes to piano. It is saved in the profile like a manual choice.
- **The last level** (skyblue) has no level-up: at 20 the streak just starts over at 0, the instrument stays, and the reveal ends like a normal one (next question, dimmed, no hint).
- Not in this plan: the gear button, the menu, the stats history (Plan 4).

## Names used everywhere

| Thing | Value |
|---|---|
| New launch argument | `-ElisaStreak <n>`: the streak she starts with. It is applied when the game starts, and `-ElisaLevel` (which starts a new streak) zeroes it, so combine them only when you want 0 |
| Accessibility ids | `character-reveal` (label = the name shown), `streak-outline` (value = the streak as a number, e.g. `"7"`) |
| Characters in the bundle | `characters/<name>.png` (folder reference to `../static/characters`) |
| New log events | `game.level-up` with `level` and `instrument` |
| Version to ship | `0.3.0` (`SwiftApp/deploy minor`) |

## File structure

```
SwiftApp/
  project.yml                         + characters folder resource
  ElisaKit/Sources/ElisaKit/
    Rewards.swift                     SavedProgress.levelUp(now:)
    Game.swift                        + character, streak, levelUpDue, startingStreak
  ElisaKit/Tests/ElisaKitTests/
    RewardsTests.swift                levelUp on SavedProgress
    GameRewardsTests.swift            character, streak, level-up in Game
    CharacterFilesTests.swift         every character has a PNG
  App/
    CharacterImages.swift             loads and caches the bundled PNGs
    CharacterReveal.swift             the picture and its name pill
    StreakOutline.swift               the outline round the screen
    LaunchOptions.swift               + streak
    GameModel.swift                   level-up reloads the player; preloads the characters
    Metrics.swift                     + the reveal's sizes
    HomeView.swift                    + the two overlays
  UITests/GameFlowUITests.swift       + 3 flows
  UITests/ScreenshotTests.swift       + streak and level-up captures
```

---

### Task 1: Level-up on the saved progress

The progress-side half of a level-up: next level, the instrument switch, a fresh streak. At the last level there is nothing to move to, so only the streak starts over.

**Files:**
- Create: `SwiftApp/ElisaKit/Sources/ElisaKit/Rewards.swift`
- Test: `SwiftApp/ElisaKit/Tests/ElisaKitTests/RewardsTests.swift`

- [ ] **Step 1: Write the failing tests**

`SwiftApp/ElisaKit/Tests/ElisaKitTests/RewardsTests.swift`:

```swift
import Testing
@testable import ElisaKit

private let t0 = 1_793_400_000.0

@Suite struct RewardsTests {
    @Test func aLevelUpGoesToTheNextLevelOnTheOtherInstrument() {
        var p = SavedProgress.fresh(now: t0)
        p.profile.streak = 20
        let up = p.levelUp(now: t0 + 1)
        #expect(up == LevelUp(level: "blue", instrument: .guitar))
        #expect(p.state.currentChord == "blue")
        #expect(p.profile.currentChord == "blue")
        #expect(p.profile.stats.currentChord == "blue")
        #expect(p.profile.currentInstrument == "guitar")
        #expect(p.profile.streak == 0)
    }

    @Test func theNextLevelUpSwitchesBackToPiano() {
        var p = SavedProgress.fresh(now: t0)
        p.profile.streak = 20
        p.levelUp(now: t0 + 1)
        p.profile.streak = 20
        let up = p.levelUp(now: t0 + 2)
        #expect(up == LevelUp(level: "black", instrument: .piano))
        #expect(p.profile.instrument == .piano)
    }

    @Test func strummedGuitarGoesToPiano() {
        var p = SavedProgress.fresh(now: t0)
        p.profile.currentInstrument = Instrument.guitarStrummed.rawValue
        p.profile.streak = 20
        p.levelUp(now: t0 + 1)
        #expect(p.profile.instrument == .piano)
    }

    @Test func theSessionAtTheOldLevelIsParkedUnfinished() {
        var p = SavedProgress.fresh(now: t0)
        p.recordAnswer(played: "red", chosen: "red", now: t0 + 1)
        p.levelUp(now: t0 + 2)
        #expect(p.history["100"]?["yellow"]?.count == 1)
        #expect(p.history["100"]?["yellow"]?.first?.done == false)
        #expect(p.profile.stats.identifications == 0)
    }

    @Test func theLastLevelOnlyStartsTheStreakOver() {
        var p = SavedProgress.fresh(now: t0)
        p.state.currentChord = "skyblue"
        p.profile.currentChord = "skyblue"
        p.profile.currentInstrument = Instrument.guitar.rawValue
        p.profile.streak = 20
        let up = p.levelUp(now: t0 + 1)
        #expect(up == nil)
        #expect(p.state.currentChord == "skyblue")
        #expect(p.profile.instrument == .guitar)
        #expect(p.profile.streak == 0)
    }
}
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `cd ~/c/bsharp/SwiftApp/ElisaKit && swift test --filter RewardsTests`
Expected: FAIL, `value of type 'SavedProgress' has no member 'levelUp'`.

- [ ] **Step 3: Write the level-up**

`SwiftApp/ElisaKit/Sources/ElisaKit/Rewards.swift`:

```swift
/// What a completed streak does to the saved progress (advanceLevel in src/ts/game.ts, plus
/// the instrument switch this app adds).
extension SavedProgress {
    /// Moves to the next level on the other instrument. The new level starts a new session and
    /// a new streak, and the instrument is saved in the profile like a manual choice. Returns
    /// nil at the last level, where nothing moves, the instrument stays and only the streak
    /// starts over.
    @discardableResult
    public mutating func levelUp(now: Double) -> LevelUp? {
        guard let up = Progression.levelUp(from: state.currentChord, instrument: profile.instrument) else {
            profile.streak = 0
            return nil
        }
        changeLevel(to: up.level, now: now)
        profile.currentInstrument = up.instrument.rawValue
        return up
    }
}
```

- [ ] **Step 4: Run the tests and make sure they pass**

Run: `cd ~/c/bsharp/SwiftApp/ElisaKit && swift test`
Expected: PASS, every suite (104 existing tests plus 5 new).

- [ ] **Step 5: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/ElisaKit/Sources/ElisaKit/Rewards.swift SwiftApp/ElisaKit/Tests/ElisaKitTests/RewardsTests.swift
git commit -m "Add the level-up with the instrument switch to the saved progress"
```

---

### Task 2: The game deals characters and ends the reveal with a level-up

`Game` gets the character on a right answer, the streak, a flag for "this answer completed the streak", and the level-up when the reveal ends. A `startingStreak` test hook (like `forcedAnswer`) seeds the streak for UI tests and screenshots.

**Files:**
- Modify: `SwiftApp/ElisaKit/Sources/ElisaKit/Game.swift`
- Test: `SwiftApp/ElisaKit/Tests/ElisaKitTests/GameRewardsTests.swift`

- [ ] **Step 1: Write the failing tests**

`SwiftApp/ElisaKit/Tests/ElisaKitTests/GameRewardsTests.swift`:

```swift
import Testing
@testable import ElisaKit

@Suite struct GameRewardsTests {
    let clock = GameTestClock()

    /// A started game that always asks red. `level` and `instrument` are what her profile
    /// saved; `streak` is the streak she starts with.
    private func game(level: String = "yellow", instrument: Instrument = .piano, streak: Int? = nil,
                      hints: Bool = true) -> Game {
        var progress = SavedProgress.fresh(now: clock.now)
        progress.state.currentChord = level
        progress.profile.currentChord = level
        progress.profile.stats.currentChord = level
        progress.profile.currentInstrument = instrument.rawValue
        progress.profile.enableOnboardingHints = hints
        var game = Game(progress: progress, forcedAnswer: "red", startingStreak: streak,
                        random: { 0.0 }, now: { [clock] in clock.now })
        game.start()
        return game
    }

    /// Presses play and answers red, the right answer.
    private func answerRight(_ g: inout Game) {
        _ = g.play()
        _ = g.tap("red")
    }

    @Test func aRightAnswerDealsACharacterUntilTheRevealEnds() {
        var g = game()
        _ = g.play()
        let wrong = g.tap("yellow")
        #expect(wrong == .wrong)
        #expect(g.character == nil)
        let right = g.tap("red")
        #expect(right == .correct)
        #expect(Characters.all.contains(g.character ?? ""))
        g.revealFinished()
        #expect(g.character == nil)
    }

    @Test func charactersDontRepeatWithinARound() {
        var g = game()
        answerRight(&g)
        let first = g.character
        g.revealFinished()
        answerRight(&g)
        #expect(g.character != nil)
        #expect(g.character != first)
    }

    @Test func theStreakCountsRightAnswersAndAMissStartsOver() {
        var g = game()
        #expect(g.streak == 0)
        answerRight(&g)
        #expect(g.streak == 1)
        g.revealFinished()
        _ = g.play()
        let wrong = g.tap("yellow")
        #expect(wrong == .wrong)
        #expect(g.streak == 0)
    }

    @Test func aStartingStreakIsKept() {
        let g = game(streak: 7)
        #expect(g.streak == 7)
    }

    @Test func twentyInARowIsDueForALevelUpButNineteenIsNot() {
        var nineteen = game(streak: 18)
        answerRight(&nineteen)
        #expect(nineteen.streak == 19)
        #expect(!nineteen.levelUpDue)
        var twenty = game(streak: 19)
        answerRight(&twenty)
        #expect(twenty.streak == 20)
        #expect(twenty.levelUpDue)
    }

    @Test func theRevealEndsWithTheNextLevelOnTheOtherInstrument() {
        var g = game(streak: 19)
        answerRight(&g)
        g.revealFinished()
        #expect(g.level == "blue")
        #expect(g.chords.map(\.id) == ["red", "yellow", "blue"])
        #expect(g.instrument == .guitar)
        #expect(g.profile.currentInstrument == "guitar")
        #expect(g.streak == 0)
        #expect(!g.levelUpDue)
        #expect(g.marked == nil)
        #expect(g.character == nil)
        // As after any level change: the hint shows, and the flags wait for play.
        #expect(g.showsPlayHint)
        #expect(g.awaitingPlay)
        #expect(!g.asked)
    }

    @Test func aLevelUpFromGuitarGoesBackToPiano() {
        var g = game(instrument: .guitar, streak: 19)
        answerRight(&g)
        g.revealFinished()
        #expect(g.level == "blue")
        #expect(g.instrument == .piano)
    }

    @Test func noHintAfterALevelUpWhenHintsAreOff() {
        var g = game(streak: 19, hints: false)
        answerRight(&g)
        g.revealFinished()
        #expect(g.level == "blue")
        #expect(!g.showsPlayHint)
        #expect(g.awaitingPlay)
    }

    @Test func theLastLevelStartsTheStreakOverAndKeepsTheInstrument() {
        var g = game(level: "skyblue", instrument: .guitar, streak: 19)
        answerRight(&g)
        g.revealFinished()
        #expect(g.level == "skyblue")
        #expect(g.instrument == .guitar)
        #expect(g.streak == 0)
        #expect(g.awaitingPlay)
        #expect(!g.showsPlayHint)
        #expect(!g.levelUpDue)
    }

    @Test func aPlainRevealKeepsTheLevelAndTheStreak() {
        var g = game()
        answerRight(&g)
        g.revealFinished()
        #expect(g.level == "yellow")
        #expect(g.instrument == .piano)
        #expect(g.streak == 1)
        #expect(g.awaitingPlay)
    }
}
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `cd ~/c/bsharp/SwiftApp/ElisaKit && swift test --filter GameRewardsTests`
Expected: FAIL, `extra argument 'startingStreak' in call` (and `no member 'character'`).

- [ ] **Step 3: Change `Game.swift`**

Five edits with the Edit tool, in `SwiftApp/ElisaKit/Sources/ElisaKit/Game.swift`.

(a) The properties and the initializer. Replace

```swift
    /// The arrow up at the play button, shown when a level starts, until play is pressed.
    public private(set) var showsPlayHint = false

    private var weights: [Double]?
    private let forcedAnswer: String?
    private let random: () -> Double
    private let now: () -> Double

    /// `forcedAnswer` always asks that chord (the web app's test hook).
    public init(progress: SavedProgress,
                forcedAnswer: String? = nil,
                random: @escaping () -> Double = { Double.random(in: 0..<1) },
                now: @escaping () -> Double = { Date().timeIntervalSince1970 }) {
        self.progress = progress
        self.forcedAnswer = forcedAnswer
        self.random = random
        self.now = now
    }

    public var profile: Profile { progress.profile }
```

with

```swift
    /// The arrow up at the play button, shown when a level starts, until play is pressed.
    public private(set) var showsPlayHint = false
    /// The character shown with the green check, from a right answer until `revealFinished()`.
    public private(set) var character: String?
    /// Whether the right answer on screen completed a streak of `Streak.target`, so the reveal
    /// ends with a level-up.
    public private(set) var levelUpDue = false

    private var weights: [Double]?
    private var deck: CharacterDeck
    private let forcedAnswer: String?
    private let startingStreak: Int?
    private let random: () -> Double
    private let now: () -> Double

    /// `forcedAnswer` always asks that chord (the web app's test hook); `startingStreak`
    /// seeds the streak when the game starts (for UI tests and screenshots).
    public init(progress: SavedProgress,
                forcedAnswer: String? = nil,
                startingStreak: Int? = nil,
                random: @escaping () -> Double = { Double.random(in: 0..<1) },
                now: @escaping () -> Double = { Date().timeIntervalSince1970 }) {
        self.progress = progress
        self.forcedAnswer = forcedAnswer
        self.startingStreak = startingStreak
        self.random = random
        self.now = now
        deck = CharacterDeck(random: random)
    }

    public var profile: Profile { progress.profile }
    /// Correct answers in a row at this level.
    public var streak: Int { profile.streak ?? 0 }
```

(b) `start()`. Replace

```swift
    public mutating func start() {
        progress.launch(now: now())
        newSession()
    }
```

with

```swift
    public mutating func start() {
        progress.launch(now: now())
        if let startingStreak {
            progress.profile.streak = startingStreak
        }
        newSession()
    }
```

(c) The right answer in `tap`. Replace

```swift
        marked = color
        return .correct
```

with

```swift
        marked = color
        character = deck.next()
        levelUpDue = streak >= Streak.target
        return .correct
```

(d) `revealFinished()`. Replace

```swift
    /// The reveal is over: the next question is loaded, not played, and the flags dim until
    /// play is pressed.
    public mutating func revealFinished() {
        guard marked != nil else { return }
        marked = nil
        newQuestion()
        awaitingPlay = true
    }
```

with

```swift
    /// The reveal is over. A completed streak moves to the next level on the other instrument
    /// (the new level starts like any level change, with the play hint); otherwise the next
    /// question is loaded at the same level. Either way it is not played, and the flags dim
    /// until play is pressed. At the last level a completed streak just starts over.
    public mutating func revealFinished() {
        guard marked != nil else { return }
        let leveledUp = levelUpDue && progress.levelUp(now: now()) != nil
        if leveledUp {
            newSession()
        } else {
            marked = nil
            character = nil
            levelUpDue = false
            newQuestion()
        }
        awaitingPlay = true
    }
```

(e) `newSession()`. Replace

```swift
    private mutating func newSession() {
        weights = nil
        marked = nil
        awaitingPlay = false
```

with

```swift
    private mutating func newSession() {
        weights = nil
        marked = nil
        character = nil
        levelUpDue = false
        awaitingPlay = false
```

- [ ] **Step 4: Run the tests and make sure they pass**

Run: `cd ~/c/bsharp/SwiftApp/ElisaKit && swift test`
Expected: PASS, every suite, including the 10 new `GameRewardsTests` and the existing `GameTests`.

- [ ] **Step 5: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/ElisaKit/Sources/ElisaKit/Game.swift SwiftApp/ElisaKit/Tests/ElisaKitTests/GameRewardsTests.swift
git commit -m "Deal a character per right answer and level up when a streak completes"
```

---

### Task 3: The character images in the app

The 25 PNGs already live in `static/characters/` for the web app. Bundle them as a folder reference (like the chords, so there is one copy) and load them through a small cache.

**Files:**
- Modify: `SwiftApp/project.yml`
- Create: `SwiftApp/App/CharacterImages.swift`
- Test: `SwiftApp/ElisaKit/Tests/ElisaKitTests/CharacterFilesTests.swift`

- [ ] **Step 1: Write the guard test**

`SwiftApp/ElisaKit/Tests/ElisaKitTests/CharacterFilesTests.swift`:

```swift
import Foundation
import Testing
@testable import ElisaKit

@Suite struct CharacterFilesTests {
    /// bsharp/static/characters, found from this file's path.
    let folder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "static/characters")

    @Test func everyCharacterHasAnImageAndNoImageIsLeftOut() throws {
        for name in Characters.all {
            #expect(FileManager.default.fileExists(atPath: folder.appending(path: "\(name).png").path(percentEncoded: false)), "\(name)")
        }
        let onDisk = try FileManager.default
            .contentsOfDirectory(atPath: folder.path(percentEncoded: false))
            .filter { $0.hasSuffix(".png") }.sorted()
        #expect(onDisk == Characters.all.map { "\($0).png" }.sorted())
    }
}
```

- [ ] **Step 2: Run it**

Run: `cd ~/c/bsharp/SwiftApp/ElisaKit && swift test --filter CharacterFilesTests`
Expected: PASS. This test guards the catalog (a character added to `Characters.all` without its PNG, or the reverse, fails it); it passes now because the images already exist.

- [ ] **Step 3: Bundle the folder**

In `SwiftApp/project.yml`, in the `ElisaMusica` target's `sources:`, after the `../static/chords` entry, add the characters folder. Replace

```yaml
      - path: ../static/chords
        type: folder
        buildPhase: resources
```

with

```yaml
      - path: ../static/chords
        type: folder
        buildPhase: resources
      # The web app's Bluey cut-outs, in the bundle at characters/<name>.png.
      - path: ../static/characters
        type: folder
        buildPhase: resources
```

- [ ] **Step 4: Write the image cache**

`SwiftApp/App/CharacterImages.swift`:

```swift
import ElisaKit
import UIKit

/// The character cut-outs, bundled from static/characters/ at `characters/<name>.png`.
@MainActor
enum CharacterImages {
    private static var cache: [String: UIImage] = [:]

    static func image(_ name: String) -> UIImage? {
        if let cached = cache[name] { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "characters"),
              let image = UIImage(contentsOfFile: url.path(percentEncoded: false)) else { return nil }
        let ready = image.preparingForDisplay() ?? image
        cache[name] = ready
        return ready
    }

    /// Reads and decodes every image up front, so a reveal never waits on the disk.
    static func preload() {
        for name in Characters.all {
            _ = image(name)
        }
    }
}
```

- [ ] **Step 5: Build and check the bundle**

```bash
cd ~/c/bsharp/SwiftApp && xcodegen generate && xcodebuild -project ElisaMusica.xcodeproj -scheme ElisaMusica -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd build 2>&1 | tail -3
command ls build/dd/Build/Products/Debug-iphonesimulator/ElisaMusica.app/characters | wc -l
```

Expected: `** BUILD SUCCEEDED **`, then `25`.

- [ ] **Step 6: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/project.yml SwiftApp/App/CharacterImages.swift SwiftApp/ElisaKit/Tests/ElisaKitTests/CharacterFilesTests.swift
git status --short SwiftApp
git commit -m "Bundle the character images and load them through a cache"
```

`git status --short SwiftApp` must show nothing under `build/` and no `.xcodeproj`.

---

### Task 4: Launch option and model glue

`-ElisaStreak` reaches the game, the model preloads the characters, and a level-up reloads the player for the new instrument and logs it.

**Files:**
- Modify: `SwiftApp/App/LaunchOptions.swift`
- Modify: `SwiftApp/App/GameModel.swift`

- [ ] **Step 1: Add the launch argument**

In `SwiftApp/App/LaunchOptions.swift`, replace

```swift
    /// Play on a throwaway progress file, so a test never touches real progress.
    var freshState = false

    static func current(_ defaults: UserDefaults = .standard) -> LaunchOptions {
        LaunchOptions(level: defaults.string(forKey: "ElisaLevel"),
                      answer: defaults.string(forKey: "ElisaAnswer"),
                      freshState: defaults.bool(forKey: "ElisaFreshState"))
    }
```

with

```swift
    /// Play on a throwaway progress file, so a test never touches real progress.
    var freshState = false
    /// Start with this streak. `-ElisaLevel` starts a new streak, so it zeroes this one.
    var streak: Int?

    static func current(_ defaults: UserDefaults = .standard) -> LaunchOptions {
        LaunchOptions(level: defaults.string(forKey: "ElisaLevel"),
                      answer: defaults.string(forKey: "ElisaAnswer"),
                      freshState: defaults.bool(forKey: "ElisaFreshState"),
                      streak: defaults.object(forKey: "ElisaStreak") == nil
                          ? nil : defaults.integer(forKey: "ElisaStreak"))
    }
```

Also change the doc comment's example line from
``/// `-ElisaFreshState YES -ElisaLevel gray -ElisaAnswer red`. A normal launch has none.``
to
``/// `-ElisaFreshState YES -ElisaLevel gray -ElisaAnswer red -ElisaStreak 7`. A normal launch has none.``

- [ ] **Step 2: Wire the model**

In `SwiftApp/App/GameModel.swift`, three edits.

(a) The initial game. Replace

```swift
        game = Game(progress: store.load(now: now) ?? .fresh(now: now), forcedAnswer: options.answer)
        game.start()
        if let level = options.level {
            game.changeLevel(to: level)
        }
        player.load(game.instrument)
```

with

```swift
        game = Game(progress: store.load(now: now) ?? .fresh(now: now), forcedAnswer: options.answer,
                    startingStreak: options.streak)
        game.start()
        if let level = options.level {
            game.changeLevel(to: level)
        }
        CharacterImages.preload()
        player.load(game.instrument)
```

(b) The end of the reveal. Replace

```swift
            guard !Task.isCancelled, let self else { return }
            self.game.revealFinished()
            self.save()
```

with

```swift
            guard !Task.isCancelled, let self else { return }
            let level = self.game.level
            self.game.revealFinished()
            if self.game.level != level {
                // A level-up switched the instrument.
                self.player.load(self.game.instrument)
                DevLog.event("game.level-up", ["level": self.game.level,
                                               "instrument": self.game.instrument.rawValue])
            }
            self.save()
```

(c) Update the doc comment above `scheduleRevealEnd` from
`/// The right answer stays on screen for the reveal; then the next chord waits for play.`
to
`/// The right answer stays on screen for the reveal; then the next chord (or, after a streak of 20, the next level) waits for play.`

- [ ] **Step 3: Build and test**

```bash
cd ~/c/bsharp/SwiftApp/ElisaKit && swift test 2>&1 | tail -2
cd ~/c/bsharp/SwiftApp && xcodegen generate && xcodebuild -project ElisaMusica.xcodeproj -scheme ElisaMusica -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd build 2>&1 | tail -3
```

Expected: all Swift tests pass, `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/App/LaunchOptions.swift SwiftApp/App/GameModel.swift
git commit -m "Seed the streak from a launch argument and reload the player on level-up"
```

---

### Task 5: The streak outline

**Files:**
- Create: `SwiftApp/App/StreakOutline.swift`
- Modify: `SwiftApp/App/HomeView.swift`

- [ ] **Step 1: Write the view**

`SwiftApp/App/StreakOutline.swift`:

```swift
import ElisaKit
import SwiftUI

/// The outline round the screen that fills clockwise from the top centre as the streak grows
/// (#streak-outline in _bluey.scss, streak.ts). A hit fills it slowly, a miss unwinds it fast.
struct StreakOutline: View {
    let streak: Int
    /// The fraction of the way round that is drawn now; it animates towards the streak.
    @State private var shown = 0.0

    private static let stroke = StrokeStyle(lineWidth: 5, lineJoin: .round)

    var body: some View {
        ZStack {
            OutlineShape().stroke(.white.opacity(0.55), style: Self.stroke)
            OutlineShape().trim(from: 0, to: shown).stroke(Theme.ink, style: Self.stroke)
        }
        .allowsHitTesting(false)
        // initial: true draws the saved streak at launch, filling from empty as the web app does.
        .onChange(of: streak, initial: true) { _, new in
            let progress = Streak.progress(new)
            withAnimation(.easeInOut(duration: progress < shown ? 0.35 : 0.9)) {
                shown = progress
            }
        }
        .accessibilityElement()
        .accessibilityIdentifier("streak-outline")
        .accessibilityValue("\(streak)")
    }
}

/// A rectangle 3 pt inside the screen edge, drawn from the top centre clockwise, so a trim of
/// 0...1 is the share of the way round (the web app's pathLength=1).
private struct OutlineShape: Shape {
    static let inset: CGFloat = 3

    func path(in rect: CGRect) -> Path {
        let left = rect.minX + Self.inset
        let top = rect.minY + Self.inset
        let right = rect.maxX - Self.inset
        let bottom = rect.maxY - Self.inset
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: top))
        path.addLine(to: CGPoint(x: right, y: top))
        path.addLine(to: CGPoint(x: right, y: bottom))
        path.addLine(to: CGPoint(x: left, y: bottom))
        path.addLine(to: CGPoint(x: left, y: top))
        path.addLine(to: CGPoint(x: rect.midX, y: top))
        return path
    }
}
```

- [ ] **Step 2: Put it over the screen**

In `SwiftApp/App/HomeView.swift`, replace

```swift
        .background(SkyBackground())
```

with

```swift
        .background(SkyBackground())
        .overlay {
            StreakOutline(streak: model.game.streak).ignoresSafeArea()
        }
```

- [ ] **Step 3: Build and look**

```bash
cd ~/c/bsharp/SwiftApp && xcodegen generate && xcodebuild -project ElisaMusica.xcodeproj -scheme ElisaMusica -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd build 2>&1 | tail -3
xcrun simctl boot "iPad mini (A17 Pro)" 2>/dev/null; open -a Simulator
xcrun simctl install "iPad mini (A17 Pro)" build/dd/Build/Products/Debug-iphonesimulator/ElisaMusica.app
BUNDLE=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' build/dd/Build/Products/Debug-iphonesimulator/ElisaMusica.app/Info.plist)
xcrun simctl terminate "iPad mini (A17 Pro)" "$BUNDLE" 2>/dev/null
xcrun simctl launch "iPad mini (A17 Pro)" "$BUNDLE" -ElisaFreshState YES -ElisaStreak 15
sleep 2
xcrun simctl io "iPad mini (A17 Pro)" screenshot build/check-streak-15.png
```

Expected: `** BUILD SUCCEEDED **`. Open `build/check-streak-15.png` with the Read tool: a dark outline runs from the top centre clockwise round the right side, the bottom and up the left side to about the middle (three quarters of the way), over a paler white track on the rest. Compare with `Reference Material/screenshots/state-06-streak-15-of-20.png`.

- [ ] **Step 4: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/App/StreakOutline.swift SwiftApp/App/HomeView.swift
git commit -m "Draw the streak as an outline round the screen"
```

---

### Task 6: The character reveal

**Files:**
- Modify: `SwiftApp/App/Metrics.swift`
- Create: `SwiftApp/App/CharacterReveal.swift`
- Modify: `SwiftApp/App/HomeView.swift`

- [ ] **Step 1: The reveal's sizes**

In `SwiftApp/App/Metrics.swift`, replace

```swift
    private func clamp(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat {
```

with

```swift
    /// #character-reveal img height: portrait min(11vh, 130px), landscape min(30vh, 220px)
    var revealImageHeight: CGFloat { landscape ? min(30 * vh, 220) : min(11 * vh, 130) }
    /// img max-width: portrait 28vw, landscape 38vw
    var revealImageMaxWidth: CGFloat { landscape ? 38 * vw : 28 * vw }
    /// .character-name font: portrait 1.3rem, landscape 1.6rem
    var revealNameFont: CGFloat { landscape ? 25.6 : 20.8 }
    /// top: portrait 9vh below the safe area, landscape 0.75rem
    var revealTop: CGFloat { landscape ? 12 : 9 * vh }
    /// right: portrait 0.75rem, landscape 6.5rem (clear of the gear Plan 4 adds)
    var revealTrailing: CGFloat { landscape ? 104 : 12 }

    private func clamp(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat {
```

- [ ] **Step 2: Write the view**

`SwiftApp/App/CharacterReveal.swift`:

```swift
import ElisaKit
import SwiftUI

/// A Bluey character and its name pill, popped in beside the play and next buttons for the
/// length of a right answer's reveal (#character-reveal in _bluey.scss).
struct CharacterReveal: View {
    let name: String
    let metrics: Metrics
    @State private var shown = false

    var body: some View {
        VStack(spacing: 4) {
            if let image = CharacterImages.image(name) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(maxWidth: metrics.revealImageMaxWidth, maxHeight: metrics.revealImageHeight)
                    .shadow(color: Theme.ink.opacity(0.35), radius: 6, y: 6)
            }
            Text(Characters.label(name))
                .font(Theme.headline(metrics.revealNameFont))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 18)
                .padding(.top, 2)
                .padding(.bottom, 4)
                .background(RoundedRectangle(cornerRadius: 20).fill(.white))
                // The 4 pt pale-blue ring (box-shadow: 0 0 0 4px $bluey-edge).
                .background(RoundedRectangle(cornerRadius: 24).fill(Theme.edge).padding(-4))
        }
        // transform: scale(0.6) rotate(-4deg) → none over 0.35 s on cubic-bezier(.3, 1.5, .5, 1),
        // and opacity over 0.25 s.
        .scaleEffect(shown ? 1 : 0.6)
        .rotationEffect(.degrees(shown ? 0 : -4))
        .animation(.timingCurve(0.3, 1.5, 0.5, 1, duration: 0.35), value: shown)
        .opacity(shown ? 1 : 0)
        .animation(.easeOut(duration: 0.25), value: shown)
        .onAppear { shown = true }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("character-reveal")
        .accessibilityLabel(Characters.label(name))
    }
}
```

- [ ] **Step 3: Show it over the screen**

In `SwiftApp/App/HomeView.swift`, replace

```swift
            .padding(.bottom, 10)
        }
        .background(SkyBackground())
```

with

```swift
            .padding(.bottom, 10)
            .overlay(alignment: .topTrailing) {
                ZStack {
                    if let name = model.game.character {
                        CharacterReveal(name: name, metrics: metrics)
                            .id(name)
                            .padding(.top, metrics.revealTop)
                            .padding(.trailing, metrics.revealTrailing)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: model.game.character)
            }
        }
        .background(SkyBackground())
```

- [ ] **Step 4: Build and look**

```bash
cd ~/c/bsharp/SwiftApp && xcodegen generate && xcodebuild -project ElisaMusica.xcodeproj -scheme ElisaMusica -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`. The full on-screen check (a right answer shows a character and its name) is done by the UI test in Task 7 and the comparison in Task 8; if you want to see it now, launch the app as in Task 5 with `-ElisaFreshState YES -ElisaAnswer red`, press play, tap the red flag and take a screenshot within 3 s.

- [ ] **Step 5: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/App/Metrics.swift SwiftApp/App/CharacterReveal.swift SwiftApp/App/HomeView.swift
git commit -m "Show a character and its name for a right answer"
```

---

### Task 7: UI tests for the three flows

**Files:**
- Modify: `SwiftApp/UITests/GameFlowUITests.swift`

- [ ] **Step 1: Write the tests**

In `SwiftApp/UITests/GameFlowUITests.swift`, replace

```swift
    func testABlackKeyLevelHasTenFlags() {
        let app = launch(["-ElisaLevel", "gray"])
        XCTAssertTrue(app.buttons["flag-gray"].waitForExistence(timeout: 10))
        let flags = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'flag-'"))
        XCTAssertEqual(flags.count, 10)
    }
}
```

with

```swift
    func testABlackKeyLevelHasTenFlags() {
        let app = launch(["-ElisaLevel", "gray"])
        XCTAssertTrue(app.buttons["flag-gray"].waitForExistence(timeout: 10))
        let flags = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'flag-'"))
        XCTAssertEqual(flags.count, 10)
    }

    /// Any element with this accessibility id, whatever its type.
    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testARightAnswerShowsACharacterForThreeSeconds() {
        let app = launch()
        let red = app.buttons["flag-red"]
        XCTAssertTrue(red.waitForExistence(timeout: 10))
        let character = element(app, "character-reveal")
        XCTAssertFalse(character.exists)
        app.buttons["play-button"].tap()

        app.buttons["flag-yellow"].tap()
        XCTAssertFalse(character.exists, "a wrong answer shows no character")

        red.tap()
        XCTAssertTrue(character.waitForExistence(timeout: 2))
        XCTAssertFalse(character.label.isEmpty, "the character's name is shown")

        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: character)
        waitForExpectations(timeout: 8)
    }

    func testTheOutlineFollowsTheStreak() {
        let app = launch(["-ElisaStreak", "7"])
        let outline = element(app, "streak-outline")
        XCTAssertTrue(outline.waitForExistence(timeout: 10))
        XCTAssertEqual(value(outline), "7")
        app.buttons["play-button"].tap()

        app.buttons["flag-yellow"].tap()
        XCTAssertEqual(value(outline), "0", "a miss starts the streak over")

        app.buttons["flag-red"].tap()
        XCTAssertEqual(value(outline), "1")
    }

    func testTwentyInARowMovesToTheNextLevel() {
        let app = launch(["-ElisaStreak", "19"])
        let red = app.buttons["flag-red"]
        XCTAssertTrue(red.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["flag-blue"].exists)
        app.buttons["play-button"].tap()
        red.tap()

        // After the reveal the next level starts: its flags show, dimmed, with the play hint.
        XCTAssertTrue(app.buttons["flag-blue"].waitForExistence(timeout: 8))
        XCTAssertEqual(value(red), "dimmed")
        XCTAssertTrue(app.staticTexts["play-hint"].exists)
        XCTAssertEqual(value(element(app, "streak-outline")), "0")

        app.buttons["play-button"].tap()
        XCTAssertEqual(value(red), "")
    }
}
```

- [ ] **Step 2: Run the UI tests**

Run: `cd ~/c/bsharp/SwiftApp && xcodegen generate && xcodebuild test -project ElisaMusica.xcodeproj -scheme ElisaMusica -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' -derivedDataPath build/dd 2>&1 | grep -E "skipped|Test Case.*(passed|failed)|TEST (SUCCEEDED|FAILED)|error:" | tail -15`
Expected: seven tests pass (the four from Plan 2 and these three), the two `ScreenshotTests` skipped, `** TEST SUCCEEDED **`. If a test fails, decide whether the test or the app is wrong; don't weaken an assertion to make it pass. Then `xcrun simctl shutdown all`.

- [ ] **Step 3: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/UITests/GameFlowUITests.swift
git commit -m "Test the character reveal, the streak outline and the level-up"
```

---

### Task 8: Compare with the web app, screen by screen

The screenshot test from Plan 2 gets the streak and level-up captures; then compare them with the references.

**Files:**
- Modify: `SwiftApp/UITests/ScreenshotTests.swift`

- [ ] **Step 1: Add the captures**

In `SwiftApp/UITests/ScreenshotTests.swift`, three edits.

(a) A longer settle for the outline, which takes 0.9 s to fill. Replace

```swift
    private func keep(_ app: XCUIApplication, _ name: String) {
        Thread.sleep(forTimeInterval: 0.5) // let any animation finish before the capture
```

with

```swift
    private func keep(_ app: XCUIApplication, _ name: String, settle: TimeInterval = 0.5) {
        Thread.sleep(forTimeInterval: settle) // let any animation finish before the capture
```

(b) The new test. Replace

```swift
        keep(app, "state-05-awaiting-play")
    }
}
```

with

```swift
        keep(app, "state-05-awaiting-play")
    }

    func testRewardStates() {
        XCUIDevice.shared.orientation = .portrait
        for streak in [5, 10, 15, 19] {
            let app = launch(["-ElisaStreak", "\(streak)"])
            _ = app.buttons["flag-red"].waitForExistence(timeout: 10)
            keep(app, String(format: "state-06-streak-%02d-of-20", streak), settle: 1.5)
        }
        let app = launch(["-ElisaAnswer", "red", "-ElisaStreak", "19"])
        let red = app.buttons["flag-red"]
        _ = red.waitForExistence(timeout: 10)
        app.buttons["play-button"].tap()
        red.tap()
        _ = app.buttons["flag-blue"].waitForExistence(timeout: 8)
        keep(app, "state-07-after-level-up")
    }
}
```

(c) Nothing else: `testAnswerStates` already captures `state-04-correct`, which now includes the character.

- [ ] **Step 2: Take the screenshots on both simulators**

```bash
cd ~/c/bsharp/SwiftApp
xcodegen generate
for dev in "iPad mini (A17 Pro)" "iPhone 16e"; do
  tag=${dev//[^A-Za-z0-9]/}
  rm -rf "build/shots-$tag.xcresult" "build/shots-$tag"
  TEST_RUNNER_ELISA_SCREENSHOTS=1 xcodebuild test -project ElisaMusica.xcodeproj -scheme ElisaMusica \
    -destination "platform=iOS Simulator,name=$dev" -derivedDataPath build/dd \
    -only-testing:ElisaMusicaUITests/ScreenshotTests/testAnswerStates \
    -only-testing:ElisaMusicaUITests/ScreenshotTests/testRewardStates \
    -resultBundlePath "build/shots-$tag.xcresult" 2>&1 | tail -1
  xcrun xcresulttool export attachments --path "build/shots-$tag.xcresult" --output-path "build/shots-$tag"
done
command ls build/shots-*/
```

Expected: `** TEST SUCCEEDED **` twice, and each folder holds PNGs plus a `manifest.json` that maps each file to its attachment name (`suggestedHumanReadableName`). Use the manifest to find each screenshot by name.

- [ ] **Step 3: Compare each one with its reference, with the Read tool**

| This app's screenshot | Reference in `Reference Material/screenshots/` |
|---|---|
| `state-04-correct` | `state-04-correct-character-reveal.png` |
| `state-06-streak-05-of-20` … `-19-of-20` | `state-06-streak-05-of-20.png` … `state-06-streak-19-of-20.png` |
| `state-07-after-level-up` | `state-07-after-level-up-to-azul.png` |

Check, for each pair:
- `state-04`: a character stands on the right edge beside the play and next buttons, its feet at the top of the flags, with a white name pill under or over its feet inside the red flag's top right corner; the green outline and check on red. The character itself differs (the deck is random); the size, position and pill are what to compare.
- `state-06`: the dark outline starts at the top centre and runs clockwise; at 5/20 about a quarter of the way (the whole top right half and part of the right side), at 10/20 half, at 15/20 three quarters, at 19/20 almost all of it; the rest is the pale track. The outline is the same width as the reference and sits at the screen edge, and no corner is clipped by the iPad's rounded display (if it is, say so in the report; don't change the inset without asking).
- `state-07`: three flags (red, yellow, blue), all dimmed, the arrow up at the play button, and an empty outline (the streak is 0).

Known differences that are **not** bugs (they come in Plan 4): the gear button.

Fix every other difference in the views and repeat Steps 2–3 until they match. Then `xcrun simctl shutdown all`.

- [ ] **Step 4: Make sure the normal test run still skips the screenshots**

```bash
cd ~/c/bsharp/SwiftApp
xcodebuild test -project ElisaMusica.xcodeproj -scheme ElisaMusica -destination 'platform=iOS Simulator,name=iPhone 16e' -derivedDataPath build/dd 2>&1 | grep -E "skipped|TEST (SUCCEEDED|FAILED)" | tail -4
```

Expected: the three `ScreenshotTests` cases reported as skipped, and `** TEST SUCCEEDED **`. Then `xcrun simctl shutdown all`.

- [ ] **Step 5: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/UITests/ScreenshotTests.swift
git status --short SwiftApp
git commit -m "Add streak and level-up screenshots and match the reward screens to the web app"
```

Also commit any view fixes from Step 3 in the same commit (add their paths explicitly). `git status --short SwiftApp` must show nothing under `build/`.

---

### Task 9: README and plan

**Files:**
- Modify: `SwiftApp/README.md`, `SwiftApp/PLAN.md`

- [ ] **Step 1: README**

In `SwiftApp/README.md`, replace

```
Launch arguments for testing: `-ElisaFreshState YES` (throwaway progress), `-ElisaLevel <chord
id>`, `-ElisaAnswer <chord id>` (always ask that chord).
```

with

```
Launch arguments for testing: `-ElisaFreshState YES` (throwaway progress), `-ElisaLevel <chord
id>`, `-ElisaAnswer <chord id>` (always ask that chord), `-ElisaStreak <n>` (start with that
streak; `-ElisaLevel` starts a new streak, so it zeroes this one).
```

- [ ] **Step 2: PLAN.md**

In `SwiftApp/PLAN.md`:
- mark step 8 done: replace `8. **Rewards.**` with `8. **Rewards (done).**`;
- in the "Folder layout" block, replace `Game, ChordFiles, NoteDisplay, FlagLayout, TapUnlock` with `Game, ChordFiles, NoteDisplay, FlagLayout, TapUnlock, Rewards`;
- in the same block, replace `TitleCard, HomeView, Fonts/, Assets.xcassets/` with `TitleCard, HomeView, CharacterReveal, StreakOutline, Fonts/, Assets.xcassets/`.

If any text the plan says to replace is not present verbatim (the files may have drifted), apply the evident intent and report the deviation.

- [ ] **Step 3: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/README.md SwiftApp/PLAN.md
git commit -m "Document the rewards and the streak launch argument"
```

---

### Task 10: Ship it to the iPad (only with the user's approval)

- [ ] **Step 1: Everything green once more**

```bash
cd ~/c/bsharp/SwiftApp/ElisaKit && swift test 2>&1 | tail -2
cd ~/c/bsharp/SwiftApp && xcodebuild test -project ElisaMusica.xcodeproj -scheme ElisaMusica -destination 'platform=iOS Simulator,name=iPhone 16e' -derivedDataPath build/dd 2>&1 | grep -E "TEST (SUCCEEDED|FAILED)" | tail -1
cd ~/c/bsharp/SwiftApp && for t in scripts/deploy/*_test.rb; do ruby "$t" | tail -1; done
xcrun simctl shutdown all
```

Expected: no Swift failures, `** TEST SUCCEEDED **`, every Ruby line `0 failures, 0 errors`.

- [ ] **Step 2: Ask the user**

The deploy needs a clean tree on `main`. If `git status --short` shows the user's web-app changes, ask them to commit or stash them; don't do it yourself. Then ask for approval, explaining the deploy: `SwiftApp/deploy minor --yes --summary "Rewards: characters, streak outline, level-up with the instrument switch."` publishes 0.3.0 to files.chiq.me, commits, tags `elisa-musica-ota-v0.3.0` and pushes `main` to `github`. There is no diagnostics build this time: nothing here needs the on-device log. Wait for an explicit yes.

- [ ] **Step 3: Deploy**

```bash
cd ~/c/bsharp && SwiftApp/deploy minor --yes --summary "Rewards: characters, streak outline, level-up with the instrument switch."
```

If the push reports a rejection but says `github/main is already at …; continuing`, git-sync got there first: check the tag reached the remote with `git ls-remote --tags github 'elisa-musica-ota-v*'`, and push it with `git push github elisa-musica-ota-v0.3.0` if it's missing.

Send the ntfy notification (the `ntfy` skill; see the project memory `ios-deploy-ntfy`) with the install page link `https://files.chiq.me/files/elisa-musica-install.html`. Ask the user to install it on the iPad and confirm:
- a right answer shows a character with its name beside the buttons for about 3 seconds, a wrong one shows none;
- the outline round the screen fills a little with every right answer and empties on a miss (it keeps its fill after quitting and reopening);
- after 20 right answers in a row the next level's flags appear, dimmed, with the arrow at play, and the chords now sound on the other instrument (piano → guitar), which they can check by tapping a flag.

To get to the level-up quickly on the iPad without 20 answers, the user can import a progress file with the streak at 19 (the format is the web app's state download; the streak is `streak` on the profile).

---

## Done when

- `cd SwiftApp/ElisaKit && swift test` passes: the level-up on the saved progress, the character, streak and level-up rules in `Game`, the character files (plus everything from Plans 1–2).
- `xcodebuild test` passes the seven UI flows (the four from Plan 2 and the character reveal, the outline and the level-up); the screenshot test's images match the references apart from the gear button.
- Elisa's iPad runs 0.3.0: a right answer shows a character, the streak fills the outline, and 20 in a row moves her to the next level on the other instrument.
