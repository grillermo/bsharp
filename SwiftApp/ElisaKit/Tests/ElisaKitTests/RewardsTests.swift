import Testing
@testable import ElisaKit

private let t0 = 1_793_400_000.0

@Suite struct RewardsTests {
    @Test func aLevelUpGoesToTheNextLevelOnTheOtherInstrument() {
        var p = SavedProgress.fresh(now: t0)
        p.profile.streak = 20
        let up = p.levelUp(now: t0 + 1)
        #expect(up == LevelUp(level: "blue", instrument: .guitar))
        #expect(p.state.currentChord == "blue")
        #expect(p.profile.currentChord == "blue")
        #expect(p.profile.stats.currentChord == "blue")
        #expect(p.profile.currentInstrument == "guitar")
        #expect(p.profile.streak == 0)
    }

    @Test func theNextLevelUpSwitchesBackToPiano() {
        var p = SavedProgress.fresh(now: t0)
        p.profile.streak = 20
        p.levelUp(now: t0 + 1)
        p.profile.streak = 20
        let up = p.levelUp(now: t0 + 2)
        #expect(up == LevelUp(level: "black", instrument: .piano))
        #expect(p.profile.instrument == .piano)
    }

    @Test func strummedGuitarGoesToPiano() {
        var p = SavedProgress.fresh(now: t0)
        p.profile.currentInstrument = Instrument.guitarStrummed.rawValue
        p.profile.streak = 20
        p.levelUp(now: t0 + 1)
        #expect(p.profile.instrument == .piano)
    }

    @Test func theSessionAtTheOldLevelIsParkedUnfinished() {
        var p = SavedProgress.fresh(now: t0)
        p.recordAnswer(played: "red", chosen: "red", now: t0 + 1)
        p.levelUp(now: t0 + 2)
        #expect(p.history["100"]?["yellow"]?.count == 1)
        #expect(p.history["100"]?["yellow"]?.first?.done == false)
        #expect(p.profile.stats.identifications == 0)
    }

    @Test func theLastLevelOnlyStartsTheStreakOver() {
        var p = SavedProgress.fresh(now: t0)
        p.state.currentChord = "skyblue"
        p.profile.currentChord = "skyblue"
        p.profile.currentInstrument = Instrument.guitar.rawValue
        p.profile.streak = 20
        let up = p.levelUp(now: t0 + 1)
        #expect(up == nil)
        #expect(p.state.currentChord == "skyblue")
        #expect(p.profile.instrument == .guitar)
        #expect(p.profile.streak == 0)
    }
}
