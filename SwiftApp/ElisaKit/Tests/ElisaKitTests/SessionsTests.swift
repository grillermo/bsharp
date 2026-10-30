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
        let wrong = p.recordAnswer(played: "red", chosen: "yellow", now: t0 + 10)
        let right1 = p.recordAnswer(played: "red", chosen: "red", now: t0 + 20)
        let right2 = p.recordAnswer(played: "yellow", chosen: "yellow", now: t0 + 30)
        #expect(wrong == false)
        #expect(right1)
        #expect(right2)
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
