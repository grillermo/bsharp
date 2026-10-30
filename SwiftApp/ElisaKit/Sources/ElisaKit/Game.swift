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
