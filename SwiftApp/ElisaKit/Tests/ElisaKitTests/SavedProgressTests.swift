import Foundation
import Testing
@testable import ElisaKit

@Suite struct SavedProgressTests {
    private func decode(_ json: String) throws -> SavedProgress {
        try JSONDecoder().decode(SavedProgress.self, from: Data(json.utf8))
    }

    @Test func decodesAWebAppDownload() throws {
        let progress = try JSONDecoder().decode(SavedProgress.self, from: Fixtures.webExport)
        #expect(progress.state.currentProfile == 100)
        #expect(progress.state.currentChord == "blue")
        let elisa = try #require(progress.state.profiles["100"])
        #expect(elisa.name == "Elisa")
        #expect(elisa.instrument == .guitar)
        #expect(elisa.streak == 7)
        #expect(elisa.stats.correct == 3)
        #expect(elisa.stats.identifications == 4)
        #expect(elisa.stats.startTime == 1793380000.5)
        #expect(elisa.stats.confusionMatrix["blue"]?["red"] == 1)
        let yellow = try #require(progress.history["100"]?["yellow"])
        #expect(yellow.count == 1)
        #expect(yellow[0].done)
        #expect(yellow[0].identifications == 20)
    }

    @Test func aProfileFromAnOldVersionGetsTheDefaults() throws {
        let progress = try JSONDecoder().decode(SavedProgress.self, from: Fixtures.webExport)
        let papa = try #require(progress.state.profiles["101"])
        #expect(papa.name == "Papá")
        #expect(papa.showChordMode == "black_only")
        #expect(papa.revealChordMode == "always")
        #expect(papa.chordDisplayMode == "shapes_and_letters")
        #expect(papa.chordSelectionMode == "random")
        #expect(papa.enableOnboardingHints)
        #expect(papa.persistReactionFace)
        #expect(papa.targetNumber == 25)
        #expect(papa.currentChord == "yellow")
        #expect(papa.instrument == .piano)
        #expect(papa.streak == nil)
    }

    @Test func aRoundTripLosesNothing() throws {
        let progress = try JSONDecoder().decode(SavedProgress.self, from: Fixtures.webExport)
        let again = try JSONDecoder().decode(SavedProgress.self, from: JSONEncoder().encode(progress))
        #expect(again == progress)
    }

    @Test func theSingleNoteTallyIsKeptAsIs() throws {
        let progress = try JSONDecoder().decode(SavedProgress.self, from: Fixtures.webExport)
        let notes = try #require(progress.state.profiles["100"]).stats.notes
        // Counts must stay numbers: a JSON 1 decoded as `true` would change the data.
        #expect(notes == .object([
            "correct": .number(1),
            "identifications": .number(1),
            "confusion_matrix": .object(["gray": .object(["C#4": .object(["C#4": .number(1)])])]),
        ]))
    }

    @Test func anUnknownInstrumentPlaysPianoButIsKept() throws {
        let progress = try decode("""
        {"state": {"profiles": {"100": {"id": 100, "name": "E", "icon": "fa-paw",
          "current_instrument": "kazoo"}}, "current_chord": "yellow", "current_profile": 100},
         "history": {}}
        """)
        let profile = try #require(progress.state.profiles["100"])
        #expect(profile.instrument == .piano)
        #expect(profile.currentInstrument == "kazoo")
    }

    @Test func anEmptyHistorySavedAsAnArrayDecodes() throws {
        // getSessionHistory() treats a stored [] as {}.
        let progress = try decode("""
        {"state": {"profiles": {}, "current_chord": "yellow", "current_profile": 100}, "history": []}
        """)
        #expect(progress.history.isEmpty)
    }

    @Test func aMissingCurrentProfileIsTheGuest() throws {
        let progress = try decode("""
        {"state": {"profiles": {}, "current_chord": "yellow"}, "history": {}}
        """)
        #expect(progress.state.currentProfile == 100)
    }

    @Test func noStreakIsLeftOutOfTheJSON() throws {
        let profile = Profile(id: 100, name: "Elisa", icon: "fa-paw", now: 0)
        let json = String(decoding: try JSONEncoder().encode(profile), as: UTF8.self)
        #expect(!json.contains("streak"))
        #expect(json.contains("\"current_instrument\":\"piano_1\""))
    }

    @Test func aFreshStartHasOneGuestProfileAtYellow() {
        let progress = SavedProgress.fresh(now: 1000)
        #expect(progress.state.currentProfile == 100)
        #expect(progress.state.currentChord == "yellow")
        #expect(Array(progress.state.profiles.keys) == ["100"])
        let elisa = progress.state.profiles["100"]
        #expect(elisa?.name == "Elisa")
        #expect(elisa?.icon == "fa-paw")
        #expect(elisa?.stats.startTime == 1000)
        #expect(elisa?.stats.currentChord == "yellow")
        #expect(progress.history.isEmpty)
    }
}
