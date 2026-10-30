import Testing
@testable import ElisaKit

@Suite struct NoteDisplayTests {
    private func chord(_ id: String) -> Chord { Chords.all.first { $0.id == id }! }

    @Test func lettersUseRealSharpAndFlatSigns() {
        #expect(NoteDisplay.letter(for: "C#4") == "C♯")
        #expect(NoteDisplay.letter(for: "Bb3") == "B♭")
        #expect(NoteDisplay.letter(for: "E4") == "E")
    }

    @Test func grayIsAnUpsideDownTriangleAPentagonAndAHeart() {
        let marks = NoteDisplay.marks(for: chord("gray"), shapes: true)
        #expect(marks.map(\.shape) == [.triangleDown, .pentagon, .heart])
        #expect(marks.map(\.letter) == ["A", "C♯", "E"])
        #expect(marks[0].letterDY == -0.10)
    }

    @Test func everyNoteHasItsOwnShape() {
        let marks = Chords.all.flatMap { NoteDisplay.marks(for: $0, shapes: true) }
        var shapeOfNote: [String: NoteShape] = [:]
        for mark in marks { shapeOfNote[mark.note] = mark.shape }
        #expect(shapeOfNote.count == 18)
        #expect(Set(shapeOfNote.values) == Set(NoteShape.allCases))
    }

    @Test func gSharpIsABiggerStar() {
        let gSharp = NoteDisplay.marks(for: chord("lightgreen"), shapes: true)[1]
        #expect(gSharp.shape == .star)
        #expect(gSharp.scale == 1.25)
    }

    @Test func withoutShapesEveryNoteIsAPlainCircle() {
        let marks = NoteDisplay.marks(for: chord("gray"), shapes: false)
        #expect(marks.allSatisfy { $0.shape == .circle && $0.letterDX == 0 && $0.letterDY == 0 && $0.scale == 1 })
    }

    @Test func displayModesPickShapesAndLetters() {
        #expect(NoteDisplay.style(for: "shapes_and_letters") == .init(shapes: true, letters: true))
        #expect(NoteDisplay.style(for: "shapes_only") == .init(shapes: true, letters: false))
        #expect(NoteDisplay.style(for: "letters_only") == .init(shapes: false, letters: true))
    }

    @Test func blackOnlyMeansFromGrayOn() {
        #expect(!NoteDisplay.chordsOn(showChordMode: "black_only", level: "brown"))
        #expect(NoteDisplay.chordsOn(showChordMode: "black_only", level: "gray"))
        #expect(NoteDisplay.chordsOn(showChordMode: "always", level: "yellow"))
        #expect(!NoteDisplay.chordsOn(showChordMode: "never", level: "skyblue"))
    }

    @Test func afterGuessShowsNotesOnlyWithTheAnswerOnScreen() {
        var profile = Profile.guest(now: 0)
        profile.revealChordMode = "after_guess"
        #expect(!NoteDisplay.notesVisible(profile: profile, level: "gray", answerShown: false))
        #expect(NoteDisplay.notesVisible(profile: profile, level: "gray", answerShown: true))
        profile.revealChordMode = "always"
        #expect(NoteDisplay.notesVisible(profile: profile, level: "gray", answerShown: false))
        #expect(!NoteDisplay.notesVisible(profile: profile, level: "yellow", answerShown: true))
    }
}
