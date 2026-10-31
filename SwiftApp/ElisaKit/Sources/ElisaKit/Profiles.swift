import Foundation

/// The settings form (ui.ts getProfileSettings). The goal stays text until it is checked, as
/// the web app reads it from an input.
public struct ProfileSettings: Equatable, Sendable {
    public var name: String
    public var icon: String?
    public var targetNumber: String
    public var showChordMode: String
    public var revealChordMode: String
    public var chordDisplayMode: String
    public var persistReactionFace: Bool
    public var enableOnboardingHints: Bool
    public var chordSelectionMode: String

    /// The form filled in from a profile (populateProfileSettings).
    public init(profile: Profile) {
        name = profile.name
        icon = profile.icon
        targetNumber = String(profile.targetNumber)
        showChordMode = profile.showChordMode
        revealChordMode = profile.revealChordMode
        chordDisplayMode = profile.chordDisplayMode
        persistReactionFace = profile.persistReactionFace
        enableOnboardingHints = profile.enableOnboardingHints
        chordSelectionMode = profile.chordSelectionMode
    }

    /// The form for a new profile (openProfileAdder): the defaults, no name, the first icon.
    public static var blank: ProfileSettings {
        var settings = ProfileSettings(profile: Profile(id: 0, name: "", icon: ProfileIcons.all[0], now: 0))
        settings.name = ""
        return settings
    }
}

/// A form that can't be saved, with the web app's message for it.
public struct ProfileError: Error, Equatable, Sendable {
    public let message: String
}

extension Profile {
    mutating func apply(_ settings: ProfileSettings, icon: String, targetNumber: Int) {
        name = settings.name
        self.icon = icon
        self.targetNumber = targetNumber
        showChordMode = settings.showChordMode
        revealChordMode = settings.revealChordMode
        chordDisplayMode = settings.chordDisplayMode
        persistReactionFace = settings.persistReactionFace
        enableOnboardingHints = settings.enableOnboardingHints
        chordSelectionMode = settings.chordSelectionMode
    }
}

extension SavedProgress {
    /// The switcher's order: every profile but the guest by id, then the guest
    /// (populateProfileSwitcher).
    public var switcherProfiles: [Profile] {
        let others = state.profiles.values.filter { $0.id != Defaults.guestProfileID }.sorted { $0.id < $1.id }
        let guest = state.profiles[String(Defaults.guestProfileID)]
        return others + (guest.map { [$0] } ?? [])
    }

    /// Case-insensitive, over every profile (isProfileNameTaken).
    public func isNameTaken(_ name: String) -> Bool {
        state.profiles.values.contains { $0.name.lowercased() == name.lowercased() }
    }

    /// The goal as a whole number (utils.ts validInt), surrounding spaces allowed.
    static func target(_ text: String) -> Int? {
        Int(text.trimmingCharacters(in: .whitespaces))
    }

    /// Adds a profile and plays as it (addProfile). Its id is the first free one after the
    /// guest's, as newProfile picks it.
    @discardableResult
    public mutating func addProfile(_ settings: ProfileSettings, now: Double) throws -> Int {
        guard let icon = settings.icon, !settings.name.isEmpty else {
            throw ProfileError(message: "Escribe un nombre y elige un ícono.")
        }
        if isNameTaken(settings.name) {
            throw ProfileError(message: "Ya existe un perfil llamado \(settings.name).")
        }
        guard let target = Self.target(settings.targetNumber) else {
            throw ProfileError(message: "La meta debe ser un número entero; recibí: \(settings.targetNumber)")
        }
        var id = Defaults.guestProfileID + 1
        while state.profiles[String(id)] != nil { id += 1 }
        var profile = Profile(id: id, name: settings.name, icon: icon, now: now)
        profile.apply(settings, icon: icon, targetNumber: target)
        state.profiles[String(id)] = profile
        switchProfile(to: id, now: now)
        return id
    }

    /// Saves the form over the current profile (submitProfileChanges). An empty name is refused
    /// too; the web app only avoids it by disabling the guest's name field.
    public mutating func updateProfile(_ settings: ProfileSettings) throws {
        if settings.name != profile.name && isNameTaken(settings.name) {
            throw ProfileError(message: "El nombre \(settings.name) ya está en uso; elige otro.")
        }
        guard let icon = settings.icon else { throw ProfileError(message: "¡Elige un ícono!") }
        guard let target = Self.target(settings.targetNumber) else {
            throw ProfileError(message: "La meta debe ser un número válido; recibí: \(settings.targetNumber)")
        }
        guard !settings.name.isEmpty else { throw ProfileError(message: "Escribe un nombre.") }
        profile.apply(settings, icon: icon, targetNumber: target)
    }

    /// Plays as another profile (setCurrentProfile). The current session is parked, unfinished,
    /// at its own level; the other profile's parked session at its level is picked up again.
    /// (The web app files the new profile's session under the previous profile's level.)
    public mutating func switchProfile(to id: Int, now: Double) {
        guard id != state.currentProfile, state.profiles[String(id)] != nil else { return }
        resetStats(done: false, now: now)
        state.currentProfile = id
        if !Chords.ids.contains(profile.currentChord) {
            profile.currentChord = Defaults.level
        }
        state.currentChord = profile.currentChord
        profile.stats.currentChord = profile.currentChord
        resumeSession(now: now)
    }

    /// Deletes a profile and its history (deleteProfile). Deleting the one playing goes back to
    /// the guest. The history goes too, so a later profile that gets the same id starts clean.
    public mutating func deleteProfile(id: Int, now: Double) throws {
        guard id != Defaults.guestProfileID else {
            throw ProfileError(message: "No se puede borrar el perfil principal.")
        }
        guard state.profiles[String(id)] != nil else { return }
        if id == state.currentProfile {
            switchProfile(to: Defaults.guestProfileID, now: now)
        }
        state.profiles[String(id)] = nil
        history[String(id)] = nil
    }
}
