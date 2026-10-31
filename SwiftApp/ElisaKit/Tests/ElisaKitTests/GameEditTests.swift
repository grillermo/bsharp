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
