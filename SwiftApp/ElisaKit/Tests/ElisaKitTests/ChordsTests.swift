import Testing
@testable import ElisaKit

@Suite struct ChordsTests {
    @Test func chordsAreInTheWebAppsTeachingOrder() {
        // Saved progress uses these ids, so the order and spelling must match src/ts/data.ts.
        #expect(Chords.ids == [
            "red", "yellow", "blue", "black", "green", "orange", "purple", "pink", "brown",
            "gray", "tan", "lightgreen", "lightpurple", "skyblue",
        ])
    }

    @Test func blackKeyChordsStartAtGray() {
        #expect(Chords.all[Chords.firstBlackIndex].id == "gray")
    }

    @Test func aLevelPlaysEveryChordUpToItsOwn() {
        #expect(Chords.inPlay(upTo: "yellow").map(\.id) == ["red", "yellow"])
        #expect(Chords.inPlay(upTo: "skyblue").count == 14)
        #expect(Chords.inPlay(upTo: "nope").isEmpty)
    }
}
