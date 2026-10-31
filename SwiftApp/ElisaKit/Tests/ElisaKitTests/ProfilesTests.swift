import Testing
@testable import ElisaKit

private let t0 = 1_793_400_000.0

private func settings(_ name: String, icon: String? = "fa-truck", target: String = "25") -> ProfileSettings {
    var s = ProfileSettings.blank
    s.name = name
    s.icon = icon
    s.targetNumber = target
    return s
}

private func expectError(_ message: String, _ action: () throws -> Void) {
    do {
        try action()
        Issue.record("expected “\(message)”")
    } catch let error as ProfileError {
        #expect(error.message == message)
    } catch {
        Issue.record("unexpected \(error)")
    }
}

@Suite struct ProfilesTests {
    @Test func theFormStartsFromTheProfile() {
        var guest = Profile.guest(now: t0)
        guest.targetNumber = 30
        guest.chordSelectionMode = "adaptive"
        let s = ProfileSettings(profile: guest)
        #expect(s.name == "Elisa")
        #expect(s.icon == "fa-paw")
        #expect(s.targetNumber == "30")
        #expect(s.chordSelectionMode == "adaptive")
    }

    @Test func aBlankFormHasTheDefaultsAndTheFirstIcon() {
        let s = ProfileSettings.blank
        #expect(s.name == "")
        #expect(s.icon == "fa-user")
        #expect(s.targetNumber == "25")
        #expect(s.showChordMode == Defaults.showChordMode)
        #expect(s.enableOnboardingHints == Defaults.enableOnboardingHints)
    }

    @Test func aNewProfileGetsTheNextFreeIdAndPlays() throws {
        var p = SavedProgress.fresh(now: t0)
        let papa = try p.addProfile(settings("Papá"), now: t0 + 1)
        #expect(papa == 101)
        #expect(p.state.currentProfile == 101)
        #expect(p.profile.name == "Papá")
        #expect(p.profile.icon == "fa-truck")
        #expect(p.profile.currentChord == Defaults.level)
        #expect(p.profile.instrument == .piano)
        let mama = try p.addProfile(settings("Mamá"), now: t0 + 2)
        #expect(mama == 102)
    }

    @Test func addingChecksTheForm() {
        var p = SavedProgress.fresh(now: t0)
        expectError("Escribe un nombre y elige un ícono.") { try p.addProfile(settings(""), now: t0) }
        expectError("Escribe un nombre y elige un ícono.") { try p.addProfile(settings("Papá", icon: nil), now: t0) }
        expectError("Ya existe un perfil llamado elisa.") { try p.addProfile(settings("elisa"), now: t0) }
        expectError("La meta debe ser un número entero; recibí: 2.5") {
            try p.addProfile(settings("Papá", target: "2.5"), now: t0)
        }
        #expect(p.state.profiles.count == 1)
    }

    @Test func savingTheFormChangesTheCurrentProfile() throws {
        var p = SavedProgress.fresh(now: t0)
        var s = ProfileSettings(profile: p.profile)
        s.icon = "fa-bolt"
        s.targetNumber = " 30 "
        s.revealChordMode = "after_guess"
        s.enableOnboardingHints = false
        try p.updateProfile(s)
        #expect(p.profile.icon == "fa-bolt")
        #expect(p.profile.targetNumber == 30)
        #expect(p.profile.revealChordMode == "after_guess")
        #expect(!p.profile.enableOnboardingHints)
        #expect(p.profile.name == "Elisa")
    }

    @Test func savingChecksTheForm() throws {
        var p = SavedProgress.fresh(now: t0)
        try p.addProfile(settings("Papá"), now: t0)
        var s = ProfileSettings(profile: p.profile)
        s.name = "ELISA"
        expectError("El nombre ELISA ya está en uso; elige otro.") { try p.updateProfile(s) }
        s = ProfileSettings(profile: p.profile)
        s.icon = nil
        expectError("¡Elige un ícono!") { try p.updateProfile(s) }
        s = ProfileSettings(profile: p.profile)
        s.targetNumber = "muchas"
        expectError("La meta debe ser un número válido; recibí: muchas") { try p.updateProfile(s) }
        s = ProfileSettings(profile: p.profile)
        s.name = ""
        expectError("Escribe un nombre.") { try p.updateProfile(s) }
    }

    @Test func switchingParksTheSessionAndPicksUpTheOther() throws {
        var p = SavedProgress.fresh(now: t0)
        p.recordAnswer(played: "red", chosen: "red", now: t0 + 1)
        p.recordAnswer(played: "red", chosen: "yellow", now: t0 + 2)
        try p.addProfile(settings("Papá"), now: t0 + 3)
        #expect(p.profile.stats.identifications == 0)
        let parked = p.history["100"]?["yellow"]?.last
        #expect(parked?.identifications == 2)
        #expect(parked?.done == false)

        p.changeLevel(to: "blue", now: t0 + 4)
        p.switchProfile(to: 100, now: t0 + 5)
        #expect(p.state.currentChord == "yellow")
        #expect(p.profile.stats.identifications == 2)
        #expect(p.profile.stats.correct == 1)

        p.switchProfile(to: 101, now: t0 + 6)
        #expect(p.state.currentChord == "blue")
        #expect(p.profile.currentChord == "blue")
    }

    @Test func switchingKeepsEachStreak() throws {
        var p = SavedProgress.fresh(now: t0)
        p.profile.streak = 7
        try p.addProfile(settings("Papá"), now: t0 + 1)
        p.switchProfile(to: 100, now: t0 + 2)
        #expect(p.profile.streak == 7)
    }

    @Test func switchingToAnUnknownProfileDoesNothing() {
        var p = SavedProgress.fresh(now: t0)
        p.switchProfile(to: 999, now: t0)
        #expect(p.state.currentProfile == 100)
    }

    @Test func theGuestComesLastInTheSwitcher() throws {
        var p = SavedProgress.fresh(now: t0)
        try p.addProfile(settings("Papá"), now: t0)
        try p.addProfile(settings("Mamá"), now: t0)
        #expect(p.switcherProfiles.map(\.id) == [101, 102, 100])
    }

    @Test func deletingGoesBackToTheGuestAndDropsTheHistory() throws {
        var p = SavedProgress.fresh(now: t0)
        try p.addProfile(settings("Papá"), now: t0 + 1)
        p.recordAnswer(played: "red", chosen: "red", now: t0 + 2)
        p.changeLevel(to: "blue", now: t0 + 3) // files Papá's session at yellow
        #expect(p.history["101"] != nil)
        try p.deleteProfile(id: 101, now: t0 + 4)
        #expect(p.state.currentProfile == 100)
        #expect(p.state.profiles["101"] == nil)
        #expect(p.history["101"] == nil)
        #expect(p.state.currentChord == "yellow")
    }

    @Test func theGuestCantBeDeleted() {
        var p = SavedProgress.fresh(now: t0)
        expectError("No se puede borrar el perfil principal.") { try p.deleteProfile(id: 100, now: t0) }
        #expect(p.state.profiles["100"] != nil)
    }
}
