import Foundation

/// What a flag tap did.
public enum TapOutcome: Equatable, Sendable {
    /// The flags are locked (see `Game.flagsLocked`): nothing happens, not even a sound.
    case ignored
    /// The chord sounds but isn't an answer: nothing has been asked yet.
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
    /// The asked chord is still sounding after play, so the flags wait for it to end
    /// (`chordFinished()`).
    public private(set) var chordSounding = false
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
    public var level: String { progress.state.currentChord }
    public var chords: [Chord] { Chords.inPlay(upTo: level) }
    public var instrument: Instrument { profile.instrument }

    /// The flags are greyed out and taps do nothing: from a right answer until play is pressed
    /// again and the chord it plays has finished sounding, so she listens before she answers.
    public var flagsLocked: Bool { marked != nil || awaitingPlay || chordSounding }

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
        if let startingStreak {
            progress.profile.streak = startingStreak
        }
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

    /// A change from the menu (profiles, settings, the instrument), given the clock. Then the
    /// game starts afresh, as after a level change: a new unplayed question, and the hint if
    /// the profile has it on. A change that throws leaves everything as it was.
    public mutating func editProgress(_ change: (inout SavedProgress, Double) throws -> Void) rethrows {
        var edited = progress
        try change(&edited, now())
        progress = edited
        newSession()
    }

    /// Play pressed: returns the chord to sound. Pressed during a reveal, it ends the reveal
    /// at once, so the next chord (or level) is the one that sounds. The flags stay locked
    /// until the caller reports the chord has finished with `chordFinished()`.
    public mutating func play() -> String {
        revealFinished()
        showsPlayHint = false
        awaitingPlay = false
        chordSounding = true
        asked = true
        return answer
    }

    /// The chord that play sounded has ended: the flags open for an answer.
    public mutating func chordFinished() {
        chordSounding = false
    }

    public mutating func tap(_ color: String) -> TapOutcome {
        if flagsLocked { return .ignored }
        guard asked else { return .sound }
        guard progress.recordAnswer(played: answer, chosen: color, now: now()) else { return .wrong }
        marked = color
        character = deck.next()
        levelUpDue = streak >= Streak.target
        return .correct
    }

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

    private mutating func newSession() {
        weights = nil
        marked = nil
        character = nil
        levelUpDue = false
        awaitingPlay = false
        chordSounding = false
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
