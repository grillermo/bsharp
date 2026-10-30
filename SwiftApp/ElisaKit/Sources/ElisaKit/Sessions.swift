/// Session bookkeeping (src/ts/game.ts, state.ts, stats.ts, session_cleanup.ts). Times are
/// Unix seconds, passed in so tests can pin them.
extension SavedProgress {
    /// Most answers the adaptive weights look back over (RECENT_IDENTIFICATIONS_LIMIT).
    static let recentAnswerLimit = 140.0

    /// The profile playing now. Falls back to the guest profile, as getCurrentProfile() does.
    public var profile: Profile {
        get {
            state.profiles[String(state.currentProfile)]
                ?? state.profiles[String(Defaults.guestProfileID)]
                ?? Profile.guest(now: 0)
        }
        set { state.profiles[String(newValue.id)] = newValue }
    }

    public static func isRecent(_ timestamp: Double, now: Double) -> Bool {
        now - timestamp <= Defaults.sessionTimeout
    }

    /// The current profile's sessions at the level in play, oldest first.
    public var levelHistory: [SessionStats] {
        get { history[String(profile.id)]?[state.currentChord] ?? [] }
        set { history[String(profile.id), default: [:]][state.currentChord] = newValue }
    }

    /// Files the current session in the level's history, once (saveSessionHistory).
    public mutating func saveSession() {
        let stats = profile.stats
        if levelHistory.last?.startTime != stats.startTime {
            levelHistory.append(stats)
        }
    }

    /// Ends the current session and starts a new one (resetStats). `done` marks a session that
    /// is over; an unfinished one, left by a level change, can be resumed.
    public mutating func resetStats(done: Bool, now: Double) {
        profile.stats.done = done
        if !done || profile.stats.identifications > 0 {
            saveSession()
        }
        profile.stats = SessionStats(currentChord: state.currentChord, now: now)
    }

    /// Picks up the level's last unfinished session, and ends it at once if it is stale
    /// (retrieveSavedStats).
    public mutating func resumeSession(now: Double) {
        guard let last = levelHistory.last, !last.done else { return }
        profile.stats = levelHistory.removeLast()
        if !Self.isRecent(last.updatedTime, now: now) {
            resetStats(done: true, now: now)
        }
    }

    /// Puts `level` in play for the current profile (changeSelector). A new level starts a new
    /// streak; the session at the old level is parked, unfinished.
    public mutating func changeLevel(to level: String, now: Double) {
        if profile.currentChord != level {
            profile.streak = 0
        }
        guard state.currentChord != level else { return }
        resetStats(done: false, now: now)
        state.currentChord = level
        profile.currentChord = level
        profile.stats.currentChord = level
        resumeSession(now: now)
    }

    /// Counts an answer: the stats, the confusion matrix and the streak (updateStartTimeIfNeeded,
    /// updateStats, nextStreak). Returns whether it was right.
    @discardableResult
    public mutating func recordAnswer(played: String, chosen: String, now: Double) -> Bool {
        let correct = played == chosen
        var current = profile
        if current.stats.identifications == 0 {
            current.stats.startTime = now
        }
        current.stats.identifications += 1
        if correct {
            current.stats.correct += 1
        }
        current.stats.confusionMatrix[played, default: [:]][chosen, default: 0] += 1
        current.stats.updatedTime = now
        current.streak = Streak.next(current.streak ?? 0, correct: correct)
        profile = current
        return correct
    }

    /// Drops broken, empty and duplicate sessions from every profile's history
    /// (cleanSessionHistory).
    public mutating func cleanHistory(now: Double) {
        for (profileID, levels) in history {
            var cleaned: [String: [SessionStats]] = [:]
            for (level, sessions) in levels where !level.isEmpty {
                var kept: [SessionStats] = []
                for var session in sessions
                where session.identifications > 0 || (!session.done && Self.isRecent(session.updatedTime, now: now)) {
                    session.currentChord = level
                    if let last = kept.last, last.identifications == session.identifications,
                       last.startTime == session.startTime {
                        continue
                    }
                    kept.append(session)
                }
                cleaned[level] = kept
            }
            history[profileID] = cleaned
        }
    }

    /// The adaptive weight of each chord in play, from the level's most recent answers
    /// (getCurrentCoefficients).
    public func adaptiveWeights() -> [Double] {
        var matrices: [ConfusionMatrix] = []
        var remaining = Self.recentAnswerLimit
        for session in levelHistory.reversed() where remaining > 0 {
            let count = session.confusionMatrix.values.flatMap(\.values).reduce(0, +)
            if count == 0 { continue }
            if count <= remaining {
                matrices.append(session.confusionMatrix)
                remaining -= count
            } else {
                let scale = remaining / count
                matrices.append(session.confusionMatrix.mapValues { $0.mapValues { $0 * scale } })
                remaining = 0
            }
        }
        let chords = Chords.inPlay(upTo: state.currentChord).map(\.id)
        return AdaptiveWeights.coefficients(AdaptiveWeights.merge(matrices, chords: chords), chords: chords)
    }

    /// What the web app does when the page opens (main.ts): back on a known profile, a stale
    /// session ended, the profile's level in play, the history cleaned.
    public mutating func launch(now: Double) {
        if state.profiles[String(state.currentProfile)] == nil {
            state.currentProfile = Defaults.guestProfileID
            if state.profiles[String(Defaults.guestProfileID)] == nil {
                profile = Profile.guest(now: now)
            }
        }
        if !Self.isRecent(profile.stats.updatedTime, now: now) {
            resetStats(done: true, now: now)
        }
        // A level this app doesn't know (a newer web version, a hand-edited file) falls back to
        // the default before it is put in play. Fixing the profile first keeps its streak.
        if !Chords.ids.contains(profile.currentChord) {
            profile.currentChord = Defaults.level
        }
        changeLevel(to: profile.currentChord, now: now)
        cleanHistory(now: now)
    }
}
