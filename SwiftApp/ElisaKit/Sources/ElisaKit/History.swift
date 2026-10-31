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
