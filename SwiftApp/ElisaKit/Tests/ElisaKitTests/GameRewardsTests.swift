import Testing
@testable import ElisaKit

@Suite struct GameRewardsTests {
    let clock = GameTestClock()

    /// A started game that always asks red. `level` and `instrument` are what her profile
    /// saved; `streak` is the streak she starts with.
    private func game(level: String = "yellow", instrument: Instrument = .piano, streak: Int? = nil,
                      hints: Bool = true) -> Game {
        var progress = SavedProgress.fresh(now: clock.now)
        progress.state.currentChord = level
        progress.profile.currentChord = level
        progress.profile.stats.currentChord = level
        progress.profile.currentInstrument = instrument.rawValue
        progress.profile.enableOnboardingHints = hints
        var game = Game(progress: progress, forcedAnswer: "red", startingStreak: streak,
                        random: { 0.0 }, now: { [clock] in clock.now })
        game.start()
        return game
    }

    /// Presses play and answers red, the right answer.
    private func answerRight(_ g: inout Game) {
        _ = g.play()
        _ = g.tap("red")
    }

    @Test func aRightAnswerDealsACharacterUntilTheRevealEnds() {
        var g = game()
        _ = g.play()
        let wrong = g.tap("yellow")
        #expect(wrong == .wrong)
        #expect(g.character == nil)
        let right = g.tap("red")
        #expect(right == .correct)
        #expect(Characters.all.contains(g.character ?? ""))
        g.revealFinished()
        #expect(g.character == nil)
    }

    @Test func charactersDontRepeatWithinARound() {
        var g = game()
        answerRight(&g)
        let first = g.character
        g.revealFinished()
        answerRight(&g)
        #expect(g.character != nil)
        #expect(g.character != first)
    }

    @Test func theStreakCountsRightAnswersAndAMissStartsOver() {
        var g = game()
        #expect(g.streak == 0)
        answerRight(&g)
        #expect(g.streak == 1)
        g.revealFinished()
        _ = g.play()
        let wrong = g.tap("yellow")
        #expect(wrong == .wrong)
        #expect(g.streak == 0)
    }

    @Test func aStartingStreakIsKept() {
        let g = game(streak: 7)
        #expect(g.streak == 7)
    }

    @Test func twentyInARowIsDueForALevelUpButNineteenIsNot() {
        var nineteen = game(streak: 18)
        answerRight(&nineteen)
        #expect(nineteen.streak == 19)
        #expect(!nineteen.levelUpDue)
        var twenty = game(streak: 19)
        answerRight(&twenty)
        #expect(twenty.streak == 20)
        #expect(twenty.levelUpDue)
    }

    @Test func theRevealEndsWithTheNextLevelOnTheOtherInstrument() {
        var g = game(streak: 19)
        answerRight(&g)
        g.revealFinished()
        #expect(g.level == "blue")
        #expect(g.chords.map(\.id) == ["red", "yellow", "blue"])
        #expect(g.instrument == .guitar)
        #expect(g.profile.currentInstrument == "guitar")
        #expect(g.streak == 0)
        #expect(!g.levelUpDue)
        #expect(g.marked == nil)
        #expect(g.character == nil)
        // As after any level change: the hint shows, and the flags wait for play.
        #expect(g.showsPlayHint)
        #expect(g.awaitingPlay)
        #expect(!g.asked)
    }

    @Test func aLevelUpFromGuitarGoesBackToPiano() {
        var g = game(instrument: .guitar, streak: 19)
        answerRight(&g)
        g.revealFinished()
        #expect(g.level == "blue")
        #expect(g.instrument == .piano)
    }

    @Test func noHintAfterALevelUpWhenHintsAreOff() {
        var g = game(streak: 19, hints: false)
        answerRight(&g)
        g.revealFinished()
        #expect(g.level == "blue")
        #expect(!g.showsPlayHint)
        #expect(g.awaitingPlay)
    }

    @Test func theLastLevelStartsTheStreakOverAndKeepsTheInstrument() {
        var g = game(level: "skyblue", instrument: .guitar, streak: 19)
        answerRight(&g)
        g.revealFinished()
        #expect(g.level == "skyblue")
        #expect(g.instrument == .guitar)
        #expect(g.streak == 0)
        #expect(g.awaitingPlay)
        #expect(!g.showsPlayHint)
        #expect(!g.levelUpDue)
    }

    @Test func aPlainRevealKeepsTheLevelAndTheStreak() {
        var g = game()
        answerRight(&g)
        g.revealFinished()
        #expect(g.level == "yellow")
        #expect(g.instrument == .piano)
        #expect(g.streak == 1)
        #expect(g.awaitingPlay)
    }
}
