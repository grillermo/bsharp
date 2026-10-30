import Testing
@testable import ElisaKit

@Suite struct ProgressionTests {
    @Test func aCorrectAnswerAddsOneAndAMissStartsOver() {
        #expect(Streak.next(0, correct: true) == 1)
        #expect(Streak.next(7, correct: true) == 8)
        #expect(Streak.next(7, correct: false) == 0)
        #expect(Streak.next(0, correct: false) == 0)
    }

    @Test func progressIsTheShareOfTheTargetClampedToZeroOne() {
        #expect(Streak.target == 20)
        #expect(Streak.progress(0) == 0)
        #expect(Streak.progress(10) == 0.5)
        #expect(Streak.progress(20) == 1)
        #expect(Streak.progress(25) == 1)
        #expect(Streak.progress(-3) == 0)
    }

    @Test func nextLevelIsTheFollowingChordOrNilAtTheEnd() {
        let levels = ["red", "yellow", "blue"]
        #expect(Progression.nextLevel(after: "red", in: levels) == "yellow")
        #expect(Progression.nextLevel(after: "blue", in: levels) == nil)
        #expect(Progression.nextLevel(after: "pink", in: levels) == nil)
        #expect(Progression.nextLevel(after: "brown") == "gray")
    }

    @Test func everyLevelUpSwitchesBetweenPianoAndGuitar() {
        let first = Progression.levelUp(from: "yellow", instrument: .piano)
        #expect(first == LevelUp(level: "blue", instrument: .guitar))
        let second = Progression.levelUp(from: "blue", instrument: .guitar)
        #expect(second == LevelUp(level: "black", instrument: .piano))
    }

    @Test func strummedGuitarGoesBackToPianoOnLevelUp() {
        #expect(Progression.levelUp(from: "yellow", instrument: .guitarStrummed)?.instrument == .piano)
    }

    @Test func theLastLevelHasNoLevelUpSoTheInstrumentStays() {
        #expect(Progression.levelUp(from: "skyblue", instrument: .guitar) == nil)
    }

    @Test func instrumentIdsMatchTheWebAppsSavedState() {
        #expect(Instrument.allCases.map(\.rawValue) == ["piano_1", "guitar", "guitar-strummed"])
        #expect(Instrument.piano.chordFolder == "piano")
        #expect(Instrument.guitarStrummed.chordFolder == "guitar-strummed")
    }
}
