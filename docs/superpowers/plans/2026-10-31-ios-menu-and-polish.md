# iOS Menu, Panels and iPad Polish Implementation Plan (Plan 4)

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The native app gets the web app's gear menu and its four panels (piano trainer, info text, stats history, profiles and settings), and behaves like an app on the iPad: no status bar or home indicator, edge swipes that need a second swipe, the screen kept on during a session, and Guided Access instructions in place of the web app's screen-pinning info.

**Architecture:** Every rule stays in the tested `ElisaKit` package: the level selector's labels, the profile icons, adding, editing, switching and deleting profiles (`Profiles.swift`), the history rows and their faces (`History.swift`), a `Game.editProgress` entry point for menu changes and the keep-awake rule. The app target only draws: a `MenuBar` in a top bar, a `PanelCard` that takes the place of the flags and the play button while a panel is open, and one view per panel. `GameModel` gets thin methods that call `ElisaKit`, reload the instrument and save.

**Tech Stack:** Swift 6.2 / SwiftUI, iOS 17+, Swift Testing (ElisaKit), XCTest UI tests, XcodeGen, Xcode 26.3.

**Spec:** `SwiftApp/PLAN.md` steps 9 (menu and panels) and 10 (iPad polish). Step 11 (moving Elisa over) is not part of this plan. Reference screenshots: `SwiftApp/Reference Material/screenshots/menu-01-gear-open.png` to `menu-06-profile-settings-scrolled.png`. The web app source is the behavior reference: `src/index.html` (the menu, the panels, the settings form, the screen-pinning modal), `src/ts/ui.ts` (panel toggling, the profile switcher, add/save/delete, the history list, the easter egg), `src/ts/state.ts` (`newProfile`), `src/ts/stats.ts` (the faces), `src/scss/_bluey.scss` and `_cim.scss` (the look). Where this plan and the TypeScript disagree, the TypeScript wins unless the plan says why.

**The plans:**
1. Foundation (done): ElisaKit logic, skeleton app, OTA deploy, first install.
2. Playable game (done, 0.2.x): persistence and import, audio, game screen, note shapes.
3. Rewards (done, 0.3.x): character reveal, streak outline, level-up with the instrument switch.
4. **This plan: Menu, panels and iPad polish** (`PLAN.md` steps 9–10).

---

## Conventions for whoever executes this

- **Repo rules** (`dev/AGENTS_MASTER.md`): commit messages are one short line with **no** `Co-Authored-By` trailer. Work on `main`.
- **git-sync pushes every commit within seconds.** Run the checks *before* committing and never amend; fix forward with a new commit.
- **Never stage files outside `SwiftApp/` or `docs/superpowers/plans/`.** The user may have uncommitted web-app changes in `src/` and `tests/`; leave them alone. Always `git add` explicit paths, and check `git status --short` first so build output and the generated `ElisaMusica.xcodeproj` (both gitignored) are never staged.
- **A hook blocks any shell command that mentions `.env`** (even inside a heredoc). Don't read `SwiftApp/.env`.
- **`ls` is aliased to eza here**, so use `command ls` when output matters.
- **Swift Testing gotcha:** `#expect(...)` wraps its expression in a closure, so a *mutating* call on a local `var` inside it does not compile. Call it into a `let` first, then `#expect` on the result. The same goes for `#expect(throws:)` around a mutating call: use `do { try …; Issue.record("…") } catch let e as ProfileError { #expect(e.message == …) }`.
- **ElisaKit is a Swift 6 package** (strict concurrency): new public types must be `Sendable`, and `static let`s must hold `Sendable` values.
- **Swift tests:** `cd ~/c/bsharp/SwiftApp/ElisaKit && swift test`. **App build:**
  `cd ~/c/bsharp/SwiftApp && xcodegen generate && xcodebuild -project ElisaMusica.xcodeproj -scheme ElisaMusica -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd build 2>&1 | tail -3`
  **UI tests:** `cd ~/c/bsharp/SwiftApp && xcodebuild test -project ElisaMusica.xcodeproj -scheme ElisaMusica -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' -derivedDataPath build/dd 2>&1 | grep -E "skipped|TEST (SUCCEEDED|FAILED)|error:" | tail -5`
- **SourceKit diagnostics in the editor** (`No such module 'Testing'`, `Cannot find 'Theme' in scope`) are noise from a stale index; trust `swift test` and `xcodebuild`.
- Simulators on this Mac: `iPad mini (A17 Pro)` and `iPhone 16e`. Run `xcrun simctl shutdown all` when a UI test or screenshot session is over.

## What Plans 1–3 left in place

- `ElisaKit`: `Chords.all`/`Chords.ids`/`Chords.firstBlackIndex` (gray, index 9), `Chord` (`id`, `spanishName`, `notes` like `"C#4"`/`"Bb3"`, `hex`); `Instrument` (`piano_1`, `guitar`, `guitar-strummed`, `CaseIterable`); `Defaults` (`guestProfileID = 100`, `targetNumber = 25`, the mode defaults); `Profile` (all the web app's fields, `init(id:name:icon:now:)`, `guest(now:)`, `instrument`); `SavedProgress` (`state`, `history`, the `profile` get/set property, `levelHistory`, `resetStats(done:now:)`, `resumeSession(now:)`, `changeLevel(to:now:)`, `recordAnswer`, `launch`); `Game` (`progress` is `public private(set)`, `profile`, `level`, `instrument`, `changeLevel(to:)`, `play()`, `tap(_:)`, `revealFinished()`, and a private `newSession()` that clears the question and shows the hint if the profile has it on); `TapUnlock` (six taps, each within 1.5 s).
- App: `GameModel` (owns `Game`, `ProgressStore`, `ChordPlayer`, `revealTask`; `play()`, `tap(_:)`, `becameActive()`, `importProgress(_:)`, private `save()`); `HomeView` (a 44 pt clear strip at the top whose six quick taps open the progress import, then `FlagGrid`, `PlayHint`, `ControlsBar`; the character reveal overlay; the streak outline overlay); `Metrics` (the web app's `clamp()` sizes); `Theme` (`ink`, `inkPressed`, `edge`, `noteInk`, `headline(_:)`, `text(_:bold:)`, `Color(hex:)`); `FlagButtonStyle`; `ChordPlayer.play(_:)` (every chord of the current instrument is already loaded, so the trainer needs no extra loading).
- Tests: `GameTests.swift` defines `GameTestClock` (`var now`); `SessionsTests.swift` shows how sessions are built in tests. UI tests launch with `-ElisaFreshState YES -ElisaAnswer red` and use the ids `flag-<chord id>` (value `correct`, `dimmed` or empty), `play-button`, `play-hint`, `character-reveal`, `streak-outline` (value = the streak). `ScreenshotTests.swift` is skipped unless `TEST_RUNNER_ELISA_SCREENSHOTS=1`.

## Behavior being ported (read once)

- **The gear.** A white circle, `clamp(40, 10 vmin, 56)` across with a soft shadow, at the top right, with an ink gear in it. Tapping it shows or hides a row of five items to its left: home, music note (trainer), info, chart (history), and the profile's icon with its name. The item for what is on screen is blue `#0077BE`, the rest ink. Home is "active" when no panel is open.
- **Panels** replace the flags, the hint and the play button (the web app hides `.control-wrapper` and `.flag-container` while `panel-open`); the gear row stays. A panel is a white card with radius 28, padding 20 and a 6 pt pale-blue ring. Tapping an item opens its panel, tapping it again (or home) closes it. **New in this app:** hiding the five items with the gear also closes the panel, so the game never sits behind a panel with no visible way back.
- **Piano trainer.** All 14 flags as plain rectangles with a 2 pt black border, three per row (five in landscape), the last row spread out. A tap plays that chord on the current instrument and counts for nothing.
- **Info.** Four paragraphs (text in Task 6). The two links open in Safari. The word "rojo", tapped six times quickly, unlocks level 0 (red) in the level picker until the app quits (`triggerEasterEgg`).
- **Stats history.** The current profile's filed sessions at every level, newest `updated_time` first, skipping sessions with no answers. Each row: a square of the level's color with a 1 pt black border, the start date `yyyy-MM-dd HH:mm` (local time), and `correct / answers (percent%) face` in bold. The face: `level = clamp(floor((percent − 50) / 10), 0, 4)`; levels 0–2 🐶, 3 🐕, 4 😊. The session in progress is not filed yet, so it is not listed (as in the web app). Empty: "Todavía no hay sesiones."
- **Profiles and settings.** At the top, a round button per profile (the guest last), the current one ringed in blue on light gray, and a dashed "+" that switches the form to "add" mode. Tapping another profile plays as it at once. Then the form: **Nivel** and **Instrumento** apply as soon as they change; the rest waits for **Guardar** (edit mode) or **Agregar perfil** (add mode), which close the panel. **Borrar perfil** asks first and goes back to the guest; it is disabled for the guest. The guest's name can't be edited. Error messages are the web app's (Task 3). The hidden **Tema** row is not ported.
- **Fijar pantalla → Info** opens the Guided Access instructions (the web app's screen-pinning modal, which already describes Guided Access), plus a line saying it is on when `UIAccessibility.isGuidedAccessEnabled`.
- **Two deliberate fixes over the web app**, both in `ElisaKit` with tests: switching profiles files the old profile's session under *its* level and resumes the new profile's parked session at *its* level (the web app files it under the level of whoever played before); deleting a profile also deletes its history, so a new profile that gets the same id doesn't inherit it.
- **iPad polish.** No status bar, no home indicator, system edge gestures deferred (a swipe from an edge needs a second swipe). The screen stays on from any play or flag tap until 5 minutes after the last one, then the normal auto-lock applies again. Rounded display corners must not clip the gear or the flags.

## Names used everywhere

| Thing | Value |
|---|---|
| Menu ids | `menu-gear`, `menu-home`, `menu-trainer`, `menu-info`, `menu-history`, `menu-profile` (value `active` on the one showing) |
| Panel ids | `info-panel`, `trainer-<chord id>`, `history-row` (label: date and summary), `history-empty` |
| Profile panel ids | `switcher-<profile id>`, `profile-add`, `profile-level`, `profile-instrument`, `profile-name`, `icon-<fa id>` (value `selected`), `profile-show-chord`, `profile-reveal`, `profile-display`, `profile-hints`, `profile-target`, `profile-selection`, `profile-guided-access`, `profile-delete`, `profile-save`, `profile-submit-add`, `guided-access-info`, `guided-access-ok` |
| Import strip | `import-strip` (the clear area of the top bar; six quick taps open the file picker, as before) |
| Active color | `Theme.active` = `#0077BE` |
| New log events | `menu.level`, `menu.instrument`, `menu.switch-profile`, `menu.add-profile`, `menu.update-profile`, `menu.delete-profile` |
| Version to ship | `0.4.0` (`SwiftApp/deploy minor`) |

## File structure

```
SwiftApp/
  ElisaKit/Sources/ElisaKit/
    LevelOptions.swift              level labels, Chords.chord(_:), Instrument.spanishName
    ProfileIcons.swift              fa-* ids → SF Symbols
    Profiles.swift                  ProfileSettings, ProfileError, add/update/switch/delete
    History.swift                   Mood, HistoryRow, SavedProgress.historyRows
    KeepAwake.swift                 the keep-the-screen-on rule
    Game.swift                      + editProgress(_:)
  ElisaKit/Tests/ElisaKitTests/
    LevelOptionsTests.swift, ProfileIconsTests.swift, ProfilesTests.swift,
    HistoryTests.swift, KeepAwakeTests.swift, GameEditTests.swift
  App/
    GameModel.swift                 + menu actions, trainer, easter egg, keep awake
    Theme.swift                     + active
    Metrics.swift                   + gear and menu sizes
    PillButton.swift                the web app's pill buttons
    PanelCard.swift                 the white card
    InfoPanel.swift, TrainerPanel.swift, HistoryPanel.swift
    ProfilePanel.swift              switcher + settings form
    GuidedAccessInfo.swift          the sheet behind "Fijar pantalla"
    MenuBar.swift                   gear + five items, Panel enum
    HomeView.swift                  top bar, panels in place of the game
    ElisaMusicaApp.swift            status bar, home indicator, edge gestures
  UITests/MenuUITests.swift         menu and panel flows
  UITests/ScreenshotTests.swift     + menu captures
```

---

### Task 1: Labels for the menus (levels, instruments, profile icons)

**Files:**
- Create: `SwiftApp/ElisaKit/Sources/ElisaKit/LevelOptions.swift`, `SwiftApp/ElisaKit/Sources/ElisaKit/ProfileIcons.swift`
- Test: `SwiftApp/ElisaKit/Tests/ElisaKitTests/LevelOptionsTests.swift`, `SwiftApp/ElisaKit/Tests/ElisaKitTests/ProfileIconsTests.swift`

- [ ] **Step 1: Write the failing tests**

`SwiftApp/ElisaKit/Tests/ElisaKitTests/LevelOptionsTests.swift`:

```swift
import Testing
@testable import ElisaKit

@Suite struct LevelOptionsTests {
    @Test func notesAreNamedInSolfege() {
        #expect(LevelOptions.solfege("C4") == "Do")
        #expect(LevelOptions.solfege("G4") == "Sol")
        #expect(LevelOptions.solfege("C#4") == "Do♯")
        #expect(LevelOptions.solfege("Bb3") == "Si♭")
        #expect(LevelOptions.solfege("Eb4") == "Mi♭")
    }

    @Test func labelsMatchTheWebAppsSelector() {
        func label(_ id: String) -> String { LevelOptions.label(for: Chords.chord(id)!) }
        #expect(label("red") == "Nivel 0: Rojo (Do Mi Sol)")
        #expect(label("yellow") == "Nivel 1: Amarillo (Do Fa La)")
        #expect(label("blue") == "Nivel 2: Azul (Si Re Sol)")
        #expect(label("brown") == "Nivel 8: Café (Sol Do Mi)")
        #expect(label("gray") == "Nivel 1: Gris (La Do♯ Mi)")
        #expect(label("lightpurple") == "Nivel 4: Lila (Si♭ Re Fa)")
        #expect(label("skyblue") == "Nivel 5: Celeste (Mi♭ Sol Si♭)")
    }

    @Test func redIsHiddenUnlessAsked() {
        #expect(LevelOptions.white(includingRed: false).map(\.id)
            == ["yellow", "blue", "black", "green", "orange", "purple", "pink", "brown"])
        #expect(LevelOptions.white(includingRed: true).first?.id == "red")
        #expect(LevelOptions.black.map(\.id) == ["gray", "tan", "lightgreen", "lightpurple", "skyblue"])
    }

    @Test func chordsAreFoundById() {
        #expect(Chords.chord("tan")?.spanishName == "Beige")
        #expect(Chords.chord("nope") == nil)
    }

    @Test func instrumentsHaveTheSelectorsNames() {
        #expect(Instrument.allCases.map(\.spanishName) == ["Piano", "Guitarra", "Guitarra (rasgueo)"])
    }
}
```

`SwiftApp/ElisaKit/Tests/ElisaKitTests/ProfileIconsTests.swift`:

```swift
import Testing
@testable import ElisaKit

@Suite struct ProfileIconsTests {
    @Test func theNineIconsInTheFormsOrder() {
        #expect(ProfileIcons.all == ["fa-user", "fa-truck", "fa-bolt", "fa-paw", "fa-soccer-ball-o",
                                     "fa-smile-o", "fa-umbrella", "fa-trophy", "fa-taxi"])
    }

    @Test func eachHasItsOwnSymbol() {
        let symbols = ProfileIcons.all.map(ProfileIcons.symbol(for:))
        #expect(Set(symbols).count == 9)
        #expect(ProfileIcons.symbol(for: "fa-paw") == "pawprint.fill")
    }

    @Test func anUnknownIconIsAPerson() {
        #expect(ProfileIcons.symbol(for: "fa-rocket") == "person.fill")
    }
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `cd ~/c/bsharp/SwiftApp/ElisaKit && swift test 2>&1 | grep -E "error:|failed" | head -5`
Expected: compile errors, `cannot find 'LevelOptions' in scope` and `cannot find 'ProfileIcons' in scope`.

- [ ] **Step 3: Write the code**

`SwiftApp/ElisaKit/Sources/ElisaKit/LevelOptions.swift`:

```swift
/// One option of the level picker.
public struct LevelOption: Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
}

/// The level selector's options (index.html #chord-selector).
public enum LevelOptions {
    private static let solfegeNames: [Character: String] = [
        "C": "Do", "D": "Re", "E": "Mi", "F": "Fa", "G": "Sol", "A": "La", "B": "Si",
    ]

    /// "C#4" → "Do♯", "Bb3" → "Si♭", "G4" → "Sol".
    public static func solfege(_ note: String) -> String {
        guard let letter = note.first, let name = solfegeNames[letter] else { return note }
        switch note.dropFirst().first {
        case "#": return name + "♯"
        case "b": return name + "♭"
        default: return name
        }
    }

    /// "Nivel 1: Amarillo (Do Fa La)". White levels count from red (0), black ones from gray (1).
    public static func label(for chord: Chord) -> String {
        let index = Chords.ids.firstIndex(of: chord.id) ?? 0
        let number = index >= Chords.firstBlackIndex ? index - Chords.firstBlackIndex + 1 : index
        let notes = chord.notes.map(solfege).joined(separator: " ")
        return "Nivel \(number): \(chord.spanishName) (\(notes))"
    }

    /// "Acordes blancos". Red only once it is unlocked (ui.ts triggerEasterEgg) or already the level.
    public static func white(includingRed: Bool) -> [LevelOption] {
        Chords.all.prefix(Chords.firstBlackIndex)
            .filter { includingRed || $0.id != "red" }
            .map { LevelOption(id: $0.id, label: label(for: $0)) }
    }

    /// "Acordes negros".
    public static var black: [LevelOption] {
        Chords.all.dropFirst(Chords.firstBlackIndex).map { LevelOption(id: $0.id, label: label(for: $0)) }
    }
}

extension Chords {
    public static func chord(_ id: String) -> Chord? {
        all.first { $0.id == id }
    }
}

extension Instrument {
    /// As the instrument selector names it.
    public var spanishName: String {
        switch self {
        case .piano: "Piano"
        case .guitar: "Guitarra"
        case .guitarStrummed: "Guitarra (rasgueo)"
        }
    }
}
```

`SwiftApp/ElisaKit/Sources/ElisaKit/ProfileIcons.swift`:

```swift
/// The profile icons. Saved progress keeps the web app's Fork Awesome ids; the app draws an
/// SF Symbol for each.
public enum ProfileIcons {
    /// In the settings form's order (index.html profile_icon_selector).
    public static let all = ["fa-user", "fa-truck", "fa-bolt", "fa-paw", "fa-soccer-ball-o",
                             "fa-smile-o", "fa-umbrella", "fa-trophy", "fa-taxi"]

    private static let symbols: [String: String] = [
        "fa-user": "person.fill",
        "fa-truck": "truck.box.fill",
        "fa-bolt": "bolt.fill",
        "fa-paw": "pawprint.fill",
        "fa-soccer-ball-o": "soccerball",
        "fa-smile-o": "face.smiling",
        "fa-umbrella": "umbrella.fill",
        "fa-trophy": "trophy.fill",
        "fa-taxi": "car.fill",
    ]

    /// The symbol for a saved icon id; a person for one this app doesn't know.
    public static func symbol(for icon: String) -> String {
        symbols[icon] ?? "person.fill"
    }
}
```

- [ ] **Step 4: Run the tests**

Run: `cd ~/c/bsharp/SwiftApp/ElisaKit && swift test 2>&1 | tail -2`
Expected: `Test run with N tests in M suites passed`, no failures.

- [ ] **Step 5: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/ElisaKit/Sources/ElisaKit/LevelOptions.swift SwiftApp/ElisaKit/Sources/ElisaKit/ProfileIcons.swift SwiftApp/ElisaKit/Tests/ElisaKitTests/LevelOptionsTests.swift SwiftApp/ElisaKit/Tests/ElisaKitTests/ProfileIconsTests.swift
git commit -m "Add the level, instrument and profile icon labels for the menus"
```

---

### Task 2: Adding, editing, switching and deleting profiles

**Files:**
- Create: `SwiftApp/ElisaKit/Sources/ElisaKit/Profiles.swift`
- Test: `SwiftApp/ElisaKit/Tests/ElisaKitTests/ProfilesTests.swift`

- [ ] **Step 1: Write the failing tests**

`SwiftApp/ElisaKit/Tests/ElisaKitTests/ProfilesTests.swift`:

```swift
import Testing
@testable import ElisaKit

private let t0 = 1_793_400_000.0

private func settings(_ name: String, icon: String? = "fa-truck", target: String = "25") -> ProfileSettings {
    var s = ProfileSettings.blank
    s.name = name
    s.icon = icon
    s.targetNumber = target
    return s
}

private func expectError(_ message: String, _ action: () throws -> Void) {
    do {
        try action()
        Issue.record("expected “\(message)”")
    } catch let error as ProfileError {
        #expect(error.message == message)
    } catch {
        Issue.record("unexpected \(error)")
    }
}

@Suite struct ProfilesTests {
    @Test func theFormStartsFromTheProfile() {
        var guest = Profile.guest(now: t0)
        guest.targetNumber = 30
        guest.chordSelectionMode = "adaptive"
        let s = ProfileSettings(profile: guest)
        #expect(s.name == "Elisa")
        #expect(s.icon == "fa-paw")
        #expect(s.targetNumber == "30")
        #expect(s.chordSelectionMode == "adaptive")
    }

    @Test func aBlankFormHasTheDefaultsAndTheFirstIcon() {
        let s = ProfileSettings.blank
        #expect(s.name == "")
        #expect(s.icon == "fa-user")
        #expect(s.targetNumber == "25")
        #expect(s.showChordMode == Defaults.showChordMode)
        #expect(s.enableOnboardingHints == Defaults.enableOnboardingHints)
    }

    @Test func aNewProfileGetsTheNextFreeIdAndPlays() throws {
        var p = SavedProgress.fresh(now: t0)
        let papa = try p.addProfile(settings("Papá"), now: t0 + 1)
        #expect(papa == 101)
        #expect(p.state.currentProfile == 101)
        #expect(p.profile.name == "Papá")
        #expect(p.profile.icon == "fa-truck")
        #expect(p.profile.currentChord == Defaults.level)
        #expect(p.profile.instrument == .piano)
        let mama = try p.addProfile(settings("Mamá"), now: t0 + 2)
        #expect(mama == 102)
    }

    @Test func addingChecksTheForm() {
        var p = SavedProgress.fresh(now: t0)
        expectError("Escribe un nombre y elige un ícono.") { try p.addProfile(settings(""), now: t0) }
        expectError("Escribe un nombre y elige un ícono.") { try p.addProfile(settings("Papá", icon: nil), now: t0) }
        expectError("Ya existe un perfil llamado elisa.") { try p.addProfile(settings("elisa"), now: t0) }
        expectError("La meta debe ser un número entero; recibí: 2.5") {
            try p.addProfile(settings("Papá", target: "2.5"), now: t0)
        }
        #expect(p.state.profiles.count == 1)
    }

    @Test func savingTheFormChangesTheCurrentProfile() throws {
        var p = SavedProgress.fresh(now: t0)
        var s = ProfileSettings(profile: p.profile)
        s.icon = "fa-bolt"
        s.targetNumber = " 30 "
        s.revealChordMode = "after_guess"
        s.enableOnboardingHints = false
        try p.updateProfile(s)
        #expect(p.profile.icon == "fa-bolt")
        #expect(p.profile.targetNumber == 30)
        #expect(p.profile.revealChordMode == "after_guess")
        #expect(!p.profile.enableOnboardingHints)
        #expect(p.profile.name == "Elisa")
    }

    @Test func savingChecksTheForm() throws {
        var p = SavedProgress.fresh(now: t0)
        try p.addProfile(settings("Papá"), now: t0)
        var s = ProfileSettings(profile: p.profile)
        s.name = "ELISA"
        expectError("El nombre ELISA ya está en uso; elige otro.") { try p.updateProfile(s) }
        s = ProfileSettings(profile: p.profile)
        s.icon = nil
        expectError("¡Elige un ícono!") { try p.updateProfile(s) }
        s = ProfileSettings(profile: p.profile)
        s.targetNumber = "muchas"
        expectError("La meta debe ser un número válido; recibí: muchas") { try p.updateProfile(s) }
        s = ProfileSettings(profile: p.profile)
        s.name = ""
        expectError("Escribe un nombre.") { try p.updateProfile(s) }
    }

    @Test func switchingParksTheSessionAndPicksUpTheOther() throws {
        var p = SavedProgress.fresh(now: t0)
        p.recordAnswer(played: "red", chosen: "red", now: t0 + 1)
        p.recordAnswer(played: "red", chosen: "yellow", now: t0 + 2)
        try p.addProfile(settings("Papá"), now: t0 + 3)
        #expect(p.profile.stats.identifications == 0)
        let parked = p.history["100"]?["yellow"]?.last
        #expect(parked?.identifications == 2)
        #expect(parked?.done == false)

        p.changeLevel(to: "blue", now: t0 + 4)
        p.switchProfile(to: 100, now: t0 + 5)
        #expect(p.state.currentChord == "yellow")
        #expect(p.profile.stats.identifications == 2)
        #expect(p.profile.stats.correct == 1)

        p.switchProfile(to: 101, now: t0 + 6)
        #expect(p.state.currentChord == "blue")
        #expect(p.profile.currentChord == "blue")
    }

    @Test func switchingKeepsEachStreak() throws {
        var p = SavedProgress.fresh(now: t0)
        p.profile.streak = 7
        try p.addProfile(settings("Papá"), now: t0 + 1)
        p.switchProfile(to: 100, now: t0 + 2)
        #expect(p.profile.streak == 7)
    }

    @Test func switchingToAnUnknownProfileDoesNothing() {
        var p = SavedProgress.fresh(now: t0)
        p.switchProfile(to: 999, now: t0)
        #expect(p.state.currentProfile == 100)
    }

    @Test func theGuestComesLastInTheSwitcher() throws {
        var p = SavedProgress.fresh(now: t0)
        try p.addProfile(settings("Papá"), now: t0)
        try p.addProfile(settings("Mamá"), now: t0)
        #expect(p.switcherProfiles.map(\.id) == [101, 102, 100])
    }

    @Test func deletingGoesBackToTheGuestAndDropsTheHistory() throws {
        var p = SavedProgress.fresh(now: t0)
        try p.addProfile(settings("Papá"), now: t0 + 1)
        p.recordAnswer(played: "red", chosen: "red", now: t0 + 2)
        p.changeLevel(to: "blue", now: t0 + 3) // files Papá's session at yellow
        #expect(p.history["101"] != nil)
        try p.deleteProfile(id: 101, now: t0 + 4)
        #expect(p.state.currentProfile == 100)
        #expect(p.state.profiles["101"] == nil)
        #expect(p.history["101"] == nil)
        #expect(p.state.currentChord == "yellow")
    }

    @Test func theGuestCantBeDeleted() {
        var p = SavedProgress.fresh(now: t0)
        expectError("No se puede borrar el perfil principal.") { try p.deleteProfile(id: 100, now: t0) }
        #expect(p.state.profiles["100"] != nil)
    }
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `cd ~/c/bsharp/SwiftApp/ElisaKit && swift test 2>&1 | grep -E "error:" | head -3`
Expected: `cannot find 'ProfileSettings' in scope` (and similar).

- [ ] **Step 3: Write the code**

`SwiftApp/ElisaKit/Sources/ElisaKit/Profiles.swift`:

```swift
import Foundation

/// The settings form (ui.ts getProfileSettings). The goal stays text until it is checked, as
/// the web app reads it from an input.
public struct ProfileSettings: Equatable, Sendable {
    public var name: String
    public var icon: String?
    public var targetNumber: String
    public var showChordMode: String
    public var revealChordMode: String
    public var chordDisplayMode: String
    public var persistReactionFace: Bool
    public var enableOnboardingHints: Bool
    public var chordSelectionMode: String

    /// The form filled in from a profile (populateProfileSettings).
    public init(profile: Profile) {
        name = profile.name
        icon = profile.icon
        targetNumber = String(profile.targetNumber)
        showChordMode = profile.showChordMode
        revealChordMode = profile.revealChordMode
        chordDisplayMode = profile.chordDisplayMode
        persistReactionFace = profile.persistReactionFace
        enableOnboardingHints = profile.enableOnboardingHints
        chordSelectionMode = profile.chordSelectionMode
    }

    /// The form for a new profile (openProfileAdder): the defaults, no name, the first icon.
    public static var blank: ProfileSettings {
        var settings = ProfileSettings(profile: Profile(id: 0, name: "", icon: ProfileIcons.all[0], now: 0))
        settings.name = ""
        return settings
    }
}

/// A form that can't be saved, with the web app's message for it.
public struct ProfileError: Error, Equatable, Sendable {
    public let message: String
}

extension Profile {
    mutating func apply(_ settings: ProfileSettings, icon: String, targetNumber: Int) {
        name = settings.name
        self.icon = icon
        self.targetNumber = targetNumber
        showChordMode = settings.showChordMode
        revealChordMode = settings.revealChordMode
        chordDisplayMode = settings.chordDisplayMode
        persistReactionFace = settings.persistReactionFace
        enableOnboardingHints = settings.enableOnboardingHints
        chordSelectionMode = settings.chordSelectionMode
    }
}

extension SavedProgress {
    /// The switcher's order: every profile but the guest by id, then the guest
    /// (populateProfileSwitcher).
    public var switcherProfiles: [Profile] {
        let others = state.profiles.values.filter { $0.id != Defaults.guestProfileID }.sorted { $0.id < $1.id }
        let guest = state.profiles[String(Defaults.guestProfileID)]
        return others + (guest.map { [$0] } ?? [])
    }

    /// Case-insensitive, over every profile (isProfileNameTaken).
    public func isNameTaken(_ name: String) -> Bool {
        state.profiles.values.contains { $0.name.lowercased() == name.lowercased() }
    }

    /// The goal as a whole number (utils.ts validInt), surrounding spaces allowed.
    static func target(_ text: String) -> Int? {
        Int(text.trimmingCharacters(in: .whitespaces))
    }

    /// Adds a profile and plays as it (addProfile). Its id is the first free one after the
    /// guest's, as newProfile picks it.
    @discardableResult
    public mutating func addProfile(_ settings: ProfileSettings, now: Double) throws -> Int {
        guard let icon = settings.icon, !settings.name.isEmpty else {
            throw ProfileError(message: "Escribe un nombre y elige un ícono.")
        }
        if isNameTaken(settings.name) {
            throw ProfileError(message: "Ya existe un perfil llamado \(settings.name).")
        }
        guard let target = Self.target(settings.targetNumber) else {
            throw ProfileError(message: "La meta debe ser un número entero; recibí: \(settings.targetNumber)")
        }
        var id = Defaults.guestProfileID + 1
        while state.profiles[String(id)] != nil { id += 1 }
        var profile = Profile(id: id, name: settings.name, icon: icon, now: now)
        profile.apply(settings, icon: icon, targetNumber: target)
        state.profiles[String(id)] = profile
        switchProfile(to: id, now: now)
        return id
    }

    /// Saves the form over the current profile (submitProfileChanges). An empty name is refused
    /// too; the web app only avoids it by disabling the guest's name field.
    public mutating func updateProfile(_ settings: ProfileSettings) throws {
        if settings.name != profile.name && isNameTaken(settings.name) {
            throw ProfileError(message: "El nombre \(settings.name) ya está en uso; elige otro.")
        }
        guard let icon = settings.icon else { throw ProfileError(message: "¡Elige un ícono!") }
        guard let target = Self.target(settings.targetNumber) else {
            throw ProfileError(message: "La meta debe ser un número válido; recibí: \(settings.targetNumber)")
        }
        guard !settings.name.isEmpty else { throw ProfileError(message: "Escribe un nombre.") }
        profile.apply(settings, icon: icon, targetNumber: target)
    }

    /// Plays as another profile (setCurrentProfile). The current session is parked, unfinished,
    /// at its own level; the other profile's parked session at its level is picked up again.
    /// (The web app files the new profile's session under the previous profile's level.)
    public mutating func switchProfile(to id: Int, now: Double) {
        guard id != state.currentProfile, state.profiles[String(id)] != nil else { return }
        resetStats(done: false, now: now)
        state.currentProfile = id
        if !Chords.ids.contains(profile.currentChord) {
            profile.currentChord = Defaults.level
        }
        state.currentChord = profile.currentChord
        profile.stats.currentChord = profile.currentChord
        resumeSession(now: now)
    }

    /// Deletes a profile and its history (deleteProfile). Deleting the one playing goes back to
    /// the guest. The history goes too, so a later profile that gets the same id starts clean.
    public mutating func deleteProfile(id: Int, now: Double) throws {
        guard id != Defaults.guestProfileID else {
            throw ProfileError(message: "No se puede borrar el perfil principal.")
        }
        guard state.profiles[String(id)] != nil else { return }
        if id == state.currentProfile {
            switchProfile(to: Defaults.guestProfileID, now: now)
        }
        state.profiles[String(id)] = nil
        history[String(id)] = nil
    }
}
```

- [ ] **Step 4: Run the tests**

Run: `cd ~/c/bsharp/SwiftApp/ElisaKit && swift test 2>&1 | tail -2`
Expected: all pass. If `switchingParksTheSessionAndPicksUpTheOther` fails on the parked session, print `p.history` in the test to see where `resetStats` filed it before changing the code; the session must be filed under the level that was in play when the switch happened.

- [ ] **Step 5: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/ElisaKit/Sources/ElisaKit/Profiles.swift SwiftApp/ElisaKit/Tests/ElisaKitTests/ProfilesTests.swift
git commit -m "Add, edit, switch and delete profiles in ElisaKit"
```

---

### Task 3: History rows, the keep-awake rule and Game.editProgress

**Files:**
- Create: `SwiftApp/ElisaKit/Sources/ElisaKit/History.swift`, `SwiftApp/ElisaKit/Sources/ElisaKit/KeepAwake.swift`
- Modify: `SwiftApp/ElisaKit/Sources/ElisaKit/Game.swift`
- Test: `SwiftApp/ElisaKit/Tests/ElisaKitTests/HistoryTests.swift`, `KeepAwakeTests.swift`, `GameEditTests.swift` (same folder)

- [ ] **Step 1: Write the failing tests**

`SwiftApp/ElisaKit/Tests/ElisaKitTests/HistoryTests.swift`:

```swift
import Foundation
import Testing
@testable import ElisaKit

private let t0 = 1_793_400_000.0 // 2026-10-30 22:40 UTC

private func session(_ chord: String, start: Double, correct: Int, answers: Int, updated: Double) -> SessionStats {
    var s = SessionStats(currentChord: chord, now: start)
    s.correct = correct
    s.identifications = answers
    s.updatedTime = updated
    s.done = true
    return s
}

@Suite struct HistoryTests {
    @Test func facesFollowTheScore() {
        #expect(Mood.emoji(percent: 100) == "😊")
        #expect(Mood.emoji(percent: 96) == "😊")
        #expect(Mood.emoji(percent: 88) == "🐕")
        #expect(Mood.emoji(percent: 72) == "🐶")
        #expect(Mood.emoji(percent: 0) == "🐶")
        #expect(Mood.level(percent: 59.9) == 0)
        #expect(Mood.level(percent: 85) == 3)
    }

    @Test func aRowReadsLikeTheWebApps() {
        let row = HistoryRow(level: "yellow", startTime: t0, correct: 24, answers: 25)
        #expect(row.summary == "24 / 25 (96%) 😊")
        #expect(row.date(in: TimeZone(identifier: "UTC")!) == "2026-10-30 22:40")
        #expect(row.date(in: TimeZone(identifier: "America/Mexico_City")!) == "2026-10-30 16:40")
    }

    @Test func rowsAreTheProfilesFiledSessionsNewestFirst() {
        var p = SavedProgress.fresh(now: t0)
        p.history["100"] = [
            "yellow": [session("yellow", start: t0, correct: 18, answers: 25, updated: t0 + 100),
                       session("yellow", start: t0 + 200, correct: 0, answers: 0, updated: t0 + 300)],
            "blue": [session("blue", start: t0 + 400, correct: 5, answers: 5, updated: t0 + 500)],
        ]
        p.history["101"] = ["yellow": [session("yellow", start: t0, correct: 1, answers: 1, updated: t0 + 900)]]
        let rows = p.historyRows
        #expect(rows.map(\.level) == ["blue", "yellow"])
        #expect(rows.map(\.answers) == [5, 25])
    }

    @Test func noHistoryNoRows() {
        #expect(SavedProgress.fresh(now: t0).historyRows.isEmpty)
    }
}
```

`SwiftApp/ElisaKit/Tests/ElisaKitTests/KeepAwakeTests.swift`:

```swift
import Testing
@testable import ElisaKit

@Suite struct KeepAwakeTests {
    @Test func onForFiveMinutesAfterTheLastPlayOrTap() {
        #expect(!KeepAwake.shouldKeepAwake(lastActivity: nil, now: 1000))
        #expect(KeepAwake.shouldKeepAwake(lastActivity: 1000, now: 1000))
        #expect(KeepAwake.shouldKeepAwake(lastActivity: 1000, now: 1299))
        #expect(!KeepAwake.shouldKeepAwake(lastActivity: 1000, now: 1300))
    }
}
```

`SwiftApp/ElisaKit/Tests/ElisaKitTests/GameEditTests.swift`:

```swift
import Testing
@testable import ElisaKit

@Suite struct GameEditTests {
    let clock = GameTestClock()

    private func game() -> Game {
        var game = Game(progress: .fresh(now: clock.now), forcedAnswer: "red",
                        random: { 0 }, now: { [clock] in clock.now })
        game.start()
        return game
    }

    @Test func anEditStartsANewUnplayedQuestion() {
        var g = game()
        _ = g.play()
        #expect(g.asked)
        g.editProgress { progress, _ in progress.profile.currentInstrument = Instrument.guitar.rawValue }
        #expect(g.instrument == .guitar)
        #expect(!g.asked)
        #expect(g.showsPlayHint)
    }

    @Test func theHintFollowsTheSetting() {
        var g = game()
        g.editProgress { progress, _ in progress.profile.enableOnboardingHints = false }
        #expect(!g.showsPlayHint)
    }

    @Test func aFailedEditChangesNothing() {
        var g = game()
        _ = g.play()
        do {
            try g.editProgress { progress, now in try progress.deleteProfile(id: 100, now: now) }
            Issue.record("the guest can't be deleted")
        } catch {}
        #expect(g.asked)
    }

    @Test func editsGetTheClock() throws {
        var g = game()
        clock.now += 50
        var seen = 0.0
        g.editProgress { _, now in seen = now }
        #expect(seen == clock.now)
    }
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `cd ~/c/bsharp/SwiftApp/ElisaKit && swift test 2>&1 | grep -E "error:" | head -3`
Expected: `cannot find 'Mood' in scope`, `cannot find 'KeepAwake' in scope`, `value of type 'Game' has no member 'editProgress'`.

- [ ] **Step 3: Write the code**

`SwiftApp/ElisaKit/Sources/ElisaKit/History.swift`:

```swift
import Foundation

/// The face for a score (stats.ts calculateNeutralLevel and getCatEmoji).
public enum Mood {
    public static func level(percent: Double) -> Int {
        min(max(0, Int(((percent - 50) / 10).rounded(.down))), 4)
    }

    public static func emoji(percent: Double) -> String {
        switch level(percent: percent) {
        case 4: "\u{1F60A}"
        case 3: "\u{1F415}"
        default: "\u{1F436}"
        }
    }
}

/// One line of the stats history panel.
public struct HistoryRow: Equatable, Sendable {
    /// The level's chord id, for its color.
    public let level: String
    public let startTime: Double
    public let correct: Int
    public let answers: Int

    public var percent: Double {
        answers == 0 ? 0 : 100 * Double(correct) / Double(answers)
    }

    /// "24 / 25 (96%) 😊"
    public var summary: String {
        "\(correct) / \(answers) (\(Int(percent.rounded()))%) \(Mood.emoji(percent: percent))"
    }

    /// "2026-10-30 11:35" (utils.ts formatDatetime), in `timeZone`.
    public func date(in timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute],
                                        from: Date(timeIntervalSince1970: startTime))
        return String(format: "%04d-%02d-%02d %02d:%02d",
                      c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0)
    }
}

extension SavedProgress {
    /// The current profile's filed sessions at every level, newest first, without empty ones
    /// (populateStatsHistoryModal). The session in progress isn't filed yet, so it isn't listed.
    public var historyRows: [HistoryRow] {
        (history[String(profile.id)] ?? [:]).values
            .flatMap { $0 }
            .filter { $0.identifications > 0 }
            .sorted { $0.updatedTime > $1.updatedTime }
            .map { HistoryRow(level: $0.currentChord, startTime: $0.startTime, correct: $0.correct,
                              answers: $0.identifications) }
    }
}
```

`SwiftApp/ElisaKit/Sources/ElisaKit/KeepAwake.swift`:

```swift
/// Whether the screen stays on (UIApplication.isIdleTimerDisabled): from a play or a tap until
/// five minutes after the last one, so a session never dims mid-chord but a forgotten iPad
/// still locks.
public enum KeepAwake {
    public static let window = 5.0 * 60

    public static func shouldKeepAwake(lastActivity: Double?, now: Double) -> Bool {
        guard let lastActivity else { return false }
        return now - lastActivity < window
    }
}
```

In `SwiftApp/ElisaKit/Sources/ElisaKit/Game.swift`, add after `changeLevel(to:)`:

```swift
    /// A change from the menu (profiles, settings, the instrument), given the clock. Then the
    /// game starts afresh, as after a level change: a new unplayed question, and the hint if
    /// the profile has it on. A change that throws leaves everything as it was.
    public mutating func editProgress(_ change: (inout SavedProgress, Double) throws -> Void) rethrows {
        var edited = progress
        try change(&edited, now())
        progress = edited
        newSession()
    }
```

- [ ] **Step 4: Run the tests**

Run: `cd ~/c/bsharp/SwiftApp/ElisaKit && swift test 2>&1 | tail -2`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/ElisaKit/Sources/ElisaKit/History.swift SwiftApp/ElisaKit/Sources/ElisaKit/KeepAwake.swift SwiftApp/ElisaKit/Sources/ElisaKit/Game.swift SwiftApp/ElisaKit/Tests/ElisaKitTests/HistoryTests.swift SwiftApp/ElisaKit/Tests/ElisaKitTests/KeepAwakeTests.swift SwiftApp/ElisaKit/Tests/ElisaKitTests/GameEditTests.swift
git commit -m "Add the history rows, the keep-awake rule and menu edits to the game"
```

---

### Task 4: GameModel actions for the menu

**Files:**
- Modify: `SwiftApp/App/GameModel.swift`

- [ ] **Step 1: Add the actions**

In `SwiftApp/App/GameModel.swift`:

(a) Replace `import Observation` with

```swift
import Observation
import UIKit
```

(b) Add these properties after `private var revealTask: Task<Void, Never>?`:

```swift
    /// Level 0 (red) in the level picker, unlocked by six quick taps on "rojo" in the info
    /// panel. Like the web app, only until the app quits.
    private(set) var redLevelUnlocked = false
    private var eggTaps = TapUnlock()
    private var lastActivity: Double?
    private var keepAwakeTask: Task<Void, Never>?
```

(c) In `play()`, add `noteActivity()` as its last line. In `tap(_:)`, add `noteActivity()` right after `guard outcome != .ignored else { return }`. In `becameActive()`, add `updateKeepAwake()` as its last line.

(d) Add these methods before `importProgress(_:)`:

```swift
    /// A flag in the piano trainer: it sounds and counts for nothing.
    func playTrainer(_ color: String) {
        player.play(color)
        noteActivity()
    }

    func changeLevel(_ level: String) {
        revealTask?.cancel()
        game.changeLevel(to: level)
        save()
        DevLog.event("menu.level", ["level": game.level])
    }

    func changeInstrument(_ instrument: Instrument) {
        edit("instrument") { progress, _ in progress.profile.currentInstrument = instrument.rawValue }
    }

    func switchProfile(_ id: Int) {
        edit("switch-profile") { $0.switchProfile(to: id, now: $1) }
    }

    func addProfile(_ settings: ProfileSettings) throws {
        try edit("add-profile") { _ = try $0.addProfile(settings, now: $1) }
    }

    func updateProfile(_ settings: ProfileSettings) throws {
        try edit("update-profile") { progress, _ in try progress.updateProfile(settings) }
    }

    /// Deletes the profile playing now and goes back to the guest.
    func deleteProfile() throws {
        let id = game.profile.id
        try edit("delete-profile") { try $0.deleteProfile(id: id, now: $1) }
    }

    func easterEggTap() {
        if eggTaps.tap(at: Date().timeIntervalSince1970) {
            redLevelUnlocked = true
        }
    }
```

(e) Add these private methods before `save()`:

```swift
    /// A menu change: ends any reveal, applies it, reloads the instrument (a profile's may be
    /// another) and saves.
    private func edit(_ name: String, _ change: (inout SavedProgress, Double) throws -> Void) rethrows {
        revealTask?.cancel()
        try game.editProgress(change)
        player.load(game.instrument)
        save()
        DevLog.event("menu.\(name)", ["profile": "\(game.profile.id)", "level": game.level,
                                      "instrument": game.instrument.rawValue])
    }

    /// The screen stays on until five minutes after the last play or tap.
    private func noteActivity() {
        lastActivity = Date().timeIntervalSince1970
        updateKeepAwake()
        keepAwakeTask?.cancel()
        keepAwakeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(KeepAwake.window + 1))
            guard !Task.isCancelled else { return }
            self?.updateKeepAwake()
        }
    }

    private func updateKeepAwake() {
        UIApplication.shared.isIdleTimerDisabled =
            KeepAwake.shouldKeepAwake(lastActivity: lastActivity, now: Date().timeIntervalSince1970)
    }
```

- [ ] **Step 2: Build**

Run the app build (Conventions). Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/App/GameModel.swift
git commit -m "Add the menu actions and the keep-awake timer to the game model"
```

---

### Task 5: The shared pieces: pill buttons, the panel card, sizes and the active color

**Files:**
- Create: `SwiftApp/App/PillButton.swift`, `SwiftApp/App/PanelCard.swift`
- Modify: `SwiftApp/App/Theme.swift`, `SwiftApp/App/Metrics.swift`

- [ ] **Step 1: Write them**

In `SwiftApp/App/Theme.swift`, add after `static let correctGreen = …`:

```swift
    /// The menu item for what is on screen, and the current profile's ring (#0077be).
    static let active = Color(hex: 0x0077BE)
```

In `SwiftApp/App/Metrics.swift`, add after `var flagGap`:

```swift
    /// div.hamburger a: clamp(40px, 10vmin, 56px) across, its gear clamp(24px, 6vmin, 3rem).
    var gearSize: CGFloat { clamp(10 * vmin, 40, 56) }
    var gearIconSize: CGFloat { clamp(6 * vmin, 24, 48) }
    /// The five menu icons and the gaps between them (about 25 pt and 33 pt on the iPad mini).
    var menuIconSize: CGFloat { clamp(3.4 * vmin, 20, 30) }
    var menuSpacing: CGFloat { clamp(4.5 * vmin, 14, 44) }
```

`SwiftApp/App/PillButton.swift`:

```swift
import SwiftUI

/// The web app's pill buttons (.button): Hello Headline, white on ink, darker while pressed.
struct PillButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.headline(20))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Capsule().fill(configuration.isPressed ? Theme.inkPressed : Theme.ink))
            .opacity(isEnabled ? 1 : 0.4)
    }
}
```

`SwiftApp/App/PanelCard.swift`:

```swift
import SwiftUI

/// A white card with a pale-blue ring (#panel-area > .panel), in place of the flags and the
/// play button while a panel is open.
struct PanelCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .foregroundStyle(Theme.ink)
            .background(RoundedRectangle(cornerRadius: 28).fill(.white))
            // box-shadow: 0 0 0 6px $bluey-edge
            .background(RoundedRectangle(cornerRadius: 34).fill(Theme.edge).padding(-6))
    }
}
```

- [ ] **Step 2: Build**

Run the app build. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/App/PillButton.swift SwiftApp/App/PanelCard.swift SwiftApp/App/Theme.swift SwiftApp/App/Metrics.swift
git commit -m "Add the pill buttons, the panel card and the menu sizes"
```

---

### Task 6: The info, trainer and history panels

**Files:**
- Create: `SwiftApp/App/InfoPanel.swift`, `SwiftApp/App/TrainerPanel.swift`, `SwiftApp/App/HistoryPanel.swift`

- [ ] **Step 1: Write the three views**

`SwiftApp/App/InfoPanel.swift`:

```swift
import SwiftUI

/// What the method is and how to practise (#i-infobox). The links open in Safari; six quick
/// taps on "rojo" unlock level 0 in the level picker.
struct InfoPanel: View {
    let onRojo: () -> Void

    private static let paragraphs = [
        "Esta app usa el [método de identificación de acordes de Eguchi](https://www.ganbar.us/documents/sakakibara_2012_chord_identification.pdf). Ver también [Ichionkai Music School](https://ichionkai.co.jp/english3.html).",
        "[Video corto (en inglés) de cómo se usa](https://youtu.be/kNfkm6PQC20).",
        "Es un método para enseñar oído absoluto a niños de 2 a 6 años. Practiquen unas 5 veces al día, 2–3 minutos cada vez (unas 20–25 respuestas). Los acordes siempre se identifican con colores, en este orden: [rojo](elisa://rojo) (Do Mi Sol), amarillo (Do Fa La), azul (Si Re Sol), negro (La Do Fa), verde (Re Sol Si), naranja (Mi Sol Do), morado (Fa La Do), rosa (Sol Si Re), café (Sol Do Mi).",
        "Presenten los acordes uno por uno, con al menos 2 semanas entre cada acorde nuevo. No agreguen un acorde nuevo hasta que identifique todos los actuales con 100% de aciertos.",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ForEach(Self.paragraphs, id: \.self) { paragraph in
                    Text((try? AttributedString(markdown: paragraph)) ?? AttributedString(paragraph))
                }
            }
            .font(Theme.text(20))
            .lineSpacing(8)
            // Links look like the rest of the text, as on bluey.chiq.me.
            .tint(Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == "elisa" else { return .systemAction }
            onRojo()
            return .handled
        })
        .accessibilityIdentifier("info-panel")
    }
}

#Preview { PanelCard { InfoPanel(onRojo: {}) }.padding() }
```

`SwiftApp/App/TrainerPanel.swift`:

```swift
import ElisaKit
import SwiftUI

/// Every chord's flag, to hear any of them without it counting (#trainer-infobox): three per
/// row (five when wider than tall), the last row spread out, all fitting without a scroll.
struct TrainerPanel: View {
    let landscape: Bool
    let onTap: (String) -> Void

    var body: some View {
        GeometryReader { geo in
            let columns = landscape ? 5 : 3
            let rows = stride(from: 0, to: Chords.all.count, by: columns).map {
                Array(Chords.all[$0..<min($0 + columns, Chords.all.count)])
            }
            let gap: CGFloat = 16
            let width = (geo.size.width - gap * CGFloat(columns)) / CGFloat(columns)
            let height = min(width * 0.8,
                             (geo.size.height - gap * CGFloat(rows.count - 1)) / CGFloat(rows.count))
            VStack(spacing: gap) {
                ForEach(rows.indices, id: \.self) { row in
                    // Half a gap either side of each flag: full rows fill the width, the last
                    // row spreads out (justify-content: space-around).
                    HStack(spacing: 0) {
                        ForEach(rows[row]) { chord in
                            Spacer(minLength: gap / 2)
                            Button { onTap(chord.id) } label: {
                                Rectangle()
                                    .fill(Color(hex: chord.hex))
                                    .overlay(Rectangle().strokeBorder(.black, lineWidth: 2))
                            }
                            .buttonStyle(FlagButtonStyle())
                            .frame(width: width, height: height)
                            .accessibilityIdentifier("trainer-\(chord.id)")
                            Spacer(minLength: gap / 2)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

#Preview { PanelCard { TrainerPanel(landscape: false, onTap: { _ in }) }.padding() }
```

`SwiftApp/App/HistoryPanel.swift`:

```swift
import ElisaKit
import SwiftUI

/// The current profile's past sessions, newest first (#stats-history-container).
struct HistoryPanel: View {
    let rows: [HistoryRow]

    var body: some View {
        if rows.isEmpty {
            Text("Todavía no hay sesiones.")
                .font(Theme.text(18))
                .accessibilityIdentifier("history-empty")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 12) {
                            Rectangle()
                                .fill(Color(hex: Chords.chord(row.level)?.hex ?? 0xFFFFFF))
                                .overlay(Rectangle().strokeBorder(.black, lineWidth: 1))
                                .frame(width: 36, height: 36)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(row.date()).font(Theme.text(16))
                                Text(row.summary).font(Theme.text(20, bold: true))
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("history-row")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#Preview {
    PanelCard {
        HistoryPanel(rows: [HistoryRow(level: "yellow", startTime: 1_793_400_000, correct: 24, answers: 25)])
    }
    .padding()
}
```

- [ ] **Step 2: Build**

Run the app build. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/App/InfoPanel.swift SwiftApp/App/TrainerPanel.swift SwiftApp/App/HistoryPanel.swift
git commit -m "Add the info, piano trainer and history panels"
```

---

### Task 7: The profile panel and the Guided Access sheet

**Files:**
- Create: `SwiftApp/App/ProfilePanel.swift`, `SwiftApp/App/GuidedAccessInfo.swift`

- [ ] **Step 1: Write the Guided Access sheet**

`SwiftApp/App/GuidedAccessInfo.swift`:

```swift
import SwiftUI
import UIKit

/// How to lock the iPad to this app (the web app's screen-pinning modal), behind
/// "Fijar pantalla". An app can't start Guided Access itself on an unmanaged iPad.
struct GuidedAccessInfo: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if UIAccessibility.isGuidedAccessEnabled {
                    Text("**Acceso guiado está activo ahora.**")
                }
                Text("**Acceso guiado** deja el iPad fijo en esta app para que Elisa no pueda salirse.")
                    .accessibilityIdentifier("guided-access-info")
                Text("**Actívalo:**")
                Text("1. Abre **Ajustes > Accesibilidad > Acceso guiado** y actívalo.\n2. En **Ajustes de código**, define un código.")
                Text("**Úsalo:**")
                Text("1. Abre la app y presiona tres veces el botón superior.\n2. Toca **Iniciar**.")
                Text("**Para salir:** presiona tres veces el botón superior e ingresa el código.")
                HStack {
                    Spacer()
                    Button("OK") { dismiss() }
                        .buttonStyle(PillButtonStyle())
                        .accessibilityIdentifier("guided-access-ok")
                    Spacer()
                }
                .padding(.top, 8)
            }
            .font(Theme.text(18))
            .foregroundStyle(Theme.ink)
            .padding(28)
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview { Text("").sheet(isPresented: .constant(true)) { GuidedAccessInfo() } }
```

- [ ] **Step 2: Write the profile panel**

`SwiftApp/App/ProfilePanel.swift`:

```swift
import ElisaKit
import SwiftUI

/// Profiles and settings (#profile-info-container): the switcher, then the form. Level and
/// instrument apply at once, as the web app's selectors do; the rest waits for Guardar (or
/// Agregar perfil in add mode), which closes the panel.
struct ProfilePanel: View {
    let model: GameModel
    let onClose: () -> Void

    @State private var adding = false
    @State private var draft = ProfileSettings.blank
    @State private var failure: String?
    @State private var confirmingDelete = false
    @State private var showingGuidedAccess = false

    private var profile: Profile { model.game.profile }
    private var isGuest: Bool { profile.id == Defaults.guestProfileID }

    static let showChordModes = [("always", "Siempre"), ("black_only", "Solo acordes negros"), ("never", "Nunca")]
    static let revealChordModes = [("always", "Siempre"), ("after_guess", "Después de adivinar")]
    static let chordDisplayModes = [("shapes_and_letters", "Figuras y letras"), ("shapes_only", "Solo figuras"),
                                    ("letters_only", "Solo letras")]
    static let selectionModes = [("random", "Al azar"), ("adaptive", "Adaptativa")]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                switcher
                Divider().overlay(Color(white: 0.33))
                row("Nivel:") { levelPicker }
                row("Instrumento:") { instrumentPicker }
                row("Nombre:") {
                    TextField("", text: $draft.name)
                        .textFieldStyle(.roundedBorder)
                        .font(Theme.text(18))
                        .frame(maxWidth: 260)
                        .disabled(isGuest && !adding)
                        .accessibilityIdentifier("profile-name")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ícono:")
                    iconPicker
                }
                row("Mostrar notas del acorde:") { picker($draft.showChordMode, Self.showChordModes, id: "profile-show-chord") }
                row("Mostrar notas:") { picker($draft.revealChordMode, Self.revealChordModes, id: "profile-reveal") }
                row("Formato de notas:") { picker($draft.chordDisplayMode, Self.chordDisplayModes, id: "profile-display") }
                row("Mantener carita:") { Toggle("", isOn: $draft.persistReactionFace).labelsHidden() }
                row("Mostrar ayudas:") {
                    Toggle("", isOn: $draft.enableOnboardingHints).labelsHidden()
                        .accessibilityIdentifier("profile-hints")
                }
                row("Meta por sesión:") {
                    TextField("", text: $draft.targetNumber)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .font(Theme.text(18))
                        .frame(maxWidth: 120)
                        .accessibilityIdentifier("profile-target")
                }
                row("Elección de acordes:") { picker($draft.chordSelectionMode, Self.selectionModes, id: "profile-selection") }
                row("Fijar pantalla:") {
                    Button { showingGuidedAccess = true } label: { Label("Info", systemImage: "pin.fill") }
                        .buttonStyle(PillButtonStyle())
                        .accessibilityIdentifier("profile-guided-access")
                }
                buttons
            }
            .font(Theme.text(22))
            .foregroundStyle(Theme.ink)
            .tint(Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { draft = ProfileSettings(profile: profile) }
        .alert("No se pudo guardar",
               isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
        .alert("¿Seguro que quieres borrar el perfil \(profile.name)?", isPresented: $confirmingDelete) {
            Button("Borrar", role: .destructive) { run { try model.deleteProfile(); onClose() } }
            Button("Cancelar", role: .cancel) {}
        }
        .sheet(isPresented: $showingGuidedAccess) { GuidedAccessInfo() }
    }

    // MARK: Switcher

    private var switcher: some View {
        HStack(spacing: 8) {
            ForEach(model.game.progress.switcherProfiles, id: \.id) { other in
                Button {
                    adding = false
                    model.switchProfile(other.id)
                    draft = ProfileSettings(profile: model.game.profile)
                } label: {
                    switcherCircle(ProfileIcons.symbol(for: other.icon), active: !adding && other.id == profile.id,
                                   dashed: false)
                }
                .accessibilityIdentifier("switcher-\(other.id)")
                .accessibilityLabel(other.name)
            }
            Button {
                adding = true
                draft = .blank
            } label: {
                switcherCircle("plus", active: adding, dashed: true)
            }
            .accessibilityIdentifier("profile-add")
        }
    }

    private func switcherCircle(_ symbol: String, active: Bool, dashed: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(Theme.noteInk)
            .frame(width: 40, height: 40)
            .background(Circle().fill(active ? Color(white: 0.88) : .clear))
            .overlay(
                Circle().strokeBorder(active ? Theme.active : (dashed ? Color(white: 0.53) : .clear),
                                      style: StrokeStyle(lineWidth: 2, dash: dashed && !active ? [4, 3] : []))
            )
    }

    // MARK: Fields

    private func row<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        // Label and field side by side when they fit, the field under the label on a phone.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { Text(label); content() }
            VStack(alignment: .leading, spacing: 8) { Text(label); content() }
        }
    }

    private var levelPicker: some View {
        Picker("Nivel", selection: Binding(get: { model.game.level }, set: { model.changeLevel($0) })) {
            Section("Acordes blancos") {
                ForEach(LevelOptions.white(includingRed: model.redLevelUnlocked || model.game.level == "red")) {
                    Text($0.label).tag($0.id)
                }
            }
            Section("Acordes negros") {
                ForEach(LevelOptions.black) { Text($0.label).tag($0.id) }
            }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("profile-level")
    }

    private var instrumentPicker: some View {
        Picker("Instrumento", selection: Binding(get: { model.game.instrument },
                                                 set: { model.changeInstrument($0) })) {
            ForEach(Instrument.allCases, id: \.self) { Text($0.spanishName).tag($0) }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("profile-instrument")
    }

    private func picker(_ selection: Binding<String>, _ options: [(String, String)], id: String) -> some View {
        Picker("", selection: selection) {
            ForEach(options, id: \.0) { Text($0.1).tag($0.0) }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .accessibilityIdentifier(id)
    }

    /// The icons as round buttons (the web app's radio buttons, too small for a finger).
    private var iconPicker: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(ProfileIcons.all, id: \.self) { icon in
                Button { draft.icon = icon } label: {
                    Image(systemName: ProfileIcons.symbol(for: icon))
                        .font(.system(size: 24))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(draft.icon == icon ? Theme.edge : .clear))
                }
                .accessibilityIdentifier("icon-\(icon)")
                .accessibilityValue(draft.icon == icon ? "selected" : "")
            }
        }
    }

    // MARK: Buttons

    private var buttons: some View {
        HStack {
            if adding {
                Spacer()
                Button("Agregar perfil") { run { try model.addProfile(draft); onClose() } }
                    .accessibilityIdentifier("profile-submit-add")
                Spacer()
            } else {
                Button("Borrar perfil") { confirmingDelete = true }
                    .disabled(isGuest)
                    .accessibilityIdentifier("profile-delete")
                Spacer()
                Button("Guardar") { run { try model.updateProfile(draft); onClose() } }
                    .accessibilityIdentifier("profile-save")
            }
        }
        .buttonStyle(PillButtonStyle())
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func run(_ action: () throws -> Void) {
        do {
            try action()
        } catch let error as ProfileError {
            failure = error.message
        } catch {
            failure = error.localizedDescription
        }
    }
}

#Preview {
    PanelCard { ProfilePanel(model: GameModel(options: LaunchOptions(freshState: true)), onClose: {}) }.padding()
}
```

- [ ] **Step 3: Build**

Run the app build. Expected: `** BUILD SUCCEEDED **`. If the compiler complains that the tuple arrays aren't `Sendable` (`static let` in a `View`), mark them `nonisolated(unsafe) static let`; they are never mutated.

- [ ] **Step 4: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/App/ProfilePanel.swift SwiftApp/App/GuidedAccessInfo.swift
git commit -m "Add the profile panel and the Guided Access instructions"
```

---

### Task 8: The gear, the menu and panels on the home screen

**Files:**
- Create: `SwiftApp/App/MenuBar.swift`
- Modify: `SwiftApp/App/HomeView.swift`

- [ ] **Step 1: Write the menu bar**

`SwiftApp/App/MenuBar.swift`:

```swift
import ElisaKit
import SwiftUI

/// The panels the menu opens. Nil is home: the game.
enum Panel: String {
    case trainer, info, history, profile
}

/// The gear and, once it is tapped, the five items beside it (div.menu-container): home, the
/// piano trainer, the info text, the stats history and the profile. The one showing is blue.
/// Hiding the items also closes the panel, so the game is never left behind one.
struct MenuBar: View {
    @Binding var open: Bool
    @Binding var panel: Panel?
    let profile: Profile
    let metrics: Metrics

    var body: some View {
        HStack(spacing: 12) {
            if open {
                HStack(spacing: metrics.menuSpacing) {
                    item("menu-home", "house.fill", active: panel == nil) { panel = nil }
                    item("menu-trainer", "music.note", active: panel == .trainer) { toggle(.trainer) }
                    item("menu-info", "info.circle.fill", active: panel == .info) { toggle(.info) }
                    item("menu-history", "chart.line.uptrend.xyaxis", active: panel == .history) { toggle(.history) }
                    Button { toggle(.profile) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: ProfileIcons.symbol(for: profile.icon))
                            Text(profile.name).font(Theme.text(metrics.menuIconSize * 1.1))
                        }
                        .foregroundStyle(panel == .profile ? Theme.active : Theme.ink)
                    }
                    .accessibilityIdentifier("menu-profile")
                    .accessibilityValue(panel == .profile ? "active" : "")
                }
                .font(.system(size: metrics.menuIconSize, weight: .semibold))
                .frame(maxWidth: .infinity)
                .transition(.opacity)
            } else {
                Spacer(minLength: 0)
            }
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    open.toggle()
                    if !open { panel = nil }
                }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: metrics.gearIconSize, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: metrics.gearSize, height: metrics.gearSize)
                    .background(Circle().fill(.white).shadow(color: .black.opacity(0.15), radius: 5, y: 4))
            }
            .accessibilityIdentifier("menu-gear")
        }
    }

    private func toggle(_ target: Panel) {
        panel = panel == target ? nil : target
    }

    private func item(_ id: String, _ symbol: String, active: Bool,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).foregroundStyle(active ? Theme.active : Theme.ink)
        }
        .accessibilityIdentifier(id)
        .accessibilityValue(active ? "active" : "")
    }
}
```

- [ ] **Step 2: Put it on the home screen**

In `SwiftApp/App/HomeView.swift`:

(a) Update the doc comment above `struct HomeView` to:

```swift
/// The main screen: the gear menu at the top, then either the game (flags, the play hint and
/// the play button) or the open panel. Six quick taps on the empty part of the top bar open
/// the parent-only progress import.
```

(b) Add after `@State private var importError: String?`:

```swift
    @State private var menuOpen = false
    @State private var panel: Panel?
```

(c) Replace the whole `VStack(spacing: 0) { … }` block inside `GeometryReader` (from `VStack(spacing: 0) {` down to and including `.padding(.bottom, 10)` that follows `.padding(.horizontal, 10)`) with:

```swift
            VStack(spacing: 0) {
                topBar(metrics)
                    .padding(.bottom, metrics.controlsGap)
                if let panel {
                    PanelCard { panelView(panel, metrics) }
                        .padding(.horizontal, 6)
                        .padding(.bottom, 6)
                } else {
                    FlagGrid(chords: model.game.chords, landscape: metrics.landscape, gap: metrics.flagGap,
                             marked: model.game.marked, dimmed: model.game.awaitingPlay,
                             noteStyle: model.game.noteStyle, onTap: { model.tap($0) })
                        .padding(.bottom, metrics.controlsGap)
                    if model.game.showsPlayHint {
                        PlayHint(buttonSize: metrics.buttonSize, arrowSize: metrics.arrowSize)
                    }
                    ControlsBar(buttonSize: metrics.buttonSize, iconSize: metrics.iconSize,
                                onPlay: { model.play() })
                        .padding(.bottom, 6)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
```

(d) In the `.overlay(alignment: .bottomTrailing)` right after it, wrap the reveal so it only shows with the game:

```swift
            .overlay(alignment: .bottomTrailing) {
                if panel == nil {
                    reveal(metrics)
                        .padding(.bottom, 10)
                        .padding(.trailing, metrics.revealTrailing)
                }
            }
```

(e) Add these two methods after `reveal(_:)`:

```swift
    /// The gear menu over a clear strip; six quick taps on the strip open the progress import.
    private func topBar(_ metrics: Metrics) -> some View {
        MenuBar(open: $menuOpen, panel: $panel, profile: model.game.profile, metrics: metrics)
            .padding(.top, 6)
            .frame(minHeight: 44)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if unlock.tap(at: Date().timeIntervalSince1970) { choosingFile = true }
                    }
                    .accessibilityIdentifier("import-strip")
            }
    }

    @ViewBuilder
    private func panelView(_ panel: Panel, _ metrics: Metrics) -> some View {
        switch panel {
        case .trainer: TrainerPanel(landscape: metrics.landscape, onTap: { model.playTrainer($0) })
        case .info: InfoPanel(onRojo: { model.easterEggTap() })
        case .history: HistoryPanel(rows: model.game.progress.historyRows)
        case .profile: ProfilePanel(model: model, onClose: { self.panel = nil })
        }
    }
```

(f) `Metrics.revealTrailing`'s comment mentions room for the gear; the gear is now in the top bar, so change its doc comment to `/// right: portrait 0.75rem, landscape 6.5rem` and leave the values.

- [ ] **Step 3: Build and try it**

Run the app build. Expected: `** BUILD SUCCEEDED **`. Then run the existing UI tests (Conventions, iPad) to be sure the game flows still pass: `** TEST SUCCEEDED **`. The top strip is now taller than 44 pt on the iPad; the import gesture still works on its empty part.

- [ ] **Step 4: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/App/MenuBar.swift SwiftApp/App/HomeView.swift SwiftApp/App/Metrics.swift
git commit -m "Add the gear menu and show its panels in place of the game"
```

---

### Task 9: iPad polish: system overlays and edge gestures

The keep-awake timer is already in `GameModel` (Task 4). This task hides the status bar and the home indicator and defers edge swipes, so a child's swipe from an edge doesn't leave the app or pull down Control Center on the first try.

**Files:**
- Modify: `SwiftApp/App/ElisaMusicaApp.swift`

- [ ] **Step 1: Add the modifiers**

In `SwiftApp/App/ElisaMusicaApp.swift`, replace

```swift
        WindowGroup {
            HomeView(model: model)
        }
```

with

```swift
        WindowGroup {
            HomeView(model: model)
                // Like an app in Guided Access: nothing at the edges to tap or drag by accident.
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
                .defersSystemGestures(on: .all)
        }
```

- [ ] **Step 2: Build and run the UI tests**

Run the app build, then the UI tests on the iPad (Conventions). Expected: `** BUILD SUCCEEDED **` and `** TEST SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/App/ElisaMusicaApp.swift
git commit -m "Hide the status bar and home indicator and defer edge swipes"
```

---

### Task 10: UI tests for the menu

**Files:**
- Create: `SwiftApp/UITests/MenuUITests.swift`

- [ ] **Step 1: Write the tests**

`SwiftApp/UITests/MenuUITests.swift`:

```swift
import XCTest

/// The gear menu and its panels, on a throwaway progress file with red always the answer.
final class MenuUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ElisaFreshState", "YES", "-ElisaAnswer", "red"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["menu-gear"].waitForExistence(timeout: 10))
        return app
    }

    /// Taps a menu item, opening the menu first if needed.
    private func open(_ app: XCUIApplication, _ item: String) {
        if !app.buttons["menu-home"].exists { app.buttons["menu-gear"].tap() }
        app.buttons[item].tap()
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// Picks an option of a menu-style picker.
    private func choose(_ app: XCUIApplication, _ picker: String, _ option: String) {
        app.buttons[picker].tap()
        XCTAssertTrue(app.buttons[option].waitForExistence(timeout: 2), "no option \(option)")
        app.buttons[option].tap()
    }

    private func waitGone(_ element: XCUIElement) {
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        waitForExpectations(timeout: 5)
    }

    func testTheGearOpensTheMenuAndHomeGoesBackToTheGame() {
        let app = launch()
        XCTAssertFalse(app.buttons["menu-home"].exists)
        app.buttons["menu-gear"].tap()
        XCTAssertEqual(app.buttons["menu-home"].value as? String, "active")

        app.buttons["menu-info"].tap()
        XCTAssertTrue(element(app, "info-panel").exists)
        XCTAssertEqual(app.buttons["menu-info"].value as? String, "active")
        XCTAssertFalse(app.buttons["flag-red"].exists)
        XCTAssertFalse(app.buttons["play-button"].exists)

        app.buttons["menu-home"].tap()
        XCTAssertTrue(app.buttons["flag-red"].exists)

        app.buttons["menu-info"].tap()
        app.buttons["menu-gear"].tap()
        XCTAssertFalse(app.buttons["menu-home"].exists)
        XCTAssertTrue(app.buttons["flag-red"].exists, "hiding the menu closes the panel")
    }

    func testTheTrainerHasEveryChordAndCountsNothing() {
        let app = launch(["-ElisaStreak", "3"])
        open(app, "menu-trainer")
        let flags = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'trainer-'"))
        XCTAssertEqual(flags.count, 14)
        app.buttons["trainer-blue"].tap()
        app.buttons["trainer-red"].tap()
        open(app, "menu-home")
        XCTAssertEqual(element(app, "streak-outline").value as? String, "3")
    }

    func testChangingTheLevelShowsItsFlags() {
        let app = launch()
        open(app, "menu-profile")
        choose(app, "profile-level", "Nivel 2: Azul (Si Re Sol)")
        open(app, "menu-home")
        XCTAssertTrue(app.buttons["flag-blue"].exists)
    }

    func testTheHistoryListsASessionOnceItIsFiled() {
        let app = launch()
        open(app, "menu-history")
        XCTAssertTrue(element(app, "history-empty").exists)

        open(app, "menu-home")
        app.buttons["play-button"].tap()
        app.buttons["flag-red"].tap()
        // A level change files the session at yellow.
        open(app, "menu-profile")
        choose(app, "profile-level", "Nivel 2: Azul (Si Re Sol)")
        open(app, "menu-history")
        let row = element(app, "history-row")
        XCTAssertTrue(row.waitForExistence(timeout: 2))
        XCTAssertTrue(row.label.contains("1 / 1 (100%)"), row.label)
    }

    func testAddingAProfilePlaysAsItAndDeletingGoesBackToElisa() {
        let app = launch()
        open(app, "menu-profile")
        XCTAssertFalse(app.buttons["profile-delete"].isEnabled, "the guest can't be deleted")

        app.buttons["profile-add"].tap()
        let name = app.textFields["profile-name"]
        name.tap()
        name.typeText("Papa\n")
        app.buttons["icon-fa-truck"].tap()
        app.buttons["profile-submit-add"].tap()
        XCTAssertTrue(app.buttons["flag-red"].waitForExistence(timeout: 3), "adding closes the panel")
        XCTAssertTrue(app.buttons["menu-profile"].label.contains("Papa"), app.buttons["menu-profile"].label)

        open(app, "menu-profile")
        XCTAssertTrue(app.buttons["switcher-101"].exists)
        XCTAssertTrue(app.buttons["profile-delete"].isEnabled)
        app.buttons["profile-delete"].tap()
        app.alerts.buttons["Borrar"].tap()
        XCTAssertTrue(app.buttons["flag-red"].waitForExistence(timeout: 3), "deleting closes the panel")
        XCTAssertTrue(app.buttons["menu-profile"].label.contains("Elisa"), app.buttons["menu-profile"].label)
    }

    func testANameThatIsTakenIsRefused() {
        let app = launch()
        open(app, "menu-profile")
        app.buttons["profile-add"].tap()
        let name = app.textFields["profile-name"]
        name.tap()
        name.typeText("elisa\n")
        app.buttons["profile-submit-add"].tap()
        XCTAssertTrue(app.alerts.staticTexts["Ya existe un perfil llamado elisa."].waitForExistence(timeout: 2))
        app.alerts.buttons["OK"].tap()
    }

    func testSavingTurnsTheHintOff() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["play-hint"].exists)
        open(app, "menu-profile")
        // On recent iOS the Toggle's tappable part is a switch inside the identified one.
        let toggle = app.switches["profile-hints"]
        let inner = toggle.switches.firstMatch
        (inner.exists ? inner : toggle).tap()
        app.buttons["profile-save"].tap()
        XCTAssertTrue(app.buttons["flag-red"].waitForExistence(timeout: 3), "saving closes the panel")
        XCTAssertFalse(app.staticTexts["play-hint"].exists)
    }

    func testTheGuidedAccessInstructions() {
        let app = launch()
        open(app, "menu-profile")
        app.buttons["profile-guided-access"].tap()
        let info = element(app, "guided-access-info")
        XCTAssertTrue(info.waitForExistence(timeout: 3))
        app.buttons["guided-access-ok"].tap()
        waitGone(info)
    }
}
```

- [ ] **Step 2: Run them on both simulators**

```bash
cd ~/c/bsharp/SwiftApp
xcodegen generate
for dev in "iPad mini (A17 Pro)" "iPhone 16e"; do
  xcodebuild test -project ElisaMusica.xcodeproj -scheme ElisaMusica -destination "platform=iOS Simulator,name=$dev" \
    -derivedDataPath build/dd -only-testing:ElisaMusicaUITests/MenuUITests 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)" | tail -5
done
xcrun simctl shutdown all
```

Expected: `** TEST SUCCEEDED **` twice.

If a test fails, find out from the failure whether the app or the test is wrong before changing either. Known XCUITest quirks to check first: a `Toggle`'s tappable part may be an inner switch (handled as written); an option of a menu `Picker` shows up as a button named by its label; an element below the fold of a `ScrollView` may need `app.swipeUp()` before `tap()` on the iPhone. Fix the app when it doesn't behave as "Behavior being ported" says.

- [ ] **Step 3: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/UITests/MenuUITests.swift
git status --short SwiftApp
git commit -m "Test the gear menu, the panels and the profile flows"
```

Also add any app fixes from Step 2 to this commit, by explicit path.

---

### Task 11: Compare with the web app, screen by screen

**Files:**
- Modify: `SwiftApp/UITests/ScreenshotTests.swift`

- [ ] **Step 1: Add the captures**

In `SwiftApp/UITests/ScreenshotTests.swift`, add before the class's final `}`:

```swift
    func testMenus() {
        let orientations: [(String, UIDeviceOrientation)] = UIDevice.current.userInterfaceIdiom == .pad
            ? [("portrait", .portrait), ("landscape", .landscapeLeft)]
            : [("portrait", .portrait)]
        for (name, orientation) in orientations {
            self.orientation = orientation
            XCUIDevice.shared.orientation = orientation
            let app = launch(["-ElisaAnswer", "red"])
            _ = app.buttons["menu-gear"].waitForExistence(timeout: 10)
            // One filed session for the history: answer at yellow, then move to blue.
            app.buttons["play-button"].tap()
            app.buttons["flag-red"].tap()
            app.buttons["menu-gear"].tap()
            app.buttons["menu-profile"].tap()
            app.buttons["profile-level"].tap()
            app.buttons["Nivel 2: Azul (Si Re Sol)"].tap()
            app.buttons["menu-home"].tap()
            keep(app, "menu-01-gear-open-\(name)")
            app.buttons["menu-trainer"].tap()
            keep(app, "menu-02-piano-trainer-\(name)")
            app.buttons["menu-info"].tap()
            keep(app, "menu-03-info-\(name)")
            app.buttons["menu-history"].tap()
            keep(app, "menu-04-stats-history-\(name)")
            app.buttons["menu-profile"].tap()
            keep(app, "menu-05-profile-settings-\(name)")
            app.swipeUp()
            keep(app, "menu-06-profile-settings-scrolled-\(name)")
            app.buttons["profile-guided-access"].tap()
            keep(app, "menu-07-guided-access-\(name)")
        }
        XCUIDevice.shared.orientation = .portrait
    }
```

- [ ] **Step 2: Take the screenshots on both simulators**

```bash
cd ~/c/bsharp/SwiftApp
xcodegen generate
for dev in "iPad mini (A17 Pro)" "iPhone 16e"; do
  tag=${dev//[^A-Za-z0-9]/}
  rm -rf "build/menu-$tag.xcresult" "build/menu-$tag"
  TEST_RUNNER_ELISA_SCREENSHOTS=1 xcodebuild test -project ElisaMusica.xcodeproj -scheme ElisaMusica \
    -destination "platform=iOS Simulator,name=$dev" -derivedDataPath build/dd \
    -only-testing:ElisaMusicaUITests/ScreenshotTests/testMenus \
    -only-testing:ElisaMusicaUITests/ScreenshotTests/testAnswerStates \
    -resultBundlePath "build/menu-$tag.xcresult" 2>&1 | tail -1
  xcrun xcresulttool export attachments --path "build/menu-$tag.xcresult" --output-path "build/menu-$tag"
done
command ls build/menu-*/
```

Expected: `** TEST SUCCEEDED **` twice; each folder holds PNGs and a `manifest.json` that maps each file to its attachment name (`suggestedHumanReadableName`).

- [ ] **Step 3: Compare each one with its reference, with the Read tool**

| This app's screenshot | Reference in `Reference Material/screenshots/` |
|---|---|
| `menu-01-gear-open-*` | `menu-01-gear-open.png` |
| `menu-02-piano-trainer-*` | `menu-02-piano-trainer.png` |
| `menu-03-info-*` | `menu-03-info.png` |
| `menu-04-stats-history-*` | `menu-04-stats-history.png` |
| `menu-05-profile-settings-*` | `menu-05-profile-settings.png` |
| `menu-06-profile-settings-scrolled-*` | `menu-06-profile-settings-scrolled.png` |

Check, for each pair:
- **menu-01:** the gear is a white circle at the top right with an ink gear; the five items sit to its left on one line, home in blue, the others ink, the profile with its paw and "Elisa". Nothing is clipped by the iPad's rounded corners or the iPhone's notch, and there is no status bar or home indicator.
- **menu-02:** 14 rectangles with black borders, three per row (five in landscape), the last row spread out, all on screen without scrolling; the music note is blue.
- **menu-03:** the four paragraphs in Open Sans ink; the links look like the rest of the text.
- **menu-04:** one row: a yellow square with a black border, the date, and `1 / 1 (100%) 😊` in bold.
- **menu-05/06:** the switcher with the paw ringed in blue and the dashed "+", a rule under it, then the rows in the web app's order with the web app's labels; Borrar perfil dimmed (guest) and Guardar as ink pills.
- **menu-07** has no reference: the Guided Access text is readable and the OK pill shows.

Known differences that are **not** bugs: the level is blue (3 flags) in `menu-01` because the history needs a level change; the reference has no title card in this app's version and showed the next button, which this app dropped in 0.3.2; icons are SF Symbols, not Fork Awesome; the form uses iOS menus and switches instead of HTML selects and checkboxes; the icons are round buttons instead of radio buttons; there is no **Tema** row.

Fix every other difference in the views and repeat Steps 2–3 until they match. Then `xcrun simctl shutdown all`.

- [ ] **Step 4: Make sure the normal test run still skips the screenshots**

```bash
cd ~/c/bsharp/SwiftApp
xcodebuild test -project ElisaMusica.xcodeproj -scheme ElisaMusica -destination 'platform=iOS Simulator,name=iPhone 16e' -derivedDataPath build/dd 2>&1 | grep -E "skipped|TEST (SUCCEEDED|FAILED)" | tail -5
xcrun simctl shutdown all
```

Expected: the four `ScreenshotTests` cases reported as skipped, and `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/UITests/ScreenshotTests.swift
git status --short SwiftApp
git commit -m "Add menu screenshots and match the panels to the web app"
```

Also commit any view fixes from Step 3 in the same commit (explicit paths). `git status --short SwiftApp` must show nothing under `build/`.

---

### Task 12: README and plan

**Files:**
- Modify: `SwiftApp/README.md`, `SwiftApp/PLAN.md`

- [ ] **Step 1: README**

In `SwiftApp/README.md`, in the "Progress" section, replace `in this app tap the title six
times quickly` with `in this app tap the empty part of the top bar (left of the gear) six times quickly` (the text wraps across a line break; match it as it is in the file).

Add this section after "Progress":

```
## Menu

The gear at the top right shows home, the piano trainer, the info text, the stats history and
the profile (icon and name). Panels take the place of the game until home is tapped or the
menu is hidden. In the profile panel, level and instrument apply at once; the other settings
apply with **Guardar**. Six quick taps on "rojo" in the info text unlock level 0 (red) in the
level picker until the app quits.

The app hides the status bar and home indicator, defers edge swipes, and keeps the screen on
until five minutes after the last play or tap. To lock the iPad to the app, use Guided Access
(profile panel → **Fijar pantalla → Info**).
```

- [ ] **Step 2: PLAN.md**

In `SwiftApp/PLAN.md`:
- replace `9. **Menu and panels.**` with `9. **Menu and panels (done).**` and `10. **iPad polish.**` with `10. **iPad polish (done).**`;
- in the "Folder layout" block, replace `HomeView, CharacterReveal, StreakOutline, Fonts/, Assets.xcassets/` with `HomeView, CharacterReveal, StreakOutline, MenuBar, PanelCard, InfoPanel, TrainerPanel, HistoryPanel, ProfilePanel, GuidedAccessInfo, Fonts/, Assets.xcassets/`;
- in the same block, replace `FlagLayout, TapUnlock, Rewards` with `FlagLayout, TapUnlock, Rewards, LevelOptions, ProfileIcons, Profiles, History, KeepAwake`.

If any text to replace isn't there verbatim (the files may have drifted), apply the evident intent and report the deviation.

- [ ] **Step 3: Commit**

```bash
cd ~/c/bsharp
git add SwiftApp/README.md SwiftApp/PLAN.md
git commit -m "Document the menu and the iPad behavior"
```

---

### Task 13: Ship it to the iPad (only with the user's approval)

- [ ] **Step 1: Everything green once more**

```bash
cd ~/c/bsharp/SwiftApp/ElisaKit && swift test 2>&1 | tail -2
cd ~/c/bsharp/SwiftApp && xcodebuild test -project ElisaMusica.xcodeproj -scheme ElisaMusica -destination 'platform=iOS Simulator,name=iPhone 16e' -derivedDataPath build/dd 2>&1 | grep -E "TEST (SUCCEEDED|FAILED)" | tail -1
cd ~/c/bsharp/SwiftApp && for t in scripts/deploy/*_test.rb; do ruby "$t" | tail -1; done
xcrun simctl shutdown all
```

Expected: no Swift failures, `** TEST SUCCEEDED **`, every Ruby line `0 failures, 0 errors`.

- [ ] **Step 2: Ask the user**

The deploy needs a clean tree on `main`. If `git status --short` shows the user's web-app changes, ask them to commit or stash them; don't do it yourself. Then ask for approval, explaining: `SwiftApp/deploy minor --yes --summary "Gear menu with trainer, info, history and profiles; app-like iPad behavior."` publishes 0.4.0 to files.chiq.me, commits, tags `elisa-musica-ota-v0.4.0` and pushes `main` to `github`. Wait for an explicit yes.

- [ ] **Step 3: Deploy**

```bash
cd ~/c/bsharp && SwiftApp/deploy minor --yes --summary "Gear menu with trainer, info, history and profiles; app-like iPad behavior."
```

If the push reports a rejection but says `github/main is already at …; continuing`, git-sync got there first: check the tag reached the remote with `git ls-remote --tags github 'elisa-musica-ota-v*'`, and push it with `git push github elisa-musica-ota-v0.4.0` if it's missing.

Send the ntfy notification (the `ntfy` skill; see the project memory `ios-deploy-ntfy`) with the install page link `https://files.chiq.me/files/elisa-musica-install.html`. Ask the user to install it on the iPad and check what the simulator can't:
- there is no status bar or home indicator, and a swipe up from the bottom edge needs a second swipe before it leaves the app;
- the screen stays on while Elisa plays, and auto-locks again about five minutes after the last tap (with the iPad's auto-lock set to 2 minutes, it should still be on 3 minutes after a tap);
- a chord in the piano trainer sounds at once, on the profile's instrument;
- Guided Access, set up with the instructions behind **Fijar pantalla → Info**, keeps the app on screen.

---

## Done when

- `cd SwiftApp/ElisaKit && swift test` passes: level labels, profile icons, profiles (add, edit, switch, delete), history rows and faces, the keep-awake rule and `Game.editProgress` (plus everything from Plans 1–3).
- `xcodebuild test` passes the game flows from Plans 2–3 and the eight menu flows; the menu screenshots match the references apart from the known differences.
- Elisa's iPad runs 0.4.0: the gear opens the menu and every panel works; the app hides the system bars, needs a second swipe at the edges, and keeps the screen on during a session.
