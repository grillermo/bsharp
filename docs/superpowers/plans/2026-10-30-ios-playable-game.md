# iOS Playable Game Implementation Plan (Plan 2 of 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Elisa can play the game in the native app: the flags of her level, play and next, the answer rules, the play hint, note shapes on black-key levels, real chord audio, and her progress saved on the iPad and imported from the web app.

**Architecture:** Every rule stays in the tested `ElisaKit` package: the saved-progress model (same JSON as the web app), session bookkeeping, a `Game` value type that answers "what does this tap mean", the audio file catalog, note shapes and the grid layout. The app target only glues them to SwiftUI views, an `AVAudioEngine` player and a JSON file in Application Support. XCUITests drive the main flows through launch arguments that force a fresh state, a level and the answer.

**Tech Stack:** Swift 6.2 / SwiftUI, iOS 17+, Swift Testing (ElisaKit), XCTest UI tests, AVFAudio, XcodeGen, Xcode 26.3.

**Spec:** `SwiftApp/PLAN.md` steps 4–7 (step 3's logic was ported in Plan 1). Reference screenshots: `SwiftApp/Reference Material/screenshots/`. The web app source in `src/ts/` is the behavior reference; where this plan and the TypeScript disagree, the TypeScript wins unless the plan says why.

**The three plans:**
1. Foundation (done): ElisaKit logic, skeleton app, OTA deploy, first install.
2. **This plan — Playable game:** persistence and import, audio, game screen, note shapes.
3. Rewards, menus, switch-over: character reveal, streak outline, level-up with the instrument switch, gear menu and panels, iPad polish, moving Elisa over.

---

## Conventions for whoever executes this

- **Repo rules** (`dev/AGENTS_MASTER.md`): commit messages are one short line with **no** `Co-Authored-By` trailer. Work on `main`.
- **git-sync pushes every commit within seconds.** Run the checks *before* committing and never amend; fix forward with a new commit.
- **Never stage files outside `SwiftApp/` or `docs/superpowers/plans/`.** The user may have uncommitted web-app changes in `src/` and `tests/`; leave them alone. Always `git add` explicit paths.
- **A hook blocks any shell command that mentions `.env`** (even inside a heredoc). Don't read `SwiftApp/.env`; write files that mention it with the Write tool.
- **`ls` is aliased to eza here**, so use `command ls` when output matters.
- **Swift tests:** `cd ~/c/bsharp/SwiftApp/ElisaKit && swift test`. **App build:**
  `cd ~/c/bsharp/SwiftApp && xcodegen generate && xcodebuild -project ElisaMusica.xcodeproj -scheme ElisaMusica -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd build 2>&1 | tail -3`
- **SourceKit diagnostics in the editor** (`No such module 'Testing'`, `Cannot find 'Theme' in scope`) are noise from a stale index; trust `swift test` and `xcodebuild`.
- Simulators on this Mac: `iPad mini (A17 Pro)` and `iPhone 16e`.

## What Plan 1 left in place

- `ElisaKit`: `Chords` (`Chord.id/spanishName/symbol/notes/hex`, `Chords.all/ids/firstBlackIndex/inPlay(upTo:)`), `Instrument` (`.piano` = `piano_1`, `.guitar`, `.guitarStrummed`, `chordFolder`), `Streak` (`target`, `next(_:correct:)`), `Progression`, `ConfusionMatrix` (`[String: [String: Double]]`), `Scoring`, `AdaptiveWeights` (`merge`, `coefficients`, `pick(_:weights:random:)`), `Characters` (`revealSeconds = 3.0`), `CharacterDeck`, `AppQuickAction`, `DevLog` (`DevLog.event(kind, fields)`).
- App: `ElisaMusicaApp` (+ `AppDelegate`), `QuickActions`, `Theme` (`ink`, `edge`, `skyTop`, `skyBottom`, `grass`, `grassDark`, `headline(_:)`, `text(_:bold:)`, `Color(hex:)`), `SkyBackground`, `TitleCard` (`fontSize(for:)`), `HomeView`.

## Behavior being ported (read once)

From `src/ts/game.ts`, `state.ts`, `session_cleanup.ts`, `onboarding.ts`, `main.ts`:

- **Level N shows the first N+1 chords.** The default level is `yellow` (red + yellow).
- **A question** is a random chord of the level (weighted by the adaptive coefficients when the profile's `chord_selection_mode` is `adaptive`). It is loaded but not played.
- **Play** sounds the question. From then on a flag tap is an answer. (`setPlayedAfter(duration * 0.8)` passes seconds to `setTimeout`, which takes milliseconds, so in practice answers count about 1 ms after play is pressed. The port keeps that: answers count as soon as play is pressed.)
- **Every flag tap sounds that flag's chord**, cutting off whatever was playing, except while the flags are dimmed.
- **A tap before play, or after the right answer is in,** only sounds the chord.
- **A wrong answer** counts (stats + confusion matrix), resets the streak to 0 and is not marked; she keeps guessing.
- **The right answer** counts, adds one to the streak, puts a green outline and check on the flag for `Characters.revealSeconds` (3 s; Plan 3 adds the character in that time), then the next question is loaded **without playing** and the flags dim (grayscale, 40 % opacity) until play is pressed. A tap on a dimmed flag does nothing at all.
- **The play hint** (an arrow up at the play button, no text) shows when the game starts or the level changes, if the profile's `enable_onboarding_hints` is on, and goes away when play is pressed.
- **The next button never activates** (`game.ts` only ever adds `.deactivated`); it is drawn at 35 % opacity and does nothing.
- **The stats bar and the reaction face are hidden** on the main screen (`_bluey.scss`), so they are not ported.
- **Sessions:** a profile's `stats` is the current session. A session idle for 30 minutes is over. `resetStats(done)` files the session in the history (unless it is a finished one with no answers) and starts a new one. Changing level files the current session unfinished and resumes the new level's last unfinished session, if any. At startup a stale session is ended and the history is cleaned.
- **Notes on flags:** `show_chord_mode` = `always` | `black_only` (default: only from gray on) | `never`; `reveal_chord_mode` = `always` (default) | `after_guess` (only while a right answer is on screen); `chord_display_mode` = `shapes_and_letters` (default) | `shapes_only` | `letters_only`.
- **Grid** (`#flag-holder` in `_bluey.scss`): portrait 1 column below 4 flags, 2 columns up to 9, 3 above 9; landscape 3 columns up to 9, 5 above. Rows share the height left below the controls.

## Names used everywhere

| Thing | Value |
|---|---|
| Saved progress file | `Application Support/ElisaMusica/progress.json`, format `{"state": …, "history": …}` (the web app's state download) |
| Backups beside it | `progress.unreadable-<unix time>.json`, `progress.before-import-<unix time>.json` |
| Launch arguments | `-ElisaFreshState YES`, `-ElisaLevel <chord id>`, `-ElisaAnswer <chord id>` |
| Accessibility ids | `play-button`, `play-hint`, `flag-<chord id>` (value `correct`, `dimmed` or empty) |
| Note shape assets | `note-<NoteShape rawValue>` in `App/Assets.xcassets` (18 SVG template images) |
| Audio in the bundle | `chords/piano/*.mp3`, `chords/guitar/*.mp3`, `chords/guitar-strummed/*.mp3` (folder reference to `../static/chords`) |
| UI test target | `ElisaMusicaUITests`, sources in `SwiftApp/UITests/` |

## File structure

```
SwiftApp/
  project.yml                         + chords folder resource, + UI test target
  ElisaKit/Sources/ElisaKit/
    SavedProgress.swift               Defaults, JSONValue, SessionStats, Profile, AppState, SavedProgress
    ProgressStore.swift               load/save the JSON file, decode a web download, backups
    Sessions.swift                    SavedProgress: answers, sessions, level changes, cleanup, adaptive weights
    Game.swift                        the question, play, what a tap means, the reveal, the hint
    ChordFiles.swift                  recording paths per instrument and chord
    NoteDisplay.swift                 NoteShape, NoteMark, which notes show and how
    FlagLayout.swift                  grid columns
    TapUnlock.swift                   six quick taps (hidden parent gesture)
  ElisaKit/Tests/ElisaKitTests/
    Fixtures.swift                    a web app state download
    SavedProgressTests.swift, ProgressStoreTests.swift, SessionsTests.swift, GameTests.swift,
    ChordFilesTests.swift, NoteDisplayTests.swift, FlagLayoutTests.swift, TapUnlockTests.swift
  App/
    ElisaMusicaApp.swift              owns the GameModel
    LaunchOptions.swift               launch arguments for tests and screenshots
    GameModel.swift                   Game + ProgressStore + ChordPlayer + the reveal timer
    ChordPlayer.swift                 AVAudioEngine, all takes of the instrument preloaded
    Metrics.swift                     the web app's clamp() sizes
    ControlsBar.swift                 round play / next buttons
    PlayHint.swift                    the first-run arrow
    FlagGrid.swift                    FlagGrid, FlagView, CorrectCheck
    NoteMarks.swift                   NoteMarks, NoteMarkView
    HomeView.swift                    the screen, plus the hidden progress import
    Theme.swift                       + inkPressed, noteInk, noteLetter, correctGreen
    Assets.xcassets/note-*.imageset   generated once by scripts/note-shapes.py
  scripts/note-shapes.py              writes the note-shape imagesets from the web app's clip paths
  UITests/GameFlowUITests.swift, UITests/ScreenshotTests.swift
```

---

### Task 1: The saved-progress model

The web app keeps two `localStorage` keys, `bsharp_state` and `bsharp_session_history`, and its hidden download link (`ui.ts` `downloadState`) writes both as `{"state": …, "history": …}`. This task models that JSON so a download decodes as is, missing fields get the web app's defaults (`initializeProfileDefaults`), and an encode/decode round trip loses nothing.

Two traps: JSON object keys are strings, so profiles are keyed `"100"`, not `100` (a Swift `[Int: Profile]` would encode as an array); and Foundation already has a type called `Progress`, so the top-level type is `SavedProgress`.

**Files:**
- Create: `SwiftApp/ElisaKit/Sources/ElisaKit/SavedProgress.swift`
- Create: `SwiftApp/ElisaKit/Tests/ElisaKitTests/Fixtures.swift`
- Test: `SwiftApp/ElisaKit/Tests/ElisaKitTests/SavedProgressTests.swift`

- [ ] **Step 1: Write the fixture**

`SwiftApp/ElisaKit/Tests/ElisaKitTests/Fixtures.swift`:

```swift
import Foundation

enum Fixtures {
    /// A download from the web app's hidden state link (ui.ts downloadState), trimmed: a full
    /// profile mid-session at blue, a second profile saved by an old version with only a name
    /// and an icon, and one finished session at yellow.
    static let webExport = Data("""
    {
      "state": {
        "profiles": {
          "100": {
            "id": 100, "name": "Elisa", "icon": "fa-paw", "target_number": 25,
            "show_chord_mode": "black_only", "reveal_chord_mode": "always",
            "chord_display_mode": "shapes_and_letters", "single_note_mode": "white_only_on_black",
            "single_note_correctness_mode": "only_correct", "persist_reaction_face": true,
            "enable_onboarding_hints": true, "color_scheme": "light", "chord_selection_mode": "random",
            "stats": {
              "current_chord": "blue", "start_time": 1793380000.5, "updated_time": 1793380100.25,
              "correct": 3, "identifications": 4,
              "confusion_matrix": {"red": {"red": 2}, "blue": {"blue": 1, "red": 1}},
              "notes": {"correct": 1, "identifications": 1, "confusion_matrix": {"gray": {"C#4": {"C#4": 1}}}},
              "done": false
            },
            "current_chord": "blue", "current_instrument": "guitar", "streak": 7
          },
          "101": {"id": 101, "name": "Papá", "icon": "fa-user"}
        },
        "current_chord": "blue",
        "current_profile": 100
      },
      "history": {
        "100": {
          "yellow": [{
            "current_chord": "yellow", "start_time": 1793300000, "updated_time": 1793300500,
            "correct": 18, "identifications": 20,
            "confusion_matrix": {"red": {"red": 9, "yellow": 1}, "yellow": {"yellow": 9, "red": 1}},
            "notes": {"correct": 0, "identifications": 0, "confusion_matrix": {}},
            "done": true
          }]
        }
      }
    }
    """.utf8)
}
```

- [ ] **Step 2: Write the failing tests**

`SwiftApp/ElisaKit/Tests/ElisaKitTests/SavedProgressTests.swift`:

```swift
import Foundation
import Testing
@testable import ElisaKit

@Suite struct SavedProgressTests {
    private func decode(_ json: String) throws -> SavedProgress {
        try JSONDecoder().decode(SavedProgress.self, from: Data(json.utf8))
    }

    @Test func decodesAWebAppDownload() throws {
        let progress = try JSONDecoder().decode(SavedProgress.self, from: Fixtures.webExport)
        #expect(progress.state.currentProfile == 100)
        #expect(progress.state.currentChord == "blue")
        let elisa = try #require(progress.state.profiles["100"])
        #expect(elisa.name == "Elisa")
        #expect(elisa.instrument == .guitar)
        #expect(elisa.streak == 7)
        #expect(elisa.stats.correct == 3)
        #expect(elisa.stats.identifications == 4)
        #expect(elisa.stats.startTime == 1793380000.5)
        #expect(elisa.stats.confusionMatrix["blue"]?["red"] == 1)
        let yellow = try #require(progress.history["100"]?["yellow"])
        #expect(yellow.count == 1)
        #expect(yellow[0].done)
        #expect(yellow[0].identifications == 20)
    }

    @Test func aProfileFromAnOldVersionGetsTheDefaults() throws {
        let progress = try JSONDecoder().decode(SavedProgress.self, from: Fixtures.webExport)
        let papa = try #require(progress.state.profiles["101"])
        #expect(papa.name == "Papá")
        #expect(papa.showChordMode == "black_only")
        #expect(papa.revealChordMode == "always")
        #expect(papa.chordDisplayMode == "shapes_and_letters")
        #expect(papa.chordSelectionMode == "random")
        #expect(papa.enableOnboardingHints)
        #expect(papa.persistReactionFace)
        #expect(papa.targetNumber == 25)
        #expect(papa.currentChord == "yellow")
        #expect(papa.instrument == .piano)
        #expect(papa.streak == nil)
    }

    @Test func aRoundTripLosesNothing() throws {
        let progress = try JSONDecoder().decode(SavedProgress.self, from: Fixtures.webExport)
        let again = try JSONDecoder().decode(SavedProgress.self, from: JSONEncoder().encode(progress))
        #expect(again == progress)
    }

    @Test func theSingleNoteTallyIsKeptAsIs() throws {
        let progress = try JSONDecoder().decode(SavedProgress.self, from: Fixtures.webExport)
        let notes = try #require(progress.state.profiles["100"]).stats.notes
        // Counts must stay numbers: a JSON 1 decoded as `true` would change the data.
        #expect(notes == .object([
            "correct": .number(1),
            "identifications": .number(1),
            "confusion_matrix": .object(["gray": .object(["C#4": .object(["C#4": .number(1)])])]),
        ]))
    }

    @Test func anUnknownInstrumentPlaysPianoButIsKept() throws {
        let progress = try decode("""
        {"state": {"profiles": {"100": {"id": 100, "name": "E", "icon": "fa-paw",
          "current_instrument": "kazoo"}}, "current_chord": "yellow", "current_profile": 100},
         "history": {}}
        """)
        let profile = try #require(progress.state.profiles["100"])
        #expect(profile.instrument == .piano)
        #expect(profile.currentInstrument == "kazoo")
    }

    @Test func anEmptyHistorySavedAsAnArrayDecodes() throws {
        // getSessionHistory() treats a stored [] as {}.
        let progress = try decode("""
        {"state": {"profiles": {}, "current_chord": "yellow", "current_profile": 100}, "history": []}
        """)
        #expect(progress.history.isEmpty)
    }

    @Test func aMissingCurrentProfileIsTheGuest() throws {
        let progress = try decode("""
        {"state": {"profiles": {}, "current_chord": "yellow"}, "history": {}}
        """)
        #expect(progress.state.currentProfile == 100)
    }

    @Test func noStreakIsLeftOutOfTheJSON() throws {
        let profile = Profile(id: 100, name: "Elisa", icon: "fa-paw", now: 0)
        let json = String(decoding: try JSONEncoder().encode(profile), as: UTF8.self)
        #expect(!json.contains("streak"))
        #expect(json.contains("\"current_instrument\":\"piano_1\""))
    }

    @Test func aFreshStartHasOneGuestProfileAtYellow() {
        let progress = SavedProgress.fresh(now: 1000)
        #expect(progress.state.currentProfile == 100)
        #expect(progress.state.currentChord == "yellow")
        #expect(Array(progress.state.profiles.keys) == ["100"])
        let elisa = progress.state.profiles["100"]
        #expect(elisa?.name == "Elisa")
        #expect(elisa?.icon == "fa-paw")
        #expect(elisa?.stats.startTime == 1000)
        #expect(elisa?.stats.currentChord == "yellow")
        #expect(progress.history.isEmpty)
    }
}
```

- [ ] **Step 3: Run them to make sure they fail**

Run: `cd ~/c/bsharp/SwiftApp/ElisaKit && swift test --filter SavedProgressTests`
Expected: FAIL, `cannot find 'SavedProgress' in scope`.

- [ ] **Step 4: Write the model**

`SwiftApp/ElisaKit/Sources/ElisaKit/SavedProgress.swift`:

```swift
import Foundation

/// The web app's defaults (src/ts/state.ts).
public enum Defaults {
    public static let level = "yellow"
    public static let guestProfileID = 100
    public static let targetNumber = 25
    public static let showChordMode = "black_only"
    public static let revealChordMode = "always"
    public static let chordDisplayMode = "shapes_and_letters"
    public static let singleNoteMode = "white_only_on_black"
    public static let singleNoteCorrectnessMode = "only_correct"
    public static let persistReactionFace = true
    public static let enableOnboardingHints = true
    public static let colorScheme = "light"
    public static let chordSelectionMode = "random"
    /// A session idle this long (seconds) is over (SESSION_TIMEOUT_TIME_SECONDS).
    public static let sessionTimeout = 30.0 * 60
}

/// Any JSON value, kept as it came. For data the app carries along but never reads.
public enum JSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

/// One session at one level (SessionStats in src/ts/types.ts). Times are Unix seconds.
public struct SessionStats: Codable, Equatable, Sendable {
    public var currentChord: String
    public var startTime: Double
    public var updatedTime: Double
    public var correct: Int
    public var identifications: Int
    public var confusionMatrix: ConfusionMatrix
    /// The single-note trainer's tally. That trainer is switched off in the web app; the value
    /// is carried as is so a round trip through this app loses nothing.
    public var notes: JSONValue
    /// Finished sessions are never resumed.
    public var done: Bool

    static let emptyNotes: JSONValue = .object([
        "correct": .number(0), "identifications": .number(0), "confusion_matrix": .object([:]),
    ])

    /// A new, empty session (newStats).
    public init(currentChord: String, now: Double) {
        self.currentChord = currentChord
        startTime = now
        updatedTime = now
        correct = 0
        identifications = 0
        confusionMatrix = [:]
        notes = Self.emptyNotes
        done = false
    }

    enum CodingKeys: String, CodingKey {
        case currentChord = "current_chord"
        case startTime = "start_time"
        case updatedTime = "updated_time"
        case correct, identifications
        case confusionMatrix = "confusion_matrix"
        case notes, done
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        currentChord = try c.decodeIfPresent(String.self, forKey: .currentChord) ?? Defaults.level
        startTime = try c.decodeIfPresent(Double.self, forKey: .startTime) ?? 0
        updatedTime = try c.decodeIfPresent(Double.self, forKey: .updatedTime) ?? startTime
        correct = try c.decodeIfPresent(Int.self, forKey: .correct) ?? 0
        identifications = try c.decodeIfPresent(Int.self, forKey: .identifications) ?? 0
        confusionMatrix = try c.decodeIfPresent(ConfusionMatrix.self, forKey: .confusionMatrix) ?? [:]
        notes = try c.decodeIfPresent(JSONValue.self, forKey: .notes) ?? Self.emptyNotes
        done = try c.decodeIfPresent(Bool.self, forKey: .done) ?? false
    }
}

/// One child's settings and progress (Profile in src/ts/types.ts). Modes stay strings, as the
/// web app saves them, so a value this app doesn't know survives a round trip.
public struct Profile: Codable, Equatable, Sendable {
    public var id: Int
    public var name: String
    public var icon: String
    public var targetNumber: Int
    /// always | black_only | never
    public var showChordMode: String
    /// always | after_guess
    public var revealChordMode: String
    /// shapes_and_letters | shapes_only | letters_only
    public var chordDisplayMode: String
    public var singleNoteMode: String
    public var singleNoteCorrectnessMode: String
    public var persistReactionFace: Bool
    public var enableOnboardingHints: Bool
    public var colorScheme: String
    /// random | adaptive
    public var chordSelectionMode: String
    /// The current session.
    public var stats: SessionStats
    /// Her level: the last chord in play.
    public var currentChord: String
    /// An `Instrument` raw value.
    public var currentInstrument: String
    /// Correct answers in a row at the current level; absent until the first answer.
    public var streak: Int?

    /// A new profile with the web app's defaults (newProfile).
    public init(id: Int, name: String, icon: String, now: Double) {
        self.id = id
        self.name = name
        self.icon = icon
        targetNumber = Defaults.targetNumber
        showChordMode = Defaults.showChordMode
        revealChordMode = Defaults.revealChordMode
        chordDisplayMode = Defaults.chordDisplayMode
        singleNoteMode = Defaults.singleNoteMode
        singleNoteCorrectnessMode = Defaults.singleNoteCorrectnessMode
        persistReactionFace = Defaults.persistReactionFace
        enableOnboardingHints = Defaults.enableOnboardingHints
        colorScheme = Defaults.colorScheme
        chordSelectionMode = Defaults.chordSelectionMode
        stats = SessionStats(currentChord: Defaults.level, now: now)
        currentChord = Defaults.level
        currentInstrument = Instrument.piano.rawValue
        streak = nil
    }

    /// The profile a fresh install starts with, as in the web app.
    public static func guest(now: Double) -> Profile {
        Profile(id: Defaults.guestProfileID, name: "Elisa", icon: "fa-paw", now: now)
    }

    /// The instrument to play; piano when the saved id is one this app doesn't know.
    public var instrument: Instrument {
        Instrument(rawValue: currentInstrument) ?? .piano
    }

    enum CodingKeys: String, CodingKey {
        case id, name, icon
        case targetNumber = "target_number"
        case showChordMode = "show_chord_mode"
        case revealChordMode = "reveal_chord_mode"
        case chordDisplayMode = "chord_display_mode"
        case singleNoteMode = "single_note_mode"
        case singleNoteCorrectnessMode = "single_note_correctness_mode"
        case persistReactionFace = "persist_reaction_face"
        case enableOnboardingHints = "enable_onboarding_hints"
        case colorScheme = "color_scheme"
        case chordSelectionMode = "chord_selection_mode"
        case stats
        case currentChord = "current_chord"
        case currentInstrument = "current_instrument"
        case streak
    }

    /// Missing fields get the defaults, as initializeProfileDefaults() fills them in.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? Defaults.guestProfileID
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Elisa"
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "fa-paw"
        targetNumber = try c.decodeIfPresent(Int.self, forKey: .targetNumber) ?? Defaults.targetNumber
        showChordMode = try c.decodeIfPresent(String.self, forKey: .showChordMode) ?? Defaults.showChordMode
        revealChordMode = try c.decodeIfPresent(String.self, forKey: .revealChordMode) ?? Defaults.revealChordMode
        chordDisplayMode = try c.decodeIfPresent(String.self, forKey: .chordDisplayMode) ?? Defaults.chordDisplayMode
        singleNoteMode = try c.decodeIfPresent(String.self, forKey: .singleNoteMode) ?? Defaults.singleNoteMode
        singleNoteCorrectnessMode = try c.decodeIfPresent(String.self, forKey: .singleNoteCorrectnessMode)
            ?? Defaults.singleNoteCorrectnessMode
        persistReactionFace = try c.decodeIfPresent(Bool.self, forKey: .persistReactionFace)
            ?? Defaults.persistReactionFace
        enableOnboardingHints = try c.decodeIfPresent(Bool.self, forKey: .enableOnboardingHints)
            ?? Defaults.enableOnboardingHints
        colorScheme = try c.decodeIfPresent(String.self, forKey: .colorScheme) ?? Defaults.colorScheme
        chordSelectionMode = try c.decodeIfPresent(String.self, forKey: .chordSelectionMode)
            ?? Defaults.chordSelectionMode
        currentChord = try c.decodeIfPresent(String.self, forKey: .currentChord) ?? Defaults.level
        stats = try c.decodeIfPresent(SessionStats.self, forKey: .stats)
            ?? SessionStats(currentChord: currentChord, now: 0)
        currentInstrument = try c.decodeIfPresent(String.self, forKey: .currentInstrument)
            ?? Instrument.piano.rawValue
        streak = try c.decodeIfPresent(Int.self, forKey: .streak)
    }
}

/// The web app's `bsharp_state`.
public struct AppState: Codable, Equatable, Sendable {
    /// Keyed by profile id as a string: JSON object keys are strings, and the web app's
    /// `Record<number, Profile>` is saved that way.
    public var profiles: [String: Profile]
    /// The level in play.
    public var currentChord: String
    public var currentProfile: Int

    public init(profiles: [String: Profile], currentChord: String, currentProfile: Int) {
        self.profiles = profiles
        self.currentChord = currentChord
        self.currentProfile = currentProfile
    }

    enum CodingKeys: String, CodingKey {
        case profiles
        case currentChord = "current_chord"
        case currentProfile = "current_profile"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profiles = try c.decodeIfPresent([String: Profile].self, forKey: .profiles) ?? [:]
        currentChord = try c.decodeIfPresent(String.self, forKey: .currentChord) ?? Defaults.level
        currentProfile = try c.decodeIfPresent(Int.self, forKey: .currentProfile) ?? Defaults.guestProfileID
    }
}

/// Profile id → level (chord id) → that level's sessions, oldest first. The web app's
/// `bsharp_session_history`.
public typealias SessionHistory = [String: [String: [SessionStats]]]

/// Everything saved: the same JSON as the web app's state download.
public struct SavedProgress: Codable, Equatable, Sendable {
    public var state: AppState
    public var history: SessionHistory

    public init(state: AppState, history: SessionHistory) {
        self.state = state
        self.history = history
    }

    /// A first launch: one guest profile, "Elisa", at yellow.
    public static func fresh(now: Double) -> SavedProgress {
        let guest = Profile.guest(now: now)
        return SavedProgress(
            state: AppState(profiles: [String(guest.id): guest], currentChord: Defaults.level,
                            currentProfile: guest.id),
            history: [:]
        )
    }

    enum CodingKeys: String, CodingKey {
        case state, history
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        state = try c.decode(AppState.self, forKey: .state)
        // The web app can have stored an empty history as [] (getSessionHistory treats it as {}).
        if (try? c.decode([JSONValue].self, forKey: .history)) != nil {
            history = [:]
        } else {
            history = try c.decodeIfPresent(SessionHistory.self, forKey: .history) ?? [:]
        }
    }
}
```

- [ ] **Step 5: Run the tests and make sure they pass**

Run: `cd ~/c/bsharp/SwiftApp/ElisaKit && swift test`
Expected: PASS, every suite. If `theSingleNoteTallyIsKeptAsIs` fails with `.bool(true)` in place of `.number(1)`, this Foundation decodes numbers as Bool: in `JSONValue.init(from:)` try `Double` before `Bool`, then re-run.

- [ ] **Step 6: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/ElisaKit/Sources/ElisaKit/SavedProgress.swift SwiftApp/ElisaKit/Tests/ElisaKitTests/Fixtures.swift SwiftApp/ElisaKit/Tests/ElisaKitTests/SavedProgressTests.swift
git commit -m "Model the web app's saved progress in ElisaKit"
```

---

### Task 2: The progress file

One JSON file holds everything. A file that can't be read is moved aside, never overwritten by the next save, and an import keeps a copy of what it replaces.

**Files:**
- Create: `SwiftApp/ElisaKit/Sources/ElisaKit/ProgressStore.swift`
- Test: `SwiftApp/ElisaKit/Tests/ElisaKitTests/ProgressStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

`SwiftApp/ElisaKit/Tests/ElisaKitTests/ProgressStoreTests.swift`:

```swift
import Foundation
import Testing
@testable import ElisaKit

@Suite struct ProgressStoreTests {
    let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    var store: ProgressStore { ProgressStore(url: folder.appending(path: "progress.json")) }

    private func files() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)).sorted()
    }

    @Test func nothingSavedLoadsAsNil() {
        #expect(store.load(now: 1000) == nil)
    }

    @Test func whatIsSavedLoadsBack() throws {
        let progress = try ProgressStore.decode(Fixtures.webExport)
        try store.save(progress)
        #expect(store.load(now: 1000) == progress)
    }

    @Test func anUnreadableFileIsMovedAsideNotLost() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.url)
        #expect(store.load(now: 1000) == nil)
        #expect(try files() == ["progress.unreadable-1000.json"])
    }

    @Test func archiveKeepsACopyBesideTheFile() throws {
        try store.save(.fresh(now: 5))
        try store.archive("before-import", now: 2000)
        #expect(try files() == ["progress.before-import-2000.json", "progress.json"])
    }

    @Test func archivingNothingDoesNothing() throws {
        try store.archive("before-import", now: 2000)
        #expect(!FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)))
    }

    @Test func aWebAppDownloadDecodes() throws {
        let progress = try ProgressStore.decode(Fixtures.webExport)
        #expect(progress.state.profiles.count == 2)
    }

    @Test func somethingElseDoesNot() {
        #expect(throws: (any Error).self) { try ProgressStore.decode(Data("{\"hello\": 1}".utf8)) }
    }
}
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `cd ~/c/bsharp/SwiftApp/ElisaKit && swift test --filter ProgressStoreTests`
Expected: FAIL, `cannot find 'ProgressStore' in scope`.

- [ ] **Step 3: Write the store**

`SwiftApp/ElisaKit/Sources/ElisaKit/ProgressStore.swift`:

```swift
import Foundation

/// The saved progress on disk: one JSON file in the shape of the web app's state download
/// (`{"state": …, "history": …}`), so a download from bluey.chiq.me imports as is.
public struct ProgressStore: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// Application Support/ElisaMusica/progress.json
    public static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "ElisaMusica/progress.json")
    }

    /// The saved progress, or nil when there is none. A file that can't be read is moved aside
    /// (`progress.unreadable-<time>.json`) so the next save doesn't overwrite it.
    public func load(now: Double) -> SavedProgress? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        if let progress = try? Self.decode(data) { return progress }
        try? FileManager.default.moveItem(at: url, to: sibling("unreadable", now: now))
        return nil
    }

    public func save(_ progress: SavedProgress) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Self.encode(progress).write(to: url, options: .atomic)
    }

    /// Copies the file to `progress.<label>-<time>.json`, e.g. before an import replaces it.
    public func archive(_ label: String, now: Double) throws {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        try FileManager.default.copyItem(at: url, to: sibling(label, now: now))
    }

    /// A web app download, or a copy of this app's own file.
    public static func decode(_ data: Data) throws -> SavedProgress {
        try JSONDecoder().decode(SavedProgress.self, from: data)
    }

    public static func encode(_ progress: SavedProgress) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(progress)
    }

    private func sibling(_ label: String, now: Double) -> URL {
        url.deletingLastPathComponent().appending(path: "progress.\(label)-\(Int(now)).json")
    }
}
```

- [ ] **Step 4: Run the tests and make sure they pass**

Run: `cd ~/c/bsharp/SwiftApp/ElisaKit && swift test`
Expected: PASS. `somethingElseDoesNot` passes because `state` is the one required key.

- [ ] **Step 5: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/ElisaKit/Sources/ElisaKit/ProgressStore.swift SwiftApp/ElisaKit/Tests/ElisaKitTests/ProgressStoreTests.swift
git commit -m "Save progress to a JSON file in the web app's download format"
```

---

### Task 3: Sessions, answers and level changes

The bookkeeping half of `game.ts`, `state.ts`, `stats.ts` and `session_cleanup.ts`, as `mutating` methods on `SavedProgress`. Time is passed in (`now:`) so tests pin it.

Session rules to keep exactly:
- `saveSession` appends the current stats to the level's history only when the last entry has a different `startTime` (`saveSessionHistory`).
- `resetStats(done:)` sets `done`, files the session unless it is finished **and** empty, and starts a new one (`resetStats`).
- `resumeSession` pops the level's last session into `stats` if it isn't done, and ends it at once if it is more than 30 minutes old (`retrieveSavedStats`).
- `changeLevel(to:)` zeroes the streak when the profile's level changes; when the level in play changes, it files the session unfinished, moves, and resumes (`changeSelector`).
- `cleanHistory` drops the `""` level, drops sessions with no answers unless unfinished and recent, relabels each session with its level, and drops a session identical (same answers and start) to the one before (`cleanSessionHistory`).
- `adaptiveWeights` merges the level's sessions newest first up to 140 answers, scaling the session that crosses the limit (`getCurrentCoefficients`).

**Files:**
- Create: `SwiftApp/ElisaKit/Sources/ElisaKit/Sessions.swift`
- Test: `SwiftApp/ElisaKit/Tests/ElisaKitTests/SessionsTests.swift`

- [ ] **Step 1: Write the failing tests**

`SwiftApp/ElisaKit/Tests/ElisaKitTests/SessionsTests.swift`:

```swift
import Testing
@testable import ElisaKit

private let t0 = 1_793_400_000.0
private func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.005 }

private func session(_ chord: String, start: Double, answers: Int, done: Bool,
                     updated: Double? = nil, matrix: ConfusionMatrix = [:]) -> SessionStats {
    var s = SessionStats(currentChord: chord, now: start)
    s.identifications = answers
    s.correct = answers
    s.done = done
    s.updatedTime = updated ?? start
    s.confusionMatrix = matrix
    return s
}

@Suite struct SessionsTests {
    @Test func anAnswerIsCountedWithItsConfusionAndStreak() {
        var p = SavedProgress.fresh(now: t0)
        #expect(p.recordAnswer(played: "red", chosen: "yellow", now: t0 + 10) == false)
        #expect(p.recordAnswer(played: "red", chosen: "red", now: t0 + 20))
        #expect(p.recordAnswer(played: "yellow", chosen: "yellow", now: t0 + 30))
        let stats = p.profile.stats
        #expect(stats.identifications == 3)
        #expect(stats.correct == 2)
        #expect(stats.confusionMatrix == ["red": ["yellow": 1, "red": 1], "yellow": ["yellow": 1]])
        #expect(stats.startTime == t0 + 10) // the first answer starts the session
        #expect(stats.updatedTime == t0 + 30)
        #expect(p.profile.streak == 2)
        p.recordAnswer(played: "red", chosen: "yellow", now: t0 + 40)
        #expect(p.profile.streak == 0)
    }

    @Test func endingASessionWithAnswersFilesIt() {
        var p = SavedProgress.fresh(now: t0)
        p.recordAnswer(played: "red", chosen: "red", now: t0 + 1)
        p.resetStats(done: true, now: t0 + 2)
        #expect(p.levelHistory.count == 1)
        #expect(p.levelHistory[0].done)
        #expect(p.levelHistory[0].identifications == 1)
        #expect(p.profile.stats.identifications == 0)
        #expect(p.profile.stats.startTime == t0 + 2)
    }

    @Test func aFinishedEmptySessionIsNotFiled() {
        var p = SavedProgress.fresh(now: t0)
        p.resetStats(done: true, now: t0 + 2)
        #expect(p.levelHistory.isEmpty)
    }

    @Test func anUnfinishedSessionIsFiledEvenIfEmpty() {
        var p = SavedProgress.fresh(now: t0)
        p.resetStats(done: false, now: t0 + 2)
        #expect(p.levelHistory.count == 1)
    }

    @Test func savingTheSameSessionTwiceFilesItOnce() {
        var p = SavedProgress.fresh(now: t0)
        p.saveSession()
        p.saveSession()
        #expect(p.levelHistory.count == 1)
    }

    @Test func changingLevelParksTheSessionAndComingBackResumesIt() {
        var p = SavedProgress.fresh(now: t0)
        p.recordAnswer(played: "red", chosen: "red", now: t0 + 1)
        p.changeLevel(to: "blue", now: t0 + 2)
        #expect(p.state.currentChord == "blue")
        #expect(p.profile.currentChord == "blue")
        #expect(p.profile.stats.currentChord == "blue")
        #expect(p.profile.stats.identifications == 0)
        #expect(p.profile.streak == 0)
        #expect(p.history["100"]?["yellow"]?.count == 1)
        #expect(p.history["100"]?["yellow"]?.first?.done == false)

        p.changeLevel(to: "yellow", now: t0 + 3)
        #expect(p.profile.stats.identifications == 1)
        #expect(p.history["100"]?["yellow"]?.isEmpty == true)
        #expect(p.history["100"]?["blue"]?.count == 1)
    }

    @Test func aStaleParkedSessionIsEndedWhenResumed() {
        var p = SavedProgress.fresh(now: t0)
        p.recordAnswer(played: "red", chosen: "red", now: t0 + 1)
        p.changeLevel(to: "blue", now: t0 + 2)
        p.changeLevel(to: "yellow", now: t0 + 2 + 3600)
        #expect(p.profile.stats.identifications == 0)
        #expect(p.history["100"]?["yellow"]?.count == 1)
        #expect(p.history["100"]?["yellow"]?.first?.done == true)
    }

    @Test func thirtyMinutesIsStillRecent() {
        #expect(SavedProgress.isRecent(t0, now: t0 + 1800))
        #expect(!SavedProgress.isRecent(t0, now: t0 + 1801))
    }

    @Test func cleaningDropsEmptyAndDuplicateSessions() {
        var p = SavedProgress.fresh(now: t0)
        p.history["100"] = [
            "": [session("red", start: 1, answers: 3, done: true)],
            "yellow": [
                session("yellow", start: 5, answers: 0, done: true),                  // empty: dropped
                session("yellow", start: 10, answers: 5, done: true),                 // kept
                session("yellow", start: 10, answers: 5, done: true),                 // duplicate: dropped
                session("blue", start: 20, answers: 3, done: true),                   // kept, relabelled
                session("yellow", start: 30, answers: 0, done: false, updated: t0 - 60),   // recent: kept
                session("yellow", start: 40, answers: 0, done: false, updated: t0 - 3600), // stale: dropped
            ],
        ]
        p.cleanHistory(now: t0)
        #expect(p.history["100"]?[""] == nil)
        let yellow = p.history["100"]?["yellow"] ?? []
        #expect(yellow.map(\.startTime) == [10, 20, 30])
        #expect(yellow.allSatisfy { $0.currentChord == "yellow" })
    }

    @Test func adaptiveWeightsComeFromTheLevelsSessions() {
        var p = SavedProgress.fresh(now: t0)
        p.history["100"] = ["yellow": [
            session("yellow", start: 1, answers: 40, done: true,
                    matrix: ["red": ["red": 12, "yellow": 8], "yellow": ["yellow": 20]]),
        ]]
        let w = p.adaptiveWeights()
        #expect(close(w[0], 0.583))
        #expect(close(w[1], 0.417))
    }

    @Test func adaptiveWeightsLookBackOnly140Answers() {
        var p = SavedProgress.fresh(now: t0)
        p.history["100"] = ["yellow": [
            session("yellow", start: 1, answers: 100, done: true, matrix: ["yellow": ["red": 100]]),
            session("yellow", start: 2, answers: 100, done: true, matrix: ["red": ["red": 100]]),
        ]]
        // The newest 100 answers count in full, the older session is scaled to the 40 left:
        // red 100 + 40 × 1.5 = 160, yellow 40 × 5 = 200.
        let w = p.adaptiveWeights()
        #expect(close(w[0], 160.0 / 360))
        #expect(close(w[1], 200.0 / 360))
    }

    @Test func launchEndsAStaleSession() {
        var p = SavedProgress.fresh(now: t0)
        p.recordAnswer(played: "red", chosen: "red", now: t0 + 1)
        p.launch(now: t0 + 3600)
        #expect(p.profile.stats.identifications == 0)
        #expect(p.levelHistory.first?.done == true)
    }

    @Test func launchFallsBackToTheGuestProfile() {
        var p = SavedProgress.fresh(now: t0)
        p.state.currentProfile = 555
        p.launch(now: t0)
        #expect(p.state.currentProfile == 100)
    }

    @Test func launchRecreatesAMissingGuest() {
        var p = SavedProgress.fresh(now: t0)
        p.state.profiles = [:]
        p.launch(now: t0)
        #expect(p.state.profiles["100"]?.name == "Elisa")
    }

    @Test func launchMovesAnUnknownLevelToYellow() {
        var p = SavedProgress.fresh(now: t0)
        p.profile.currentChord = "nope"
        p.state.currentChord = "nope"
        p.launch(now: t0)
        #expect(p.state.currentChord == "yellow")
        #expect(p.profile.currentChord == "yellow")
    }

    @Test func launchPutsTheProfilesLevelInPlay() {
        var p = SavedProgress.fresh(now: t0)
        p.profile.currentChord = "gray"
        p.launch(now: t0)
        #expect(p.state.currentChord == "gray")
    }
}
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `cd ~/c/bsharp/SwiftApp/ElisaKit && swift test --filter SessionsTests`
Expected: FAIL, `value of type 'SavedProgress' has no member 'recordAnswer'`.

- [ ] **Step 3: Write the session logic**

`SwiftApp/ElisaKit/Sources/ElisaKit/Sessions.swift`:

```swift
/// Session bookkeeping (src/ts/game.ts, state.ts, stats.ts, session_cleanup.ts). Times are
/// Unix seconds, passed in so tests can pin them.
extension SavedProgress {
    /// Most answers the adaptive weights look back over (RECENT_IDENTIFICATIONS_LIMIT).
    static let recentAnswerLimit = 140.0

    /// The profile playing now. Falls back to the guest profile, as getCurrentProfile() does.
    public var profile: Profile {
        get {
            state.profiles[String(state.currentProfile)]
                ?? state.profiles[String(Defaults.guestProfileID)]
                ?? Profile.guest(now: 0)
        }
        set { state.profiles[String(newValue.id)] = newValue }
    }

    public static func isRecent(_ timestamp: Double, now: Double) -> Bool {
        now - timestamp <= Defaults.sessionTimeout
    }

    /// The current profile's sessions at the level in play, oldest first.
    public var levelHistory: [SessionStats] {
        get { history[String(profile.id)]?[state.currentChord] ?? [] }
        set { history[String(profile.id), default: [:]][state.currentChord] = newValue }
    }

    /// Files the current session in the level's history, once (saveSessionHistory).
    public mutating func saveSession() {
        let stats = profile.stats
        if levelHistory.last?.startTime != stats.startTime {
            levelHistory.append(stats)
        }
    }

    /// Ends the current session and starts a new one (resetStats). `done` marks a session that
    /// is over; an unfinished one, left by a level change, can be resumed.
    public mutating func resetStats(done: Bool, now: Double) {
        profile.stats.done = done
        if !done || profile.stats.identifications > 0 {
            saveSession()
        }
        profile.stats = SessionStats(currentChord: state.currentChord, now: now)
    }

    /// Picks up the level's last unfinished session, and ends it at once if it is stale
    /// (retrieveSavedStats).
    public mutating func resumeSession(now: Double) {
        guard let last = levelHistory.last, !last.done else { return }
        profile.stats = levelHistory.removeLast()
        if !Self.isRecent(last.updatedTime, now: now) {
            resetStats(done: true, now: now)
        }
    }

    /// Puts `level` in play for the current profile (changeSelector). A new level starts a new
    /// streak; the session at the old level is parked, unfinished.
    public mutating func changeLevel(to level: String, now: Double) {
        if profile.currentChord != level {
            profile.streak = 0
        }
        guard state.currentChord != level else { return }
        resetStats(done: false, now: now)
        state.currentChord = level
        profile.currentChord = level
        profile.stats.currentChord = level
        resumeSession(now: now)
    }

    /// Counts an answer: the stats, the confusion matrix and the streak (updateStartTimeIfNeeded,
    /// updateStats, nextStreak). Returns whether it was right.
    @discardableResult
    public mutating func recordAnswer(played: String, chosen: String, now: Double) -> Bool {
        let correct = played == chosen
        var current = profile
        if current.stats.identifications == 0 {
            current.stats.startTime = now
        }
        current.stats.identifications += 1
        if correct {
            current.stats.correct += 1
        }
        current.stats.confusionMatrix[played, default: [:]][chosen, default: 0] += 1
        current.stats.updatedTime = now
        current.streak = Streak.next(current.streak ?? 0, correct: correct)
        profile = current
        return correct
    }

    /// Drops broken, empty and duplicate sessions from every profile's history
    /// (cleanSessionHistory).
    public mutating func cleanHistory(now: Double) {
        for (profileID, levels) in history {
            var cleaned: [String: [SessionStats]] = [:]
            for (level, sessions) in levels where !level.isEmpty {
                var kept: [SessionStats] = []
                for var session in sessions
                where session.identifications > 0 || (!session.done && Self.isRecent(session.updatedTime, now: now)) {
                    session.currentChord = level
                    if let last = kept.last, last.identifications == session.identifications,
                       last.startTime == session.startTime {
                        continue
                    }
                    kept.append(session)
                }
                cleaned[level] = kept
            }
            history[profileID] = cleaned
        }
    }

    /// The adaptive weight of each chord in play, from the level's most recent answers
    /// (getCurrentCoefficients).
    public func adaptiveWeights() -> [Double] {
        var matrices: [ConfusionMatrix] = []
        var remaining = Self.recentAnswerLimit
        for session in levelHistory.reversed() where remaining > 0 {
            let count = session.confusionMatrix.values.flatMap(\.values).reduce(0, +)
            if count == 0 { continue }
            if count <= remaining {
                matrices.append(session.confusionMatrix)
                remaining -= count
            } else {
                let scale = remaining / count
                matrices.append(session.confusionMatrix.mapValues { $0.mapValues { $0 * scale } })
                remaining = 0
            }
        }
        let chords = Chords.inPlay(upTo: state.currentChord).map(\.id)
        return AdaptiveWeights.coefficients(AdaptiveWeights.merge(matrices, chords: chords), chords: chords)
    }

    /// What the web app does when the page opens (main.ts): back on a known profile, a stale
    /// session ended, the profile's level in play, the history cleaned.
    public mutating func launch(now: Double) {
        if state.profiles[String(state.currentProfile)] == nil {
            state.currentProfile = Defaults.guestProfileID
            if state.profiles[String(Defaults.guestProfileID)] == nil {
                profile = Profile.guest(now: now)
            }
        }
        if !Self.isRecent(profile.stats.updatedTime, now: now) {
            resetStats(done: true, now: now)
        }
        // A level this app doesn't know (a newer web version, a hand-edited file) falls back to
        // the default before it is put in play. Fixing the profile first keeps its streak.
        if !Chords.ids.contains(profile.currentChord) {
            profile.currentChord = Defaults.level
        }
        changeLevel(to: profile.currentChord, now: now)
        cleanHistory(now: now)
    }
}
```

Note on `launchMovesAnUnknownLevelToYellow`: the level in play is still `"nope"`, so `changeLevel(to: "yellow")` parks the `"nope"` session (under a `"nope"` history key, harmless) and moves.

- [ ] **Step 4: Run the tests and make sure they pass**

Run: `cd ~/c/bsharp/SwiftApp/ElisaKit && swift test`
Expected: PASS. If a session test fails, compare the method line by line with its TypeScript function named in the doc comment; the TypeScript is the reference.

- [ ] **Step 5: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/ElisaKit/Sources/ElisaKit/Sessions.swift SwiftApp/ElisaKit/Tests/ElisaKitTests/SessionsTests.swift
git commit -m "Port session bookkeeping and adaptive weights from history"
```

---

### Task 4: Display rules: note shapes, grid columns, the hidden gesture

Three small pure pieces the screen needs, tested together.

**Files:**
- Create: `SwiftApp/ElisaKit/Sources/ElisaKit/NoteDisplay.swift`, `SwiftApp/ElisaKit/Sources/ElisaKit/FlagLayout.swift`, `SwiftApp/ElisaKit/Sources/ElisaKit/TapUnlock.swift`
- Test: `SwiftApp/ElisaKit/Tests/ElisaKitTests/NoteDisplayTests.swift`, `SwiftApp/ElisaKit/Tests/ElisaKitTests/FlagLayoutTests.swift`, `SwiftApp/ElisaKit/Tests/ElisaKitTests/TapUnlockTests.swift`

- [ ] **Step 1: Write the failing tests**

`SwiftApp/ElisaKit/Tests/ElisaKitTests/NoteDisplayTests.swift`:

```swift
import Testing
@testable import ElisaKit

@Suite struct NoteDisplayTests {
    private func chord(_ id: String) -> Chord { Chords.all.first { $0.id == id }! }

    @Test func lettersUseRealSharpAndFlatSigns() {
        #expect(NoteDisplay.letter(for: "C#4") == "C♯")
        #expect(NoteDisplay.letter(for: "Bb3") == "B♭")
        #expect(NoteDisplay.letter(for: "E4") == "E")
    }

    @Test func grayIsAnUpsideDownTriangleAPentagonAndAHeart() {
        let marks = NoteDisplay.marks(for: chord("gray"), shapes: true)
        #expect(marks.map(\.shape) == [.triangleDown, .pentagon, .heart])
        #expect(marks.map(\.letter) == ["A", "C♯", "E"])
        #expect(marks[0].letterDY == -0.10)
    }

    @Test func everyNoteHasItsOwnShape() {
        let marks = Chords.all.flatMap { NoteDisplay.marks(for: $0, shapes: true) }
        var shapeOfNote: [String: NoteShape] = [:]
        for mark in marks { shapeOfNote[mark.note] = mark.shape }
        #expect(shapeOfNote.count == 18)
        #expect(Set(shapeOfNote.values) == Set(NoteShape.allCases))
    }

    @Test func gSharpIsABiggerStar() {
        let gSharp = NoteDisplay.marks(for: chord("lightgreen"), shapes: true)[1]
        #expect(gSharp.shape == .star)
        #expect(gSharp.scale == 1.25)
    }

    @Test func withoutShapesEveryNoteIsAPlainCircle() {
        let marks = NoteDisplay.marks(for: chord("gray"), shapes: false)
        #expect(marks.allSatisfy { $0.shape == .circle && $0.letterDX == 0 && $0.letterDY == 0 && $0.scale == 1 })
    }

    @Test func displayModesPickShapesAndLetters() {
        #expect(NoteDisplay.style(for: "shapes_and_letters") == .init(shapes: true, letters: true))
        #expect(NoteDisplay.style(for: "shapes_only") == .init(shapes: true, letters: false))
        #expect(NoteDisplay.style(for: "letters_only") == .init(shapes: false, letters: true))
    }

    @Test func blackOnlyMeansFromGrayOn() {
        #expect(!NoteDisplay.chordsOn(showChordMode: "black_only", level: "brown"))
        #expect(NoteDisplay.chordsOn(showChordMode: "black_only", level: "gray"))
        #expect(NoteDisplay.chordsOn(showChordMode: "always", level: "yellow"))
        #expect(!NoteDisplay.chordsOn(showChordMode: "never", level: "skyblue"))
    }

    @Test func afterGuessShowsNotesOnlyWithTheAnswerOnScreen() {
        var profile = Profile.guest(now: 0)
        profile.revealChordMode = "after_guess"
        #expect(!NoteDisplay.notesVisible(profile: profile, level: "gray", answerShown: false))
        #expect(NoteDisplay.notesVisible(profile: profile, level: "gray", answerShown: true))
        profile.revealChordMode = "always"
        #expect(NoteDisplay.notesVisible(profile: profile, level: "gray", answerShown: false))
        #expect(!NoteDisplay.notesVisible(profile: profile, level: "yellow", answerShown: true))
    }
}
```

`SwiftApp/ElisaKit/Tests/ElisaKitTests/FlagLayoutTests.swift`:

```swift
import Testing
@testable import ElisaKit

@Suite struct FlagLayoutTests {
    @Test func portraitWidensAsFlagsAreAdded() {
        #expect(FlagLayout.columns(count: 2, landscape: false) == 1)
        #expect(FlagLayout.columns(count: 3, landscape: false) == 1)
        #expect(FlagLayout.columns(count: 4, landscape: false) == 2)
        #expect(FlagLayout.columns(count: 9, landscape: false) == 2)
        #expect(FlagLayout.columns(count: 10, landscape: false) == 3)
        #expect(FlagLayout.columns(count: 14, landscape: false) == 3)
    }

    @Test func landscapeHasMoreColumns() {
        #expect(FlagLayout.columns(count: 2, landscape: true) == 3)
        #expect(FlagLayout.columns(count: 9, landscape: true) == 3)
        #expect(FlagLayout.columns(count: 10, landscape: true) == 5)
    }
}
```

`SwiftApp/ElisaKit/Tests/ElisaKitTests/TapUnlockTests.swift`:

```swift
import Testing
@testable import ElisaKit

@Suite struct TapUnlockTests {
    @Test func theSixthQuickTapUnlocks() {
        var unlock = TapUnlock()
        let results = (0..<6).map { unlock.tap(at: Double($0)) }
        #expect(results == [false, false, false, false, false, true])
    }

    @Test func aPauseStartsTheCountOver() {
        var unlock = TapUnlock()
        for i in 0..<5 { _ = unlock.tap(at: Double(i)) }
        #expect(!unlock.tap(at: 6.6))
        #expect((0..<4).map { unlock.tap(at: 7 + Double($0)) } == [false, false, false, false])
        #expect(unlock.tap(at: 11))
    }

    @Test func afterUnlockingItNeedsSixMore() {
        var unlock = TapUnlock()
        for i in 0..<6 { _ = unlock.tap(at: Double(i)) }
        #expect(!unlock.tap(at: 6))
    }
}
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `cd ~/c/bsharp/SwiftApp/ElisaKit && swift test --filter "NoteDisplay|FlagLayout|TapUnlock"`
Expected: FAIL, `cannot find 'NoteDisplay' in scope`.

- [ ] **Step 3: Write the three files**

`SwiftApp/ElisaKit/Sources/ElisaKit/NoteDisplay.swift`:

```swift
import Foundation

/// The shape a note is drawn with (src/scss/_note-shapes.scss). Raw values are the asset names
/// after "note-".
public enum NoteShape: String, CaseIterable, Sendable {
    case circle, triangle, triangleDown = "triangle-down", moon, moonFlipped = "moon-flipped"
    case heart, heartDown = "heart-down", pentagon, hexagon, octagon
    case roundedSquare = "rounded-square", roundedDiamond = "rounded-diamond", teardrop
    case trapezoid, trapezoidDown = "trapezoid-down", star, clover, cloverRotated = "clover-rotated"
}

/// One note drawn on a flag.
public struct NoteMark: Equatable, Sendable {
    /// With its octave, e.g. "C#4".
    public let note: String
    /// What is printed, e.g. "C♯".
    public let letter: String
    public let shape: NoteShape
    /// Moves the letter onto the shape's visual centre, as a share of the letter's size
    /// (the CSS translate on .note-text-span).
    public let letterDX: Double
    public let letterDY: Double
    /// The star is drawn bigger than the rest (2.5em instead of 2em).
    public let scale: Double
}

/// Which notes a flag shows and how (ui.ts setChordDisplayMode/populateFlags, game.ts
/// changeSelector).
public enum NoteDisplay {
    public struct Style: Equatable, Sendable {
        public let shapes: Bool
        public let letters: Bool

        public init(shapes: Bool, letters: Bool) {
            self.shapes = shapes
            self.letters = letters
        }
    }

    /// chord_display_mode: shapes_and_letters (the default), shapes_only or letters_only.
    public static func style(for mode: String) -> Style {
        Style(shapes: mode != "letters_only", letters: mode != "shapes_only")
    }

    /// A level with black-key chords: gray onwards.
    public static func isBlackLevel(_ level: String) -> Bool {
        (Chords.ids.firstIndex(of: level) ?? 0) >= Chords.firstBlackIndex
    }

    /// Whether the level's flags carry notes at all (show_chord_mode: always, black_only, never).
    public static func chordsOn(showChordMode: String, level: String) -> Bool {
        showChordMode == "always" || (showChordMode == "black_only" && isBlackLevel(level))
    }

    /// Whether the notes are drawn right now. With reveal_chord_mode after_guess they show only
    /// while a right answer is on screen.
    public static func notesVisible(profile: Profile, level: String, answerShown: Bool) -> Bool {
        guard chordsOn(showChordMode: profile.showChordMode, level: level) else { return false }
        return profile.revealChordMode != "after_guess" || answerShown
    }

    /// The chord's notes, low to high. Without shapes every note is a plain circle.
    public static func marks(for chord: Chord, shapes: Bool) -> [NoteMark] {
        chord.notes.map { note in
            let look = shapes ? (looks[note] ?? Look(shape: .circle)) : Look(shape: .circle)
            return NoteMark(note: note, letter: letter(for: note), shape: look.shape,
                            letterDX: look.dx, letterDY: look.dy, scale: look.scale)
        }
    }

    /// "C#4" → "C♯", "Bb3" → "B♭".
    public static func letter(for note: String) -> String {
        String(note.filter { !$0.isNumber })
            .replacingOccurrences(of: "#", with: "♯")
            .replacingOccurrences(of: "b", with: "♭")
    }

    private struct Look {
        let shape: NoteShape
        var dx = 0.0
        var dy = 0.0
        var scale = 1.0
    }

    /// div.use-shapes in _note-shapes.scss: the clip path and letter nudge of each note.
    private static let looks: [String: Look] = [
        "A3": Look(shape: .triangleDown, dy: -0.10),
        "A4": Look(shape: .triangle, dy: 0.10),
        "B3": Look(shape: .roundedDiamond, dx: 0.07, dy: 0.02),
        "B4": Look(shape: .roundedSquare),
        "Bb3": Look(shape: .trapezoid, dy: 0.05),
        "Bb4": Look(shape: .trapezoidDown, dy: -0.07),
        "C4": Look(shape: .moon, dx: -0.20, dy: 0.12),
        "C5": Look(shape: .moonFlipped, dx: 0.20, dy: 0.12),
        "C#4": Look(shape: .pentagon, dy: 0.10),
        "D4": Look(shape: .clover),
        "D5": Look(shape: .cloverRotated, dx: 0.05),
        "E4": Look(shape: .heart, dx: -0.05),
        "E5": Look(shape: .heartDown, dx: -0.05, dy: 0.05),
        "Eb4": Look(shape: .teardrop, dx: 0.09, dy: 0.10),
        "F4": Look(shape: .circle),
        "F#4": Look(shape: .hexagon),
        "G4": Look(shape: .octagon),
        "G#4": Look(shape: .star, scale: 1.25),
    ]
}
```

`SwiftApp/ElisaKit/Sources/ElisaKit/FlagLayout.swift`:

```swift
/// Columns of the flag grid (#flag-holder in _bluey.scss): one wide flag per row while there
/// are few, more columns as flags are added, and more again when the screen is wider than tall.
public enum FlagLayout {
    public static func columns(count: Int, landscape: Bool) -> Int {
        if landscape { return count > 9 ? 5 : 3 }
        if count < 4 { return 1 }
        return count > 9 ? 3 : 2
    }
}
```

`SwiftApp/ElisaKit/Sources/ElisaKit/TapUnlock.swift`:

```swift
/// The hidden gesture in front of parent-only actions (ui.ts enableDownload): six taps, each
/// within 1.5 s of the one before.
public struct TapUnlock: Sendable {
    private var count = 0
    private var last: Double?

    public init() {}

    /// Counts a tap at `time` (seconds). True on the tap that unlocks; the count then starts over.
    public mutating func tap(at time: Double) -> Bool {
        if let last, time - last > 1.5 {
            count = 0
        }
        last = time
        count += 1
        guard count >= 6 else { return false }
        count = 0
        return true
    }
}
```

- [ ] **Step 4: Run the tests and make sure they pass**

Run: `cd ~/c/bsharp/SwiftApp/ElisaKit && swift test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/ElisaKit/Sources/ElisaKit/NoteDisplay.swift SwiftApp/ElisaKit/Sources/ElisaKit/FlagLayout.swift SwiftApp/ElisaKit/Sources/ElisaKit/TapUnlock.swift SwiftApp/ElisaKit/Tests/ElisaKitTests/NoteDisplayTests.swift SwiftApp/ElisaKit/Tests/ElisaKitTests/FlagLayoutTests.swift SwiftApp/ElisaKit/Tests/ElisaKitTests/TapUnlockTests.swift
git commit -m "Add note shapes, grid columns and the hidden tap gesture to ElisaKit"
```

---

### Task 5: The game

`Game` is the main screen's rules as a value type: it never plays a sound or starts a timer, it says what should happen. The app's `GameModel` (Task 8) does the playing and the waiting.

**Files:**
- Create: `SwiftApp/ElisaKit/Sources/ElisaKit/Game.swift`
- Test: `SwiftApp/ElisaKit/Tests/ElisaKitTests/GameTests.swift`

- [ ] **Step 1: Write the failing tests**

`SwiftApp/ElisaKit/Tests/ElisaKitTests/GameTests.swift`:

```swift
import Testing
@testable import ElisaKit

private final class Clock {
    var now = 1_793_400_000.0
}

@Suite struct GameTests {
    let clock = Clock()

    private func game(_ progress: SavedProgress? = nil, answer: String? = "red",
                      random: Double = 0.0) -> Game {
        var game = Game(progress: progress ?? .fresh(now: clock.now), forcedAnswer: answer,
                        random: { random }, now: { [clock] in clock.now })
        game.start()
        return game
    }

    @Test func itStartsWithAnUnplayedQuestionAndTheHint() {
        let g = game()
        #expect(g.answer == "red")
        #expect(!g.asked)
        #expect(g.showsPlayHint)
        #expect(!g.awaitingPlay)
        #expect(g.chords.map(\.id) == ["red", "yellow"])
    }

    @Test func noHintWhenTheProfileTurnedHintsOff() {
        var progress = SavedProgress.fresh(now: clock.now)
        progress.profile.enableOnboardingHints = false
        #expect(!game(progress).showsPlayHint)
    }

    @Test func aTapBeforePlayOnlySounds() {
        var g = game()
        #expect(g.tap("red") == .sound)
        #expect(g.profile.stats.identifications == 0)
    }

    @Test func playAsksTheQuestionAndHidesTheHint() {
        var g = game()
        #expect(g.play() == "red")
        #expect(g.asked)
        #expect(!g.showsPlayHint)
    }

    @Test func aWrongAnswerCountsAndSheKeepsGuessing() {
        var g = game()
        _ = g.play()
        #expect(g.tap("yellow") == .wrong)
        #expect(g.marked == nil)
        #expect(g.profile.stats.identifications == 1)
        #expect(g.profile.stats.correct == 0)
        #expect(g.profile.streak == 0)
        #expect(g.tap("red") == .correct)
    }

    @Test func theRightAnswerIsMarkedAndFurtherTapsOnlySound() {
        var g = game()
        _ = g.play()
        #expect(g.tap("red") == .correct)
        #expect(g.marked == "red")
        #expect(g.profile.streak == 1)
        #expect(g.tap("yellow") == .sound)
        #expect(g.profile.stats.identifications == 1)
    }

    @Test func afterTheRevealTheFlagsWaitForPlay() {
        var g = game()
        _ = g.play()
        _ = g.tap("red")
        g.revealFinished()
        #expect(g.marked == nil)
        #expect(g.awaitingPlay)
        #expect(!g.asked)
        #expect(!g.showsPlayHint)
        #expect(g.tap("red") == .ignored)
        _ = g.play()
        #expect(!g.awaitingPlay)
        #expect(g.tap("red") == .correct)
        #expect(g.profile.streak == 2)
    }

    @Test func revealFinishedWithoutAnAnswerDoesNothing() {
        var g = game()
        g.revealFinished()
        #expect(!g.awaitingPlay)
    }

    @Test func randomModePicksUniformly() {
        #expect(game(answer: nil, random: 0.0).answer == "red")
        #expect(game(answer: nil, random: 0.99).answer == "yellow")
    }

    @Test func adaptiveModeWeighsByTheHistory() {
        var progress = SavedProgress.fresh(now: clock.now)
        progress.profile.chordSelectionMode = "adaptive"
        var past = SessionStats(currentChord: "yellow", now: clock.now - 9000)
        past.identifications = 40
        past.done = true
        past.confusionMatrix = ["red": ["red": 12, "yellow": 8], "yellow": ["yellow": 20]]
        progress.history["100"] = ["yellow": [past]]
        // Weights are 0.583 red, 0.417 yellow; uniform would give yellow for 0.5.
        #expect(game(progress, answer: nil, random: 0.5).answer == "red")
        progress.profile.chordSelectionMode = "random"
        #expect(game(progress, answer: nil, random: 0.5).answer == "yellow")
    }

    @Test func changingLevelShowsItsFlagsAndTheHintAgain() {
        var g = game()
        _ = g.play()
        _ = g.tap("red")
        g.changeLevel(to: "gray")
        #expect(g.level == "gray")
        #expect(g.chords.count == 10)
        #expect(g.marked == nil)
        #expect(g.showsPlayHint)
        #expect(g.profile.streak == 0)
    }

    @Test func anUnknownLevelIsIgnored() {
        var g = game()
        g.changeLevel(to: "nope")
        #expect(g.level == "yellow")
    }

    @Test func comingBackAfterHalfAnHourStartsANewSession() {
        var g = game()
        _ = g.play()
        _ = g.tap("red")
        clock.now += 31 * 60
        g.becameActive()
        #expect(g.profile.stats.identifications == 0)
        #expect(g.progress.levelHistory.last?.done == true)
        #expect(g.marked == nil)
        #expect(g.showsPlayHint)
    }

    @Test func comingBackSoonChangesNothing() {
        var g = game()
        _ = g.play()
        clock.now += 60
        g.becameActive()
        #expect(g.asked)
    }

    @Test func notesShowFromGrayOnByDefault() {
        var g = game()
        #expect(g.noteStyle == nil)
        g.changeLevel(to: "gray")
        #expect(g.noteStyle == .init(shapes: true, letters: true))
    }

    @Test func afterGuessNotesShowWithTheAnswer() {
        var progress = SavedProgress.fresh(now: clock.now)
        progress.profile.revealChordMode = "after_guess"
        progress.profile.currentChord = "gray"
        var g = game(progress, answer: "gray")
        #expect(g.noteStyle == nil)
        _ = g.play()
        _ = g.tap("gray")
        #expect(g.noteStyle != nil)
    }

    @Test func theInstrumentIsTheProfiles() {
        var progress = SavedProgress.fresh(now: clock.now)
        progress.profile.currentInstrument = "guitar-strummed"
        #expect(game(progress).instrument == .guitarStrummed)
    }
}
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `cd ~/c/bsharp/SwiftApp/ElisaKit && swift test --filter GameTests`
Expected: FAIL, `cannot find 'Game' in scope`.

- [ ] **Step 3: Write the game**

`SwiftApp/ElisaKit/Sources/ElisaKit/Game.swift`:

```swift
import Foundation

/// What a flag tap did.
public enum TapOutcome: Equatable, Sendable {
    /// The flags are dimmed until play is pressed: nothing happens, not even a sound.
    case ignored
    /// The chord sounds but isn't an answer: nothing has been asked yet, or the right answer
    /// is already in.
    case sound
    /// A wrong answer: the chord sounds, the miss counts, and she keeps guessing.
    case wrong
    /// The right answer: the flag shows the green check until `revealFinished()`.
    case correct
}

/// The main screen's rules (src/ts/game.ts): which chord is asked, whether it has been played,
/// what a tap means. Sounds and timers belong to the caller; the progress it changes is in
/// `progress`, ready to save.
public struct Game {
    public private(set) var progress: SavedProgress
    /// The chord being asked.
    public private(set) var answer = ""
    /// Whether the question has been played, so a tap counts as an answer. As in the web app
    /// (whose 0.8 × duration timer is in milliseconds by mistake), that is as soon as play is
    /// pressed.
    public private(set) var asked = false
    /// The flag showing the green check, from a right answer until `revealFinished()`.
    public private(set) var marked: String?
    /// After the reveal the next chord waits for play, and the flags are dimmed meanwhile.
    public private(set) var awaitingPlay = false
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
    public var level: String { progress.state.currentChord }
    public var chords: [Chord] { Chords.inPlay(upTo: level) }
    public var instrument: Instrument { profile.instrument }

    /// How the flags show their notes now, or nil when they show none.
    public var noteStyle: NoteDisplay.Style? {
        guard NoteDisplay.notesVisible(profile: profile, level: level, answerShown: marked != nil) else {
            return nil
        }
        return NoteDisplay.style(for: profile.chordDisplayMode)
    }

    /// Opens the app: the web app's page-load housekeeping, then a first question, not played.
    public mutating func start() {
        progress.launch(now: now())
        newSession()
    }

    /// Back from the background. A session idle for 30 minutes is over, as reopening the web
    /// app would end it.
    public mutating func becameActive() {
        guard !SavedProgress.isRecent(profile.stats.updatedTime, now: now()) else { return }
        progress.resetStats(done: true, now: now())
        newSession()
    }

    public mutating func changeLevel(to level: String) {
        guard Chords.ids.contains(level) else { return }
        progress.changeLevel(to: level, now: now())
        newSession()
    }

    /// Play pressed: returns the chord to sound.
    public mutating func play() -> String {
        showsPlayHint = false
        awaitingPlay = false
        asked = true
        return answer
    }

    public mutating func tap(_ color: String) -> TapOutcome {
        if awaitingPlay { return .ignored }
        guard marked == nil, asked else { return .sound }
        guard progress.recordAnswer(played: answer, chosen: color, now: now()) else { return .wrong }
        marked = color
        return .correct
    }

    /// The reveal is over: the next question is loaded, not played, and the flags dim until
    /// play is pressed.
    public mutating func revealFinished() {
        guard marked != nil else { return }
        marked = nil
        newQuestion()
        awaitingPlay = true
    }

    private mutating func newSession() {
        weights = nil
        marked = nil
        awaitingPlay = false
        newQuestion()
        showsPlayHint = profile.enableOnboardingHints
    }

    private mutating func newQuestion() {
        let adaptive = profile.chordSelectionMode == "adaptive"
        if adaptive, weights == nil {
            weights = progress.adaptiveWeights()
        }
        answer = forcedAnswer ?? AdaptiveWeights.pick(chords.map(\.id), weights: adaptive ? weights : nil,
                                                      random: random)
        asked = false
    }
}
```

- [ ] **Step 4: Run the tests and make sure they pass**

Run: `cd ~/c/bsharp/SwiftApp/ElisaKit && swift test`
Expected: PASS, every suite.

- [ ] **Step 5: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/ElisaKit/Sources/ElisaKit/Game.swift SwiftApp/ElisaKit/Tests/ElisaKitTests/GameTests.swift
git commit -m "Add the game rules: question, play, answers and the reveal"
```

---

### Task 6: Chord audio

The recordings stay where the web app has them (`static/chords/`); `project.yml` adds that folder to the app bundle as `chords/`, so there is one copy in git. `ChordFiles` (tested) knows the file names; `ChordPlayer` (app) decodes the current instrument's recordings into memory and plays them through one `AVAudioPlayerNode`. One node is enough because a new chord always cuts off the one sounding (`stopCurrentAudio` in `game.ts`). Piano files are 48 kHz stereo and both guitars 44.1 kHz mono, so the node is reconnected with the right format whenever the instrument changes.

**Files:**
- Create: `SwiftApp/ElisaKit/Sources/ElisaKit/ChordFiles.swift`
- Test: `SwiftApp/ElisaKit/Tests/ElisaKitTests/ChordFilesTests.swift`
- Modify: `SwiftApp/project.yml` (target `ElisaMusica`, `sources`)
- Create: `SwiftApp/App/ChordPlayer.swift`

- [ ] **Step 1: Write the failing test**

`SwiftApp/ElisaKit/Tests/ElisaKitTests/ChordFilesTests.swift`:

```swift
import Foundation
import Testing
@testable import ElisaKit

@Suite struct ChordFilesTests {
    /// bsharp/static/chords, found from this file's path.
    let chordsFolder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "static/chords")

    @Test func pianoHasThreeTakesAndEachGuitarOne() {
        #expect(ChordFiles.paths(for: .piano, color: "red") == [
            "piano/ceg_red_short.mp3", "piano/ceg_red_medium.mp3", "piano/ceg_red_long.mp3",
        ])
        #expect(ChordFiles.paths(for: .guitar, color: "gray") == ["guitar/a3cs4e4_gray.mp3"])
        #expect(ChordFiles.paths(for: .guitarStrummed, color: "skyblue") == ["guitar-strummed/ds4g4as4_skyblue.mp3"])
        #expect(ChordFiles.paths(for: .piano, color: "nope").isEmpty)
    }

    @Test func everyRecordingExistsAndNoneIsLeftOut() throws {
        let paths = Instrument.allCases.flatMap { instrument in
            Chords.ids.flatMap { ChordFiles.paths(for: instrument, color: $0) }
        }
        #expect(paths.count == 70)
        for path in paths {
            #expect(FileManager.default.fileExists(atPath: chordsFolder.appending(path: path).path(percentEncoded: false)), "\(path)")
        }
        var onDisk = 0
        for folder in ["piano", "guitar", "guitar-strummed"] {
            onDisk += try FileManager.default
                .contentsOfDirectory(atPath: chordsFolder.appending(path: folder).path(percentEncoded: false))
                .filter { $0.hasSuffix(".mp3") }.count
        }
        #expect(onDisk == 70)
    }
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `cd ~/c/bsharp/SwiftApp/ElisaKit && swift test --filter ChordFilesTests`
Expected: FAIL, `cannot find 'ChordFiles' in scope`.

- [ ] **Step 3: Write the catalog**

`SwiftApp/ElisaKit/Sources/ElisaKit/ChordFiles.swift`:

```swift
/// The chord recordings in static/chords/ (src/ts/data.ts AUDIO_FILE_LIST), as paths under the
/// bundle's `chords/` folder. Piano has three takes per chord; each guitar has one.
public enum ChordFiles {
    /// File names spell the notes German style: h is B, s is sharp ("acse" is A C♯ E).
    static let pianoNotes = [
        "red": "ceg", "yellow": "cfa", "blue": "hdg", "black": "acf", "green": "dgh",
        "orange": "egc", "purple": "fac", "pink": "ghd", "brown": "gce", "gray": "acse",
        "tan": "dfsa", "lightgreen": "egsh", "lightpurple": "asdf", "skyblue": "dsgas",
    ]
    static let guitarNotes = [
        "red": "c4e4g4", "yellow": "c4f4a4", "blue": "h3d4g4", "black": "a3c4f4", "green": "d4g4h4",
        "orange": "e4g4c5", "purple": "f4a4c5", "pink": "g4h4d5", "brown": "g4c5e5", "gray": "a3cs4e4",
        "tan": "d4fs4a4", "lightgreen": "e4gs4h4", "lightpurple": "as3d4f4", "skyblue": "ds4g4as4",
    ]

    public static func paths(for instrument: Instrument, color: String) -> [String] {
        switch instrument {
        case .piano:
            guard let notes = pianoNotes[color] else { return [] }
            return ["short", "medium", "long"].map { "piano/\(notes)_\(color)_\($0).mp3" }
        case .guitar, .guitarStrummed:
            guard let notes = guitarNotes[color] else { return [] }
            return ["\(instrument.chordFolder)/\(notes)_\(color).mp3"]
        }
    }
}
```

- [ ] **Step 4: Run the tests and make sure they pass**

Run: `cd ~/c/bsharp/SwiftApp/ElisaKit && swift test`
Expected: PASS.

- [ ] **Step 5: Bundle the recordings**

In `SwiftApp/project.yml`, under `targets: ElisaMusica:`, replace

```yaml
    sources:
      - App
```

with

```yaml
    sources:
      - App
      # The web app's recordings, as a folder reference: in the bundle at chords/<instrument>/.
      # A folder (not a group) keeps guitar/ and guitar-strummed/, whose file names are the same.
      - path: ../static/chords
        type: folder
        buildPhase: resources
```

- [ ] **Step 6: Write the player**

`SwiftApp/App/ChordPlayer.swift`:

```swift
import AVFAudio
import ElisaKit
import QuartzCore

/// Plays the chord recordings with no audible delay: every take of the current instrument is
/// decoded into memory when the instrument is loaded, so a tap only schedules a buffer. One
/// player node is enough because a new chord always cuts off the one sounding (game.ts
/// stopCurrentAudio).
@MainActor
final class ChordPlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    /// Chord id → its takes: three for piano, one for each guitar.
    private var takes: [String: [AVAudioPCMBuffer]] = [:]
    private var instrument: Instrument?

    init() {
        let session = AVAudioSession.sharedInstance()
        // .playback, so the silent switch doesn't mute the game.
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
        engine.attach(player)
    }

    /// Decodes the instrument's recordings and wires the player for their format (piano is
    /// 48 kHz stereo, both guitars 44.1 kHz mono).
    func load(_ instrument: Instrument) {
        guard instrument != self.instrument else { return }
        let started = CACurrentMediaTime()
        var loaded: [String: [AVAudioPCMBuffer]] = [:]
        for chord in Chords.all {
            loaded[chord.id] = ChordFiles.paths(for: instrument, color: chord.id).compactMap(Self.decode)
        }
        guard let format = loaded.values.lazy.compactMap(\.first).first?.format else {
            DevLog.event("audio.load-failed", ["instrument": instrument.rawValue])
            return
        }
        player.stop()
        engine.stop()
        engine.disconnectNodeOutput(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        takes = loaded
        self.instrument = instrument
        startEngine()
        let session = AVAudioSession.sharedInstance()
        DevLog.event("audio.loaded", [
            "instrument": instrument.rawValue,
            "decodeMs": Self.ms(CACurrentMediaTime() - started),
            "outputLatencyMs": Self.ms(session.outputLatency),
            "ioBufferMs": Self.ms(session.ioBufferDuration),
        ])
    }

    /// Cuts off whatever is sounding and plays one take of `color`, picked at random.
    func play(_ color: String) {
        guard let take = takes[color]?.randomElement() else { return }
        let started = CACurrentMediaTime()
        // An interruption (a call, Siri) or a route change stops the engine.
        if !engine.isRunning { startEngine() }
        player.stop()
        player.scheduleBuffer(take, completionHandler: nil)
        player.play()
        DevLog.event("audio.play", ["color": color, "scheduleMs": Self.ms(CACurrentMediaTime() - started)])
    }

    private func startEngine() {
        do {
            try engine.start()
        } catch {
            DevLog.event("audio.engine-error", ["error": "\(error)"])
        }
    }

    private static func decode(_ path: String) -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.resourceURL?.appending(path: "chords/\(path)"),
              let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil
        else {
            DevLog.event("audio.missing", ["path": path])
            return nil
        }
        return buffer
    }

    private static func ms(_ seconds: Double) -> String {
        String(format: "%.1f", seconds * 1000)
    }
}
```

- [ ] **Step 7: Build and check the bundle**

```bash
cd ~/c/bsharp/SwiftApp
xcodegen generate
xcodebuild -project ElisaMusica.xcodeproj -scheme ElisaMusica -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd build 2>&1 | tail -3
APP=build/dd/Build/Products/Debug-iphonesimulator/ElisaMusica.app
command ls "$APP/chords"; for d in piano guitar guitar-strummed; do command ls "$APP/chords/$d" | wc -l; done
```

Expected: `** BUILD SUCCEEDED **`; `guitar  guitar-strummed  piano`; then `42`, `14`, `14`.

If the folder is missing or flattened (mp3s at the bundle root), the folder reference didn't take: open `ElisaMusica.xcodeproj/project.pbxproj` and check that `chords` is a `lastKnownFileType = folder` reference in the Resources build phase, then fix `project.yml` (not the generated project).

- [ ] **Step 8: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/ElisaKit/Sources/ElisaKit/ChordFiles.swift SwiftApp/ElisaKit/Tests/ElisaKitTests/ChordFilesTests.swift SwiftApp/project.yml SwiftApp/App/ChordPlayer.swift
git commit -m "Bundle the web app's chord recordings and add the chord player"
```

---

### Task 7: Note shape images

The web app draws note shapes as CSS clip paths: SVG paths in a 0–1 box (`<clipPath>`s near the end of `src/index.html`) plus five `polygon()`s and a `circle()` in `src/scss/_note-shapes.scss`. Rather than port SVG arcs to SwiftUI paths, a script writes each one as an SVG template image in the asset catalog, kept as vectors, so SwiftUI can tint and scale it.

**Files:**
- Create: `SwiftApp/scripts/note-shapes.py`
- Create (generated, committed): `SwiftApp/App/Assets.xcassets/note-*.imageset/` (18)

- [ ] **Step 1: Write the generator**

`SwiftApp/scripts/note-shapes.py`:

```python
#!/usr/bin/env python3
"""Writes App/Assets.xcassets/note-<shape>.imageset for every note shape: an SVG template image,
kept as vectors, so SwiftUI can tint and scale it.

The paths are the web app's clip paths, in a 0-1 box: the <clipPath>s near the end of
src/index.html, and the polygon() / circle() values in src/scss/_note-shapes.scss. The names
match NoteShape's raw values in ElisaKit/Sources/ElisaKit/NoteDisplay.swift. Run it again only
if a shape changes; the imagesets are committed.
"""
import json
from pathlib import Path

ASSETS = Path(__file__).resolve().parents[1] / "App" / "Assets.xcassets"


def path(d):
    return f'<path d="{d}"/>'


def polygon(points):
    """CSS polygon() percentages, e.g. "50% 0%, 100% 38%" → an SVG path in the 0-1 box."""
    pairs = [p.split() for p in points.split(",")]
    coords = [f"{float(x.rstrip('%')) / 100:g} {float(y.rstrip('%')) / 100:g}" for x, y in pairs]
    return path("M" + " L".join(coords) + " Z")


SHAPES = {
    "circle": '<circle cx=".5" cy=".5" r=".5"/>',
    "triangle": path("m.8192 1q.2338-0 .1293-.2028l-.3476-.6741q-.1046-.2028-.2091 0l-.3476.6741q-.1046.2028.1293.2028z"),
    "triangle-down": path("m.1808 0q-.2338 0-.1293.2028l.3476.6741q.1046.2028.2091 0l.3476-.6741q.1046-.2028-.1293-.2028z"),
    "moon": path("m.5011.025a.4761.475 0 00-.4761.475.4761.475 0 00.4761.475.4761.475 0 00.4739-.4449.3187.318 0 01-.1276.027.3187.318 0 01-.3187-.318.3187.318 0 01.074-.2031.4761.475 0 00-.1016-.0111z"),
    "moon-flipped": path("m.025.4989a.4761.475 270 00.475.4761.4761.475 270 00.475-.4761.4761.475 270 00-.4449-.4739.3187.318 270 01.027.1276.3187.318 270 01-.318.3187.3187.318 270 01-.2031-.074.4761.475 270 00-.0111.1016z"),
    "heart": path("m 0.27446288,0.02497801 c -0.13778724,0 -0.24945956,0.12061671 -0.24945956,0.26932511 0,0.30247927 0.28243446,0.38179115 0.47499467,0.68067485 0.18220613,-0.2969646 0.47500535,-0.38796757 0.47500535,-0.68067485 0,-0.1487084 -0.1117578,-0.26932511 -0.24945955,-0.26932511 -0.0998009,0 -0.18570023,0.06363921 -0.2255458,0.15530394 -0.0395357,-0.09143312 -0.12536021,-0.15530394 -0.22527867,-0.15530394 z"),
    "heart-down": path("m0.27446 0.97542c-0.13779 0-0.24946-0.12062-0.24946-0.26933 0-0.30248 0.28243-0.38179 0.47499-0.68067 0.18221 0.29696 0.47501 0.38797 0.47501 0.68067 0 0.14871-0.11176 0.26933-0.24946 0.26933-0.099801 0-0.1857-0.063639-0.22555-0.1553-0.039536 0.091433-0.12536 0.1553-0.22528 0.1553z"),
    "pentagon": polygon("50% 0%, 100% 38%, 82% 100%, 18% 100%, 0% 38%"),
    "hexagon": polygon("50% 0%, 100% 25%, 100% 75%, 50% 100%, 0% 75%, 0% 25%"),
    "octagon": polygon("30% 0%, 70% 0%, 100% 30%, 100% 70%, 70% 100%, 30% 100%, 0% 70%, 0% 30%"),
    "rounded-square": path("m0.16833 0.025 0.66323 6.9e-5c0.07945 1e-5 0.1434 0.06033 0.14336 0.13529l7.1e-5 0.67938c9e-6 0.07492-0.06394 0.13523-0.14334 0.13526l-0.66323-7e-5c-0.07945-9e-6 -0.1434-0.06033-0.14336-0.13529l-7e-5 -0.67938c-9e-6 -0.07492 0.06394-0.13523 0.14333-0.13526z"),
    "rounded-diamond": path("m0.57829 0.058879 0.36256 0.36263c0.04343 0.04344 0.04541 0.11139 0.0044 0.15236l-0.37145 0.37153c-0.04096 0.04097-0.1089 0.03899-0.15232-0.0044l-0.36256-0.36263c-0.04343-0.04344-0.04541-0.11139-0.0044-0.15236l0.37145-0.37153c0.04096-0.04097 0.1089-0.03899 0.15232 0.004399z"),
    "teardrop": path("M 0.975,0.64658972 C 0.975,0.82786247 0.76208656,0.975 0.50003926,0.975 0.23775109,0.975 0.02026146,0.82782823 0.02507851,0.64658972 0.03134067,0.40346614 0.29266543,0.30443291 0.50003926,0.025 0.72017826,0.29527426 0.975,0.46529985 0.975,0.64658972 Z"),
    "trapezoid": polygon("20% 0%, 80% 0%, 100% 100%, 0% 100%"),
    "trapezoid-down": polygon("0% 0%, 100% 0%, 80% 100%, 20% 100%"),
    "star": path("m1 0.75-0.33401-0.0010179-0.16599 0.25102-0.16599-0.25102-0.33401 0.0010179 0.16802-0.25-0.16802-0.25 0.33401 0.0010179 0.16599-0.25102 0.16599 0.25102 0.33401-0.0010179-0.16802 0.25z"),
    "clover": path("m0.29492 0a0.29492 0.28702 0 0 0-0.29492 0.28702 0.29492 0.28702 0 0 0 0.09774 0.21298 0.29492 0.28702 0 0 0-0.09774 0.21298 0.29492 0.28702 0 0 0 0.29492 0.28702 0.29492 0.28702 0 0 0 0.20508-0.0817 0.29492 0.28702 0 0 0 0.20509 0.0817 0.29492 0.28702 0 0 0 0.29491-0.28702 0.29492 0.28702 0 0 0-0.09722-0.21298 0.29492 0.28702 0 0 0 0.09722-0.21298 0.29492 0.28702 0 0 0-0.29491-0.28702 0.29492 0.28702 0 0 0-0.20463 0.0813 0.29492 0.28702 0 0 0-0.20554-0.0813z"),
    "clover-rotated": path("m0.5 3.6997e-5a0.24116 0.24129 0 0 0-0.24116 0.24129 0.24116 0.24129 0 0 0 9.9936e-4 0.018179 0.24116 0.24129 0 0 0-0.018688-7.9594e-4 0.24116 0.24129 0 0 0-0.24116 0.24129 0.24116 0.24129 0 0 0 0.24116 0.2413 0.24116 0.24129 0 0 0 0.018688-0.0012999 0.24116 0.24129 0 0 0-9.9936e-4 0.018709 0.24116 0.24129 0 0 0 0.24116 0.2413 0.24116 0.24129 0 0 0 0.24116-0.2413 0.24116 0.24129 0 0 0-9.9936e-4 -0.018709 0.24116 0.24129 0 0 0 0.018688 0.0013 0.24116 0.24129 0 0 0 0.24116-0.2413 0.24116 0.24129 0 0 0-0.24116-0.24129 0.24116 0.24129 0 0 0-0.018688 0.0012999 0.24116 0.24129 0 0 0 9.9936e-4 -0.018719 0.24116 0.24129 0 0 0-0.24116-0.24129z"),
}

for name, body in SHAPES.items():
    folder = ASSETS / f"note-{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    # 100 x 100 points drawn from the 0-1 box the web app's paths use.
    (folder / f"note-{name}.svg").write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 1 1">{body}</svg>\n'
    )
    (folder / "Contents.json").write_text(json.dumps({
        "images": [{"filename": f"note-{name}.svg", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": True, "template-rendering-intent": "template"},
    }, indent=2) + "\n")

print(f"{len(SHAPES)} imagesets in {ASSETS}")
```

Before running it, compare every path string above against `src/index.html` (lines with `<clipPath id="…-clip-path"`) and every polygon against `src/scss/_note-shapes.scss`; they must match character for character. (The web's names map as: `triangle-upside-down` → `triangle-down`, `moon-inverted` → `moon-flipped`, `heart-upside-down` → `heart-down`, `square` → `rounded-square`, `diamond` → `rounded-diamond`, `clover-rotated` → `clover-rotated`.)

- [ ] **Step 2: Run it and build**

```bash
cd ~/c/bsharp/SwiftApp
python3 scripts/note-shapes.py
command ls App/Assets.xcassets | grep -c '^note-'
xcodebuild -project ElisaMusica.xcodeproj -scheme ElisaMusica -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd build 2>&1 | grep -iE "warning: .*note-|error|BUILD" | tail -5
```

Expected: `18 imagesets in …`, `18`, and `** BUILD SUCCEEDED **` with no asset-catalog warning naming a `note-` image. Whether they render right is checked on screen in Task 12.

- [ ] **Step 3: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/scripts/note-shapes.py SwiftApp/App/Assets.xcassets
git commit -m "Add the note shapes as vector images generated from the web app's clip paths"
```

---

### Task 8: The game model and launch options

The glue between `Game`, the progress file and the player. It is created once, in the `App` struct: a view's `@State` initial value can be evaluated more than once, and this object decodes all the audio.

**Files:**
- Create: `SwiftApp/App/LaunchOptions.swift`, `SwiftApp/App/GameModel.swift`
- Modify: `SwiftApp/App/ElisaMusicaApp.swift`, `SwiftApp/App/HomeView.swift`

- [ ] **Step 1: Launch options**

`SwiftApp/App/LaunchOptions.swift`:

```swift
import ElisaKit
import Foundation

/// Launch arguments for UI tests and screenshots, e.g.
/// `-ElisaFreshState YES -ElisaLevel gray -ElisaAnswer red`. A normal launch has none.
struct LaunchOptions {
    /// Start at this level (a chord id).
    var level: String?
    /// Always ask this chord, like the web app's __bsharp_test_deterministic_color.
    var answer: String?
    /// Play on a throwaway progress file, so a test never touches real progress.
    var freshState = false

    static func current(_ defaults: UserDefaults = .standard) -> LaunchOptions {
        LaunchOptions(level: defaults.string(forKey: "ElisaLevel"),
                      answer: defaults.string(forKey: "ElisaAnswer"),
                      freshState: defaults.bool(forKey: "ElisaFreshState"))
    }

    /// Where progress is kept. A fresh state gets a new temporary file on every call, so read
    /// it once.
    func progressURL() -> URL {
        freshState
            ? URL.temporaryDirectory.appending(path: "\(UUID().uuidString)/progress.json")
            : ProgressStore.defaultURL
    }
}
```

- [ ] **Step 2: The model**

`SwiftApp/App/GameModel.swift`:

```swift
import ElisaKit
import Foundation
import Observation

/// The main screen's state: the game, its progress file and the chord player.
@MainActor @Observable
final class GameModel {
    private(set) var game: Game
    private let options: LaunchOptions
    private let store: ProgressStore
    private let player = ChordPlayer()
    private var revealTask: Task<Void, Never>?

    init(options: LaunchOptions = .current()) {
        self.options = options
        store = ProgressStore(url: options.progressURL())
        let now = Date().timeIntervalSince1970
        game = Game(progress: store.load(now: now) ?? .fresh(now: now), forcedAnswer: options.answer)
        game.start()
        if let level = options.level {
            game.changeLevel(to: level)
        }
        player.load(game.instrument)
        save()
        DevLog.event("game.start", ["level": game.level, "instrument": game.instrument.rawValue])
    }

    func play() {
        player.play(game.play())
    }

    func tap(_ color: String) {
        let outcome = game.tap(color)
        guard outcome != .ignored else { return }
        player.play(color)
        guard outcome != .sound else { return }
        DevLog.event("game.answer", ["asked": game.answer, "tapped": color, "streak": "\(game.profile.streak ?? 0)"])
        save()
        if outcome == .correct {
            scheduleRevealEnd()
        }
    }

    func becameActive() {
        game.becameActive()
        save()
    }

    /// Replaces all progress with a download from the web app, or a copy of this app's file.
    /// The current file is kept beside it first.
    func importProgress(_ data: Data) throws {
        let progress = try ProgressStore.decode(data)
        try store.archive("before-import", now: Date().timeIntervalSince1970)
        revealTask?.cancel()
        game = Game(progress: progress, forcedAnswer: options.answer)
        game.start()
        player.load(game.instrument)
        save()
        DevLog.event("progress.import", ["profiles": "\(progress.state.profiles.count)", "level": game.level])
    }

    /// The right answer stays on screen for the reveal; then the next chord waits for play.
    private func scheduleRevealEnd() {
        revealTask?.cancel()
        revealTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Characters.revealSeconds))
            guard !Task.isCancelled, let self else { return }
            self.game.revealFinished()
            self.save()
        }
    }

    private func save() {
        do {
            try store.save(game.progress)
        } catch {
            DevLog.event("progress.save-error", ["error": "\(error)"])
        }
    }
}
```

- [ ] **Step 3: Own the model in the App struct**

In `SwiftApp/App/ElisaMusicaApp.swift`, replace

```swift
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
```

with

```swift
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    /// Made once, here: a view's @State initial value can be evaluated again, and the model
    /// decodes all the audio.
    @State private var model = GameModel()

    var body: some Scene {
        WindowGroup {
            HomeView(model: model)
        }
    }
```

- [ ] **Step 4: Pass the model to the screen (layout comes in Task 9)**

Replace `SwiftApp/App/HomeView.swift` with:

```swift
import SwiftUI

/// The main screen. Task 9 of Plan 2 adds the controls and flags.
struct HomeView: View {
    let model: GameModel

    var body: some View {
        GeometryReader { geo in
            VStack {
                TitleCard(fontSize: TitleCard.fontSize(for: geo.size))
                    .padding(.top, 12)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .background(SkyBackground())
    }
}

#Preview { HomeView(model: GameModel(options: LaunchOptions(freshState: true))) }
```

- [ ] **Step 5: Build**

Run: `cd ~/c/bsharp/SwiftApp && xcodegen generate && xcodebuild -project ElisaMusica.xcodeproj -scheme ElisaMusica -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/App/LaunchOptions.swift SwiftApp/App/GameModel.swift SwiftApp/App/ElisaMusicaApp.swift SwiftApp/App/HomeView.swift
git commit -m "Add the game model with saved progress and launch options"
```

---

### Task 9: The game screen

Title, round play and next buttons, the hint arrow, and the flag grid with notes and the green check. Sizes copy the web app's `clamp()`s (`_bluey.scss`), with `vw`/`vh`/`vmin` taken from the screen's safe-area size.

**Files:**
- Modify: `SwiftApp/App/Theme.swift`
- Create: `SwiftApp/App/Metrics.swift`, `SwiftApp/App/ControlsBar.swift`, `SwiftApp/App/PlayHint.swift`, `SwiftApp/App/FlagGrid.swift`, `SwiftApp/App/NoteMarks.swift`
- Modify: `SwiftApp/App/HomeView.swift`

- [ ] **Step 1: Colors**

In `SwiftApp/App/Theme.swift`, after `static let grassDark = Color(hex: 0xCBDF56)`, add:

```swift
    /// $bluey-ink-pressed: the round buttons' lower edge.
    static let inkPressed = Color(hex: 0x4E4E7A)
    /// Note shapes (div.note: #333 at 95 %) and their letters ($fg-color-dark).
    static let noteInk = Color(hex: 0x333333)
    static let noteLetter = Color(hex: 0xDADADA)
    /// The outline and check of a right answer.
    static let correctGreen = Color(hex: 0x008000)
```

- [ ] **Step 2: Sizes**

`SwiftApp/App/Metrics.swift`:

```swift
import SwiftUI

/// The web app's clamp() sizes (_bluey.scss) for a screen of `size`.
struct Metrics {
    let size: CGSize

    private var vw: CGFloat { size.width / 100 }
    private var vh: CGFloat { size.height / 100 }
    private var vmin: CGFloat { min(size.width, size.height) / 100 }

    var landscape: Bool { size.width > size.height }
    var titleFont: CGFloat { TitleCard.fontSize(for: size) }
    /// .title-card bottom margin: clamp(8px, 2vh, 20px)
    var titleGap: CGFloat { clamp(2 * vh, 8, 20) }
    /// div.controls a: clamp(56px, min(14vmin, 11vh), 104px)
    var buttonSize: CGFloat { clamp(min(14 * vmin, 11 * vh), 56, 104) }
    /// div.controls i.fa: clamp(26px, min(6.5vmin, 5vh), 48px)
    var iconSize: CGFloat { clamp(min(6.5 * vmin, 5 * vh), 26, 48) }
    /// Both buttons' side margins: 2 × clamp(8px, 3vw, 14px)
    var buttonSpacing: CGFloat { 2 * clamp(3 * vw, 8, 14) }
    /// .control-wrapper bottom padding: clamp(6px, 1.5vh, 16px)
    var controlsGap: CGFloat { clamp(1.5 * vh, 6, 16) }
    /// .onboarding-arrow: clamp(1.8rem, 5vh, 3rem)
    var arrowSize: CGFloat { clamp(5 * vh, 28.8, 48) }
    /// #flag-holder gap: clamp(6px, 1.5vmin, 14px)
    var flagGap: CGFloat { clamp(1.5 * vmin, 6, 14) }

    private func clamp(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat {
        min(high, max(low, value))
    }
}
```

- [ ] **Step 3: Play and next**

`SwiftApp/App/ControlsBar.swift`:

```swift
import SwiftUI

/// The round play and next buttons.
struct ControlsBar: View {
    let buttonSize: CGFloat
    let iconSize: CGFloat
    let spacing: CGFloat
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: spacing) {
            Button(action: onPlay) {
                Image(systemName: "play.fill").font(.system(size: iconSize, weight: .black))
            }
            .buttonStyle(RoundButtonStyle(size: buttonSize))
            .accessibilityIdentifier("play-button")
            // The web app never enables its next button (game.ts only ever adds .deactivated),
            // so it is drawn dimmed and does nothing.
            RoundButtonFace(size: buttonSize, pressed: false) {
                Image(systemName: "arrow.right").font(.system(size: iconSize, weight: .black))
            }
            .opacity(0.35)
            .accessibilityHidden(true)
        }
    }
}

struct RoundButtonStyle: ButtonStyle {
    let size: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        RoundButtonFace(size: size, pressed: configuration.isPressed) { configuration.label }
    }
}

/// An ink circle with a darker lower edge that sinks when pressed (div.controls a).
struct RoundButtonFace<Label: View>: View {
    let size: CGFloat
    let pressed: Bool
    @ViewBuilder let label: () -> Label

    var body: some View {
        Circle()
            .fill(Theme.ink)
            .frame(width: size, height: size)
            .overlay(label().foregroundStyle(.white))
            .shadow(color: Theme.inkPressed, radius: 0, y: pressed ? 2 : 6)
            .shadow(color: .black.opacity(0.15), radius: 10, y: 12)
            .offset(y: pressed ? 4 : 0)
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}
```

- [ ] **Step 4: The hint**

`SwiftApp/App/PlayHint.swift`:

```swift
import SwiftUI

/// The first-run hint: an arrow up at the play button and no text, since she can't read yet.
/// Laid out like ControlsBar so the arrow sits under the play button.
struct PlayHint: View {
    let buttonSize: CGFloat
    let spacing: CGFloat
    let arrowSize: CGFloat

    var body: some View {
        HStack(spacing: spacing) {
            Text("↑")
                .font(.system(size: arrowSize))
                .foregroundStyle(Theme.ink)
                .frame(width: buttonSize)
                .accessibilityIdentifier("play-hint")
            Color.clear.frame(width: buttonSize, height: 1)
        }
    }
}
```

- [ ] **Step 5: Notes on a flag**

`SwiftApp/App/NoteMarks.swift`:

```swift
import ElisaKit
import SwiftUI

/// A flag's three notes on a diagonal, low note bottom left to high note top right
/// (.chord-notes-container), each a dark shape with its letter.
struct NoteMarks: View {
    let marks: [NoteMark]
    let letters: Bool

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let size = min(height * 0.3, width * 0.22)
            let inset = height * 0.03
            let centers = [
                CGPoint(x: width / 6, y: height - inset - size / 2),
                CGPoint(x: width / 2, y: height / 2),
                CGPoint(x: width * 5 / 6, y: inset + size / 2),
            ]
            ForEach(Array(zip(marks, centers).enumerated()), id: \.offset) { item in
                NoteMarkView(mark: item.element.0, size: size, letters: letters)
                    .position(item.element.1)
            }
        }
    }
}

struct NoteMarkView: View {
    let mark: NoteMark
    let size: CGFloat
    let letters: Bool

    var body: some View {
        ZStack {
            Image("note-\(mark.shape.rawValue)")
                .renderingMode(.template)
                .resizable()
                .foregroundStyle(Theme.noteInk.opacity(0.95))
                .frame(width: size * mark.scale, height: size * mark.scale)
            if letters {
                Text(mark.letter)
                    .font(Theme.text(size * 0.6, bold: true))
                    .foregroundStyle(Theme.noteLetter)
                    // The CSS nudge is a share of the letter's own box, about 0.6 of the shape.
                    .offset(x: size * 0.6 * mark.letterDX, y: size * 0.6 * mark.letterDY)
            }
        }
        .frame(width: size, height: size)
    }
}
```

- [ ] **Step 6: The flags**

`SwiftApp/App/FlagGrid.swift`:

```swift
import ElisaKit
import SwiftUI

/// The level's flags in rows that share the height left (the #flag-holder grid).
struct FlagGrid: View {
    let chords: [Chord]
    let landscape: Bool
    let gap: CGFloat
    let marked: String?
    let dimmed: Bool
    let noteStyle: NoteDisplay.Style?
    let onTap: (String) -> Void

    var body: some View {
        GeometryReader { geo in
            let columns = FlagLayout.columns(count: chords.count, landscape: landscape)
            let rows = stride(from: 0, to: chords.count, by: columns).map {
                Array(chords[$0..<min($0 + columns, chords.count)])
            }
            let width = (geo.size.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
            let height = (geo.size.height - gap * CGFloat(max(rows.count, 1) - 1)) / CGFloat(max(rows.count, 1))
            VStack(alignment: .leading, spacing: gap) {
                ForEach(rows.indices, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(rows[row]) { chord in
                            Button { onTap(chord.id) } label: {
                                FlagView(chord: chord, marked: marked == chord.id, dimmed: dimmed,
                                         noteStyle: noteStyle)
                            }
                            .buttonStyle(FlagButtonStyle())
                            .frame(width: width, height: height)
                            .accessibilityIdentifier("flag-\(chord.id)")
                            .accessibilityValue(marked == chord.id ? "correct" : dimmed ? "dimmed" : "")
                        }
                    }
                }
            }
        }
    }
}

/// A flag reacts to a tap by sounding its chord, not by changing its look.
struct FlagButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.contentShape(Rectangle())
    }
}

/// One flag: the chord's color, its notes when they show, and the green check on a right answer.
struct FlagView: View {
    let chord: Chord
    let marked: Bool
    let dimmed: Bool
    let noteStyle: NoteDisplay.Style?

    var body: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(Color(hex: chord.hex))
            .overlay {
                if let noteStyle {
                    NoteMarks(marks: NoteDisplay.marks(for: chord, shapes: noteStyle.shapes),
                              letters: noteStyle.letters)
                }
            }
            .overlay {
                if marked {
                    CorrectCheck()
                    // div.flag-correct: outline 4px solid green, outside the flag.
                    RoundedRectangle(cornerRadius: 26)
                        .strokeBorder(Theme.correctGreen, lineWidth: 4)
                        .padding(-4)
                }
            }
            .shadow(color: .black.opacity(0.15), radius: 0, y: 5)
            // #flag-holder.awaiting-play .flag: grayscale(1), opacity 0.4.
            .grayscale(dimmed ? 1 : 0)
            .opacity(dimmed ? 0.4 : 1)
    }
}

/// i.answer-icon.correct: a green check outlined in black, a little see-through.
struct CorrectCheck: View {
    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 56, weight: .black))
            .foregroundStyle(Theme.correctGreen)
            .shadow(color: .black, radius: 1)
            .shadow(color: .black, radius: 1)
            .opacity(0.75)
    }
}
```

- [ ] **Step 7: The screen**

Replace `SwiftApp/App/HomeView.swift` with:

```swift
import ElisaKit
import SwiftUI

/// The main screen: title, play and next, the play hint and the flags.
struct HomeView: View {
    let model: GameModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            let metrics = Metrics(size: geo.size)
            VStack(spacing: 0) {
                TitleCard(fontSize: metrics.titleFont)
                    .padding(.top, 12)
                    .padding(.bottom, metrics.titleGap)
                ControlsBar(buttonSize: metrics.buttonSize, iconSize: metrics.iconSize,
                            spacing: metrics.buttonSpacing, onPlay: { model.play() })
                    .padding(.bottom, metrics.controlsGap)
                if model.game.showsPlayHint {
                    PlayHint(buttonSize: metrics.buttonSize, spacing: metrics.buttonSpacing,
                             arrowSize: metrics.arrowSize)
                }
                FlagGrid(chords: model.game.chords, landscape: metrics.landscape, gap: metrics.flagGap,
                         marked: model.game.marked, dimmed: model.game.awaitingPlay,
                         noteStyle: model.game.noteStyle, onTap: { model.tap($0) })
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .background(SkyBackground())
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.becameActive() }
        }
    }
}

#Preview { HomeView(model: GameModel(options: LaunchOptions(freshState: true))) }
```

- [ ] **Step 8: Build and look at it**

```bash
cd ~/c/bsharp/SwiftApp
xcodegen generate
xcodebuild -project ElisaMusica.xcodeproj -scheme ElisaMusica -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd build 2>&1 | tail -3
APP=build/dd/Build/Products/Debug-iphonesimulator/ElisaMusica.app
BID=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist")
dev="iPad mini (A17 Pro)"
xcrun simctl boot "$dev" 2>/dev/null; xcrun simctl bootstatus "$dev" -b >/dev/null
xcrun simctl install "$dev" "$APP"
for level in yellow gray; do
  xcrun simctl terminate "$dev" "$BID" 2>/dev/null
  xcrun simctl launch "$dev" "$BID" -ElisaFreshState YES -ElisaLevel $level && sleep 3
  xcrun simctl io "$dev" screenshot "build/check-$level.png"
done
xcrun simctl shutdown "$dev"
```

Open `build/check-yellow.png` with the Read tool next to `Reference Material/screenshots/state-01-first-run-play-hint.png`, and `build/check-gray.png` next to `level-black-01-gris-ipad-portrait.png`. Expect: two full-width flags with the arrow under play; ten flags in three columns with dark note shapes and light letters on a diagonal. The gear and the pale outline round the screen are Plan 3. Any note shape that is missing or a solid square means its SVG didn't render: fix the generator (Task 7) and re-run it. Fix layout differences before committing; Task 12 does the full comparison.

- [ ] **Step 9: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/App/Theme.swift SwiftApp/App/Metrics.swift SwiftApp/App/ControlsBar.swift SwiftApp/App/PlayHint.swift SwiftApp/App/NoteMarks.swift SwiftApp/App/FlagGrid.swift SwiftApp/App/HomeView.swift
git commit -m "Add the game screen: play button, hint arrow and the flag grid"
```

---

### Task 10: Importing progress from the web app

Elisa's progress moves over with the web app's hidden download (tap the gear five times quickly, then the download link; it saves `bsharp_state_<time>.json`). In this app the matching hidden gesture is six quick taps on the title card. It opens the Files picker, checks the file, asks before replacing, and keeps the old progress beside the new.

**Files:**
- Modify: `SwiftApp/App/HomeView.swift`

- [ ] **Step 1: Add the gesture, picker and alerts**

Replace `SwiftApp/App/HomeView.swift` with:

```swift
import ElisaKit
import SwiftUI
import UniformTypeIdentifiers

/// The main screen: title, play and next, the play hint and the flags. Six quick taps on the
/// title open the parent-only progress import.
struct HomeView: View {
    let model: GameModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var unlock = TapUnlock()
    @State private var choosingFile = false
    @State private var pendingImport: Data?
    @State private var importError: String?

    var body: some View {
        GeometryReader { geo in
            let metrics = Metrics(size: geo.size)
            VStack(spacing: 0) {
                TitleCard(fontSize: metrics.titleFont)
                    .padding(.top, 12)
                    .padding(.bottom, metrics.titleGap)
                    .onTapGesture {
                        if unlock.tap(at: Date().timeIntervalSince1970) { choosingFile = true }
                    }
                ControlsBar(buttonSize: metrics.buttonSize, iconSize: metrics.iconSize,
                            spacing: metrics.buttonSpacing, onPlay: { model.play() })
                    .padding(.bottom, metrics.controlsGap)
                if model.game.showsPlayHint {
                    PlayHint(buttonSize: metrics.buttonSize, spacing: metrics.buttonSpacing,
                             arrowSize: metrics.arrowSize)
                }
                FlagGrid(chords: model.game.chords, landscape: metrics.landscape, gap: metrics.flagGap,
                         marked: model.game.marked, dimmed: model.game.awaitingPlay,
                         noteStyle: model.game.noteStyle, onTap: { model.tap($0) })
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .background(SkyBackground())
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.becameActive() }
        }
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.json]) { result in
            readImport(result)
        }
        .alert("¿Reemplazar el progreso con este archivo?",
               isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } })) {
            Button("Reemplazar", role: .destructive) { confirmImport() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("El progreso actual se guarda aparte por si acaso.")
        }
        .alert("No se pudo importar",
               isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
    }

    /// Reads and checks the file before asking, so a wrong file fails here and not after
    /// "Reemplazar".
    private func readImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            _ = try ProgressStore.decode(data)
            pendingImport = data
        } catch {
            importError = error.localizedDescription
        }
    }

    private func confirmImport() {
        guard let data = pendingImport else { return }
        pendingImport = nil
        do {
            try model.importProgress(data)
        } catch {
            importError = error.localizedDescription
        }
    }
}

#Preview { HomeView(model: GameModel(options: LaunchOptions(freshState: true))) }
```

- [ ] **Step 2: Build and try it in the simulator**

```bash
cd ~/c/bsharp/SwiftApp
xcodebuild -project ElisaMusica.xcodeproj -scheme ElisaMusica -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd build 2>&1 | tail -3
APP=build/dd/Build/Products/Debug-iphonesimulator/ElisaMusica.app
BID=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist")
dev="iPad mini (A17 Pro)"
xcrun simctl boot "$dev" 2>/dev/null; xcrun simctl bootstatus "$dev" -b >/dev/null
xcrun simctl install "$dev" "$APP"
# A download-shaped file at gray.
printf '%s\n' '{"state":{"profiles":{"100":{"id":100,"name":"Elisa","icon":"fa-paw","current_chord":"gray"}},"current_chord":"gray","current_profile":100},"history":{}}' > build/import-gray.json
open -a Simulator
```

Put the file in the simulator's Files app by dragging `SwiftApp/build/import-gray.json` from Finder onto the Simulator window (it lands in Files → On My iPad). Then in the app: tap the title six times quickly, pick the file, tap **Reemplazar**. Expect ten flags with note shapes (gray). Check the backup exists:

```bash
find "$(xcrun simctl get_app_container "iPad mini (A17 Pro)" "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' ~/c/bsharp/SwiftApp/build/dd/Build/Products/Debug-iphonesimulator/ElisaMusica.app/Info.plist)" data)/Library/Application Support/ElisaMusica" -name 'progress*'
```

Expected: `progress.json` and `progress.before-import-<time>.json`. Then `xcrun simctl shutdown "iPad mini (A17 Pro)"`.

(If dragging files into the simulator isn't possible in this session, say so in the report and leave the manual check for the user; the decoding is covered by the ElisaKit tests.)

- [ ] **Step 3: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/App/HomeView.swift
git commit -m "Import progress from a web app download with a hidden title gesture"
```

---

### Task 11: UI tests for the main flows

**Files:**
- Modify: `SwiftApp/project.yml`
- Create: `SwiftApp/UITests/GameFlowUITests.swift`

- [ ] **Step 1: Add the UI test target**

In `SwiftApp/project.yml`, under `targets: ElisaMusica:`, add a `scheme` key at the same indentation as `sources:` (so it sits inside the `ElisaMusica` target):

```yaml
    scheme:
      testTargets:
        - ElisaMusicaUITests
```

and add a second target at the end of the file, at the same indentation as `ElisaMusica:`:

```yaml
  ElisaMusicaUITests:
    type: bundle.ui-testing
    platform: iOS
    sources:
      - UITests
    dependencies:
      - target: ElisaMusica
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: $(ELISA_MUSICA_BUNDLE_ID).uitests
        GENERATE_INFOPLIST_FILE: YES
        CODE_SIGN_STYLE: Automatic
        TEST_TARGET_NAME: ElisaMusica
```

- [ ] **Step 2: Write the tests**

`SwiftApp/UITests/GameFlowUITests.swift`:

```swift
import XCTest

/// The main flows, on a throwaway progress file with red always the answer.
final class GameFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ElisaFreshState", "YES", "-ElisaAnswer", "red"] + extra
        app.launch()
        return app
    }

    private func value(_ element: XCUIElement) -> String {
        element.value as? String ?? ""
    }

    func testTheHintPointsAtPlayUntilItIsPressed() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["play-hint"].waitForExistence(timeout: 10))
        app.buttons["play-button"].tap()
        XCTAssertFalse(app.staticTexts["play-hint"].exists)
    }

    func testATapBeforePlayIsNotAnAnswer() {
        let app = launch()
        let red = app.buttons["flag-red"]
        XCTAssertTrue(red.waitForExistence(timeout: 10))
        red.tap()
        XCTAssertEqual(value(red), "")
    }

    func testWrongThenRightThenTheFlagsWaitForPlay() {
        let app = launch()
        let red = app.buttons["flag-red"]
        let yellow = app.buttons["flag-yellow"]
        XCTAssertTrue(red.waitForExistence(timeout: 10))
        app.buttons["play-button"].tap()

        yellow.tap()
        XCTAssertEqual(value(yellow), "", "a wrong answer isn't marked")

        red.tap()
        XCTAssertEqual(value(red), "correct")

        // After the 3 s reveal the next chord waits for play: dimmed, and a tap does nothing.
        expectation(for: NSPredicate(format: "value == 'dimmed'"), evaluatedWith: red)
        waitForExpectations(timeout: 8)
        red.tap()
        XCTAssertEqual(value(red), "dimmed")

        app.buttons["play-button"].tap()
        XCTAssertEqual(value(red), "")
        red.tap()
        XCTAssertEqual(value(red), "correct")
    }

    func testABlackKeyLevelHasTenFlags() {
        let app = launch(["-ElisaLevel", "gray"])
        XCTAssertTrue(app.buttons["flag-gray"].waitForExistence(timeout: 10))
        let flags = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'flag-'"))
        XCTAssertEqual(flags.count, 10)
    }
}
```

- [ ] **Step 3: Run them**

```bash
cd ~/c/bsharp/SwiftApp
xcodegen generate
xcodebuild test -project ElisaMusica.xcodeproj -scheme ElisaMusica -destination 'platform=iOS Simulator,name=iPhone 16e' -derivedDataPath build/dd 2>&1 | grep -E "Test Case .*(passed|failed)|TEST (SUCCEEDED|FAILED)|error:" | tail -15
```

Expected: four `passed` lines and `** TEST SUCCEEDED **`. If a test fails, the failure says which flow broke; fix the app, not the test, unless the test contradicts "Behavior being ported" above.

- [ ] **Step 4: Make sure the release build still archives**

`./deploy` archives the `ElisaMusica` scheme; a UI test target must not break that.

```bash
cd ~/c/bsharp/SwiftApp
xcodebuild -project ElisaMusica.xcodeproj -scheme ElisaMusica -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd build 2>&1 | tail -1
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/project.yml SwiftApp/UITests/GameFlowUITests.swift
git commit -m "Add UI tests for the play, answer and reveal flow"
```

---

### Task 12: Compare with the web app, screen by screen

A UI test (skipped unless asked for) takes the screenshots: every reference level in portrait and landscape on the iPad, portrait on the iPhone, and the answer states. They come out of the test result bundle.

**Files:**
- Create: `SwiftApp/UITests/ScreenshotTests.swift`

- [ ] **Step 1: Write the screenshot test**

`SwiftApp/UITests/ScreenshotTests.swift`:

```swift
import XCTest

/// Screenshots to compare with SwiftApp/Reference Material/screenshots/. Skipped unless the
/// test runner has ELISA_SCREENSHOTS=1 (pass TEST_RUNNER_ELISA_SCREENSHOTS=1 to xcodebuild).
final class ScreenshotTests: XCTestCase {
    static let levels = ["yellow", "blue", "black", "green", "orange", "purple", "pink", "brown",
                         "gray", "tan", "lightgreen", "lightpurple", "skyblue"]

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["ELISA_SCREENSHOTS"] == "1",
                          "set TEST_RUNNER_ELISA_SCREENSHOTS=1 to take screenshots")
    }

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ElisaFreshState", "YES"] + arguments
        app.launch()
        return app
    }

    private func keep(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testLevels() {
        let orientations: [(String, UIDeviceOrientation)] = UIDevice.current.userInterfaceIdiom == .pad
            ? [("portrait", .portrait), ("landscape", .landscapeLeft)]
            : [("portrait", .portrait)]
        for (name, orientation) in orientations {
            XCUIDevice.shared.orientation = orientation
            for level in Self.levels {
                let app = launch(["-ElisaLevel", level])
                _ = app.buttons["flag-\(level)"].waitForExistence(timeout: 10)
                keep(app, "level-\(level)-\(name)")
            }
        }
        XCUIDevice.shared.orientation = .portrait
    }

    func testAnswerStates() {
        XCUIDevice.shared.orientation = .portrait
        let app = launch(["-ElisaAnswer", "red"])
        let red = app.buttons["flag-red"]
        _ = red.waitForExistence(timeout: 10)
        keep(app, "state-01-first-run-play-hint")
        app.buttons["play-button"].tap()
        keep(app, "state-02-chord-playing")
        app.buttons["flag-yellow"].tap()
        keep(app, "state-03-wrong-answer")
        red.tap()
        keep(app, "state-04-correct")
        expectation(for: NSPredicate(format: "value == 'dimmed'"), evaluatedWith: red)
        waitForExpectations(timeout: 8)
        keep(app, "state-05-awaiting-play")
    }
}
```

- [ ] **Step 2: Take the screenshots on both simulators**

```bash
cd ~/c/bsharp/SwiftApp
xcodegen generate
for dev in "iPad mini (A17 Pro)" "iPhone 16e"; do
  tag=${dev//[^A-Za-z0-9]/}
  rm -rf "build/shots-$tag.xcresult" "build/shots-$tag"
  TEST_RUNNER_ELISA_SCREENSHOTS=1 xcodebuild test -project ElisaMusica.xcodeproj -scheme ElisaMusica \
    -destination "platform=iOS Simulator,name=$dev" -derivedDataPath build/dd \
    -only-testing:ElisaMusicaUITests/ScreenshotTests -resultBundlePath "build/shots-$tag.xcresult" 2>&1 | tail -1
  xcrun xcresulttool export attachments --path "build/shots-$tag.xcresult" --output-path "build/shots-$tag"
done
command ls build/shots-*/
```

Expected: `** TEST SUCCEEDED **` twice, and each folder holds PNGs plus a `manifest.json` that maps each file to its attachment name (`suggestedHumanReadableName`). Use the manifest to find each screenshot by name.

- [ ] **Step 3: Compare each one with its reference, with the Read tool**

| This app's screenshot | Reference in `Reference Material/screenshots/` |
|---|---|
| iPad `level-<id>-portrait` | `level-white-0N-<name>-ipad-portrait.png` / `level-black-0N-<name>-ipad-portrait.png` |
| iPad `level-<id>-landscape` | the same names with `-ipad-landscape.png` |
| iPhone `level-<id>-portrait` | the same names with `-iphone-portrait.png` |
| iPhone `state-01` … `state-05` | `state-01-first-run-play-hint.png` … `state-05-awaiting-play-after-reveal.png` |

(The reference files use the Spanish level names: amarillo = yellow, azul = blue, negro = black, verde = green, naranja = orange, morado = purple, rosa = pink, cafe = brown, gris = gray, beige = tan, verde-claro = lightgreen, lila = lightpurple, celeste = skyblue.)

For each pair check:
- the number of columns and rows of flags, and that the last row is never cut off;
- flag colors, corner rounding and the shadow under each flag;
- the play button (ink, round, white triangle) and the dimmed next button, their size and position under the title;
- on gray and later: a dark shape with a light letter for each note, low note bottom left to high note top right, the right shape per note (compare with `level-black-05-celeste-ipad-portrait.png`, which shows all of them);
- `state-01`: the arrow under the play button; `state-04`: green outline and check on red; `state-05`: both flags greyed out.

Known differences that are **not** bugs (they come in Plan 3): the gear button, the pale outline round the screen (streak track), the character and its name in `state-04`.

Fix every other difference in the views and repeat Steps 2–3 until they match. Then shut the simulators down: `xcrun simctl shutdown all`.

- [ ] **Step 4: Make sure the normal test run skips them**

```bash
cd ~/c/bsharp/SwiftApp
xcodebuild test -project ElisaMusica.xcodeproj -scheme ElisaMusica -destination 'platform=iOS Simulator,name=iPhone 16e' -derivedDataPath build/dd 2>&1 | grep -E "skipped|TEST (SUCCEEDED|FAILED)" | tail -4
```

Expected: the two `ScreenshotTests` cases reported as skipped, and `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/UITests/ScreenshotTests.swift
git status --short SwiftApp
git commit -m "Add screenshot tests to compare the game screen with the web app"
```

Also commit any view fixes from Step 3 in the same commit (add their paths explicitly). `git status --short SwiftApp` must show nothing under `build/`.

---

### Task 13: README and plan

**Files:**
- Modify: `SwiftApp/README.md`, `SwiftApp/PLAN.md`

- [ ] **Step 1: README**

In `SwiftApp/README.md`, replace the `## Build and test` section (from its heading up to `## Setup on a new machine`) with:

````markdown
## Build and test

```bash
cd SwiftApp/ElisaKit && swift test
```

```bash
cd SwiftApp && xcodegen generate && open ElisaMusica.xcodeproj
```

UI tests (main flows) on the simulator:

```bash
cd SwiftApp && xcodebuild test -project ElisaMusica.xcodeproj -scheme ElisaMusica -destination 'platform=iOS Simulator,name=iPhone 16e' -derivedDataPath build/dd
```

Screenshots to compare with `Reference Material/`: the same command with
`TEST_RUNNER_ELISA_SCREENSHOTS=1` in front and `-only-testing:ElisaMusicaUITests/ScreenshotTests
-resultBundlePath build/shots.xcresult` at the end, then
`xcrun xcresulttool export attachments --path build/shots.xcresult --output-path build/shots`.

Launch arguments for testing: `-ElisaFreshState YES` (throwaway progress), `-ElisaLevel <chord
id>`, `-ElisaAnswer <chord id>` (always ask that chord).

## Progress

Saved in `Application Support/ElisaMusica/progress.json`, in the same format as the web app's
state download. To bring progress over from https://bluey.chiq.me: in the web app tap the gear
five times quickly and tap the download link that appears; get the file onto the iPad (AirDrop
to Files); in this app tap the title six times quickly, pick the file and tap **Reemplazar**.
The previous progress is kept beside it as `progress.before-import-<time>.json`.

````

- [ ] **Step 2: PLAN.md**

In `SwiftApp/PLAN.md`:
- mark steps 3–7 done, the same way steps 1–2 are marked: `3. **Data and logic, test-first (done).**`, `4. **Persistence (done).**`, `5. **Audio (done).**`, `6. **Game screen (done).**`, `7. **Note shapes (done).**`;
- in the "Stack" list, replace

  ```markdown
  - A committed `ElisaMusica.xcodeproj`, not a generated one: `./deploy` bumps
    `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.pbxproj` and commits that.
  ```

  with

  ```markdown
  - `project.yml` is the source of truth; `ElisaMusica.xcodeproj` is generated by XcodeGen and
    gitignored. `./deploy` bumps `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in
    `project.yml` and commits that.
  ```
;
- in the "Stack" list, replace

  ```markdown
  - Audio: `AVAudioEngine` with one `AVAudioPlayerNode` per chord file, all preloaded into
    buffers, so a tap sounds the chord immediately. The audio session uses `.playback`, so the
    silent switch doesn't mute it.
  ```

  with

  ```markdown
  - Audio: `AVAudioEngine` with one `AVAudioPlayerNode`, every take of the current instrument
    preloaded into buffers, so a tap sounds the chord immediately. One node is enough because a
    new chord always cuts off the one sounding. The audio session uses `.playback`, so the
    silent switch doesn't mute it.
  ```

- in the "Folder layout" block, add a line after the `App/` entry's two lines:
  `  UITests/                main flows and screenshot tests (XCUITest)`, and replace the
  ElisaKit entry's last line (`                          AppQuickAction, DevLog`) with

  ```
                            AppQuickAction, DevLog, SavedProgress, ProgressStore, Sessions,
                            Game, ChordFiles, NoteDisplay, FlagLayout, TapUnlock
  ```

- [ ] **Step 3: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/README.md SwiftApp/PLAN.md
git commit -m "Document testing and progress import for the iOS app"
```

---

### Task 14: Ship it to the iPad (only with the user's approval)

- [ ] **Step 1: Everything green once more**

```bash
cd ~/c/bsharp/SwiftApp/ElisaKit && swift test 2>&1 | tail -2
cd ~/c/bsharp/SwiftApp && xcodebuild test -project ElisaMusica.xcodeproj -scheme ElisaMusica -destination 'platform=iOS Simulator,name=iPhone 16e' -derivedDataPath build/dd 2>&1 | tail -1
cd ~/c/bsharp/SwiftApp && for t in scripts/deploy/*_test.rb; do ruby "$t" | tail -1; done
```

Expected: no Swift failures, `** TEST SUCCEEDED **`, every Ruby line `0 failures, 0 errors`.

- [ ] **Step 2: Ask the user**

The deploy needs a clean tree on `main`. If `git status --short` shows the user's web-app changes, ask them to commit or stash them; don't do it yourself. Then ask for approval, explaining both deploys:

1. `SwiftApp/deploy minor --devlog --yes --summary "Playable game: flags, play, answers, note shapes, real chords, progress import."` publishes 0.2.0 as a diagnostics build, to measure the tap-to-sound delay on the iPad.
2. Right after, `SwiftApp/deploy --yes --summary "0.2.0 without diagnostics."` publishes 0.2.1, so the iPad ends on a normal build.

Each one commits, tags and pushes `main` to `github`. Wait for an explicit yes.

- [ ] **Step 3: The diagnostics build and the delay**

Start the DevLog server in the background, then deploy:

```bash
cd ~/c/bsharp && python3 SwiftApp/scripts/devlog/server.py
```

(run that one with `run_in_background: true`), then:

```bash
cd ~/c/bsharp && SwiftApp/deploy minor --devlog --yes --summary "Playable game: flags, play, answers, note shapes, real chords, progress import."
```

If the push reports a rejection but says `github/main is already at …; continuing`, git-sync got there first: check the tag reached the remote with `git ls-remote --tags github 'elisa-musica-ota-v*'`, and push it with `git push github elisa-musica-ota-v0.2.0` if it's missing.

Send the ntfy notification (the `ntfy` skill; see the project memory `ios-deploy-ntfy`). Ask the user to install it on the iPad, open it, press play and tap a dozen flags. Then read the records:

```bash
cd ~/c/bsharp/SwiftApp && command ls -t log | head -3 && grep -h '"audio\.' log/*.jsonl | tail -20
```

Report `decodeMs` from `audio.loaded` (how long the instrument takes to load at launch), `outputLatencyMs` + `ioBufferMs` (the hardware's share of the delay) and the typical `scheduleMs` from `audio.play`. Their sum is the delay from tap to sound. If it goes over about 50 ms, or `decodeMs` over about 1500, say so in the report; don't change the player in this plan.

Stop the server (`pkill -f scripts/devlog/server.py`).

- [ ] **Step 4: The normal build**

```bash
cd ~/c/bsharp && SwiftApp/deploy --yes --summary "0.2.0 without diagnostics."
```

Check the tag as in Step 3, send the ntfy notification for 0.2.1, and ask the user to install it on the iPad and confirm: the flags of her level show, play sounds a chord, a wrong tap sounds its chord, the right tap gets the green check, then the flags dim until play.

---

## Done when

- `cd SwiftApp/ElisaKit && swift test` passes: saved progress and import, sessions, the game rules, chord files, note display, grid layout, the hidden gesture (plus everything from Plan 1).
- `xcodebuild test` passes the four UI flows; the screenshot test's images match the references apart from the Plan 3 items.
- Elisa's iPad runs 0.2.1: she can play every level with real chords, and her progress is saved across launches and can be imported from the web app.
