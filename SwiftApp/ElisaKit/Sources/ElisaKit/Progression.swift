/// The recordings a chord can be played with. Raw values are the web app's ids, so a profile
/// imported from it keeps its instrument.
public enum Instrument: String, Codable, CaseIterable, Sendable {
    case piano = "piano_1"
    case guitar = "guitar"
    case guitarStrummed = "guitar-strummed"

    /// Folder of this instrument's recordings under `chords/`.
    public var chordFolder: String {
        switch self {
        case .piano: "piano"
        case .guitar: "guitar"
        case .guitarStrummed: "guitar-strummed"
        }
    }

    /// Each level-up switches between piano and guitar, so every new level starts on the
    /// other instrument. Strummed guitar is only ever chosen by hand; it goes back to piano.
    public var afterLevelUp: Instrument {
        self == .piano ? .guitar : .piano
    }
}

/// Correct answers in a row at the current level (src/ts/streak.ts). A miss starts over;
/// reaching the target moves to the next level.
public enum Streak {
    public static let target = 20

    public static func next(_ streak: Int, correct: Bool) -> Int {
        correct ? streak + 1 : 0
    }

    /// How far round the screen outline is filled, 0...1.
    public static func progress(_ streak: Int) -> Double {
        min(1, max(0, Double(streak) / Double(target)))
    }
}

public struct LevelUp: Equatable, Sendable {
    public let level: String
    public let instrument: Instrument
}

public enum Progression {
    /// The level after `current`, or nil when it is the last one (or unknown).
    public static func nextLevel(after current: String, in levels: [String] = Chords.ids) -> String? {
        guard let index = levels.firstIndex(of: current), index < levels.count - 1 else { return nil }
        return levels[index + 1]
    }

    /// Where a completed streak leads: the next level, on the other instrument. Nil at the
    /// last level, where the streak simply starts over and nothing switches.
    public static func levelUp(from level: String, instrument: Instrument) -> LevelUp? {
        nextLevel(after: level).map { LevelUp(level: $0, instrument: instrument.afterLevelUp) }
    }
}
