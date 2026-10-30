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
