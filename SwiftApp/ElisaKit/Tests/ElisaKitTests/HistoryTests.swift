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
