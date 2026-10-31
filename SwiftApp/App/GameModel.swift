import ElisaKit
import Foundation
import Observation

/// The main screen's state: the game, its progress file and the chord player.
@MainActor @Observable
final class GameModel {
    private(set) var game: Game
    private let options: LaunchOptions
    private let store: ProgressStore
    private let player = ChordPlayer()
    private var revealTask: Task<Void, Never>?

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
        player.play(game.play())
    }

    func tap(_ color: String) {
        let outcome = game.tap(color)
        guard outcome != .ignored else { return }
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
            if self.game.level != level {
                // A level-up switched the instrument.
                self.player.load(self.game.instrument)
                DevLog.event("game.level-up", ["level": self.game.level,
                                               "instrument": self.game.instrument.rawValue])
            }
            self.save()
        }
    }

    private func save() {
        do {
            try store.save(game.progress)
        } catch {
            DevLog.event("progress.save-error", ["error": "\(error)"])
        }
    }
}
