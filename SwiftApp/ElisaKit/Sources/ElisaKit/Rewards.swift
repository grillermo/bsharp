/// What a completed streak does to the saved progress (advanceLevel in src/ts/game.ts, plus
/// the instrument switch this app adds).
extension SavedProgress {
    /// Moves to the next level on the other instrument. The new level starts a new session and
    /// a new streak, and the instrument is saved in the profile like a manual choice. Returns
    /// nil at the last level, where nothing moves, the instrument stays and only the streak
    /// starts over.
    @discardableResult
    public mutating func levelUp(now: Double) -> LevelUp? {
        guard let up = Progression.levelUp(from: state.currentChord, instrument: profile.instrument) else {
            profile.streak = 0
            return nil
        }
        changeLevel(to: up.level, now: now)
        profile.currentInstrument = up.instrument.rawValue
        return up
    }
}
