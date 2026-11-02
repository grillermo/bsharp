import ElisaKit
import Foundation
import Observation
import UIKit

/// The main screen's state: the game, its progress file and the chord player.
@MainActor @Observable
final class GameModel {
    private(set) var game: Game
    private let options: LaunchOptions
    private let store: ProgressStore
    private let player = ChordPlayer()
    private var revealTask: Task<Void, Never>?
    private var unlockTask: Task<Void, Never>?

    /// Level 0 (red) in the level picker, unlocked by six quick taps on "rojo" in the info
    /// panel. Like the web app, only until the app quits.
    private(set) var redLevelUnlocked = false
    private var eggTaps = TapUnlock()
    private var lastActivity: Double?
    private var keepAwakeTask: Task<Void, Never>?

    init(options: LaunchOptions = .current()) {
        self.options = options
        store = ProgressStore(url: options.progressURL())
        let now = Date().timeIntervalSince1970
        game = Game(progress: store.load(now: now) ?? .fresh(now: now), forcedAnswer: options.answer,
                    startingStreak: options.streak)
        game.start()
        if let level = options.level {
            game.changeLevel(to: level)
        }
        CharacterImages.preload()
        player.load(game.instrument)
        save()
        DevLog.event("game.start", ["level": game.level, "instrument": game.instrument.rawValue])
    }

    func play() {
        // Play pressed during a reveal ends it at once, and may level up.
        revealTask?.cancel()
        let level = game.level
        let chord = game.play()
        levelChanged(from: level)
        scheduleUnlock(after: player.play(chord))
        save()
        noteActivity()
    }

    /// The flags open once the chord has sounded to the end (at once if it didn't sound).
    private func scheduleUnlock(after duration: TimeInterval?) {
        unlockTask?.cancel()
        guard let duration else {
            game.chordFinished()
            return
        }
        unlockTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled, let self else { return }
            self.game.chordFinished()
        }
    }

    func tap(_ color: String) {
        let outcome = game.tap(color)
        guard outcome != .ignored else { return }
        noteActivity()
        player.play(color)
        guard outcome != .sound else { return }
        DevLog.event("game.answer", ["asked": game.answer, "tapped": color, "streak": "\(game.profile.streak ?? 0)"])
        save()
        if outcome == .correct {
            scheduleRevealEnd()
        }
    }

    func becameActive() {
        game.becameActive()
        save()
        updateKeepAwake()
    }

    /// A flag in the piano trainer: it sounds and counts for nothing.
    func playTrainer(_ color: String) {
        player.play(color)
        noteActivity()
    }

    func changeLevel(_ level: String) {
        revealTask?.cancel()
        game.changeLevel(to: level)
        save()
        DevLog.event("menu.level", ["level": game.level])
    }

    func changeInstrument(_ instrument: Instrument) {
        edit("instrument") { progress, _ in progress.profile.currentInstrument = instrument.rawValue }
    }

    func switchProfile(_ id: Int) {
        edit("switch-profile") { $0.switchProfile(to: id, now: $1) }
    }

    func addProfile(_ settings: ProfileSettings) throws {
        try edit("add-profile") { _ = try $0.addProfile(settings, now: $1) }
    }

    func updateProfile(_ settings: ProfileSettings) throws {
        try edit("update-profile") { progress, _ in try progress.updateProfile(settings) }
    }

    /// Deletes the profile playing now and goes back to the guest.
    func deleteProfile() throws {
        let id = game.profile.id
        try edit("delete-profile") { try $0.deleteProfile(id: id, now: $1) }
    }

    func easterEggTap() {
        if eggTaps.tap(at: Date().timeIntervalSince1970) {
            redLevelUnlocked = true
        }
    }

    /// Replaces all progress with a download from the web app, or a copy of this app's file.
    /// The current file is kept beside it first.
    func importProgress(_ data: Data) throws {
        let progress = try ProgressStore.decode(data)
        try store.archive("before-import", now: Date().timeIntervalSince1970)
        revealTask?.cancel()
        game = Game(progress: progress, forcedAnswer: options.answer)
        game.start()
        player.load(game.instrument)
        save()
        DevLog.event("progress.import", ["profiles": "\(progress.state.profiles.count)", "level": game.level])
    }

    /// The right answer stays on screen for the reveal; then the next chord (or, after a streak of 20, the next level) waits for play.
    private func scheduleRevealEnd() {
        revealTask?.cancel()
        revealTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Characters.revealSeconds))
            guard !Task.isCancelled, let self else { return }
            let level = self.game.level
            self.game.revealFinished()
            self.levelChanged(from: level)
            self.save()
        }
    }

    private func levelChanged(from level: String) {
        guard game.level != level else { return }
        // A level-up switched the instrument.
        player.load(game.instrument)
        DevLog.event("game.level-up", ["level": game.level, "instrument": game.instrument.rawValue])
    }

    /// A menu change: ends any reveal, applies it, reloads the instrument (a profile's may be
    /// another) and saves.
    private func edit(_ name: String, _ change: (inout SavedProgress, Double) throws -> Void) rethrows {
        revealTask?.cancel()
        try game.editProgress(change)
        player.load(game.instrument)
        save()
        DevLog.event("menu.\(name)", ["profile": "\(game.profile.id)", "level": game.level,
                                      "instrument": game.instrument.rawValue])
    }

    /// The screen stays on until five minutes after the last play or tap.
    private func noteActivity() {
        lastActivity = Date().timeIntervalSince1970
        updateKeepAwake()
        keepAwakeTask?.cancel()
        keepAwakeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(KeepAwake.window + 1))
            guard !Task.isCancelled else { return }
            self?.updateKeepAwake()
        }
    }

    private func updateKeepAwake() {
        UIApplication.shared.isIdleTimerDisabled =
            KeepAwake.shouldKeepAwake(lastActivity: lastActivity, now: Date().timeIntervalSince1970)
    }

    private func save() {
        do {
            try store.save(game.progress)
        } catch {
            DevLog.event("progress.save-error", ["error": "\(error)"])
        }
    }
}
