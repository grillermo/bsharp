import Testing
@testable import ElisaKit

final class GameTestClock {
    var now = 1_793_400_000.0
}

@Suite struct GameTests {
    let clock = GameTestClock()

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
        let outcome = g.tap("red")
        #expect(outcome == .sound)
        #expect(g.profile.stats.identifications == 0)
    }

    @Test func playAsksTheQuestionAndHidesTheHint() {
        var g = game()
        let played = g.play()
        #expect(played == "red")
        #expect(g.asked)
        #expect(!g.showsPlayHint)
    }

    @Test func aWrongAnswerCountsAndSheKeepsGuessing() {
        var g = game()
        _ = g.play()
        g.chordFinished()
        let wrong = g.tap("yellow")
        #expect(wrong == .wrong)
        #expect(g.marked == nil)
        #expect(g.profile.stats.identifications == 1)
        #expect(g.profile.stats.correct == 0)
        #expect(g.profile.streak == 0)
        let right = g.tap("red")
        #expect(right == .correct)
    }

    @Test func theRightAnswerLocksTheFlags() {
        var g = game()
        _ = g.play()
        g.chordFinished()
        let right = g.tap("red")
        #expect(right == .correct)
        #expect(g.marked == "red")
        #expect(g.profile.streak == 1)
        #expect(g.flagsLocked)
        let after = g.tap("yellow")
        #expect(after == .ignored)
        #expect(g.profile.stats.identifications == 1)
    }

    @Test func theFlagsStayLockedUntilTheChordHasSounded() {
        var g = game()
        _ = g.play()
        #expect(g.flagsLocked)
        #expect(g.tap("red") == .ignored)
        #expect(g.profile.stats.identifications == 0)
        g.chordFinished()
        #expect(!g.flagsLocked)
        #expect(g.tap("red") == .correct)
    }

    @Test func aLevelChangeWhileTheChordSoundsOpensTheFlags() {
        var g = game()
        _ = g.play()
        g.changeLevel(to: "blue")
        #expect(!g.flagsLocked)
    }

    @Test func afterTheRevealTheFlagsWaitForPlay() {
        var g = game()
        _ = g.play()
        g.chordFinished()
        _ = g.tap("red")
        g.revealFinished()
        #expect(g.marked == nil)
        #expect(g.awaitingPlay)
        #expect(!g.asked)
        #expect(!g.showsPlayHint)
        let ignored = g.tap("red")
        #expect(ignored == .ignored)
        _ = g.play()
        #expect(!g.awaitingPlay)
        #expect(g.flagsLocked, "still locked while the chord sounds")
        g.chordFinished()
        let right = g.tap("red")
        #expect(right == .correct)
        #expect(g.profile.streak == 2)
    }

    @Test func playDuringTheRevealEndsItAndOpensTheFlags() {
        var g = game()
        _ = g.play()
        g.chordFinished()
        _ = g.tap("red")
        #expect(g.marked == "red")
        _ = g.play()
        g.chordFinished()
        #expect(g.marked == nil)
        #expect(g.character == nil)
        #expect(!g.awaitingPlay)
        #expect(g.asked)
        #expect(g.tap("red") == .correct)
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
        g.chordFinished()
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
        g.chordFinished()
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
        g.chordFinished()
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
        g.chordFinished()
        _ = g.tap("gray")
        #expect(g.noteStyle != nil)
    }

    @Test func theInstrumentIsTheProfiles() {
        var progress = SavedProgress.fresh(now: clock.now)
        progress.profile.currentInstrument = "guitar-strummed"
        #expect(game(progress).instrument == .guitarStrummed)
    }
}
