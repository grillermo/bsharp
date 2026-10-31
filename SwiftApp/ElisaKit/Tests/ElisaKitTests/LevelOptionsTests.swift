import Testing
@testable import ElisaKit

@Suite struct LevelOptionsTests {
    @Test func notesAreNamedInSolfege() {
        #expect(LevelOptions.solfege("C4") == "Do")
        #expect(LevelOptions.solfege("G4") == "Sol")
        #expect(LevelOptions.solfege("C#4") == "Do♯")
        #expect(LevelOptions.solfege("Bb3") == "Si♭")
        #expect(LevelOptions.solfege("Eb4") == "Mi♭")
    }

    @Test func labelsMatchTheWebAppsSelector() {
        func label(_ id: String) -> String { LevelOptions.label(for: Chords.chord(id)!) }
        #expect(label("red") == "Nivel 0: Rojo (Do Mi Sol)")
        #expect(label("yellow") == "Nivel 1: Amarillo (Do Fa La)")
        #expect(label("blue") == "Nivel 2: Azul (Si Re Sol)")
        #expect(label("brown") == "Nivel 8: Café (Sol Do Mi)")
        #expect(label("gray") == "Nivel 1: Gris (La Do♯ Mi)")
        #expect(label("lightpurple") == "Nivel 4: Lila (Si♭ Re Fa)")
        #expect(label("skyblue") == "Nivel 5: Celeste (Mi♭ Sol Si♭)")
    }

    @Test func redIsHiddenUnlessAsked() {
        #expect(LevelOptions.white(includingRed: false).map(\.id)
            == ["yellow", "blue", "black", "green", "orange", "purple", "pink", "brown"])
        #expect(LevelOptions.white(includingRed: true).first?.id == "red")
        #expect(LevelOptions.black.map(\.id) == ["gray", "tan", "lightgreen", "lightpurple", "skyblue"])
    }

    @Test func chordsAreFoundById() {
        #expect(Chords.chord("tan")?.spanishName == "Beige")
        #expect(Chords.chord("nope") == nil)
    }

    @Test func instrumentsHaveTheSelectorsNames() {
        #expect(Instrument.allCases.map(\.spanishName) == ["Piano", "Guitarra", "Guitarra (rasgueo)"])
    }
}
