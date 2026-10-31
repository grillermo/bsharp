/// Whether the screen stays on (UIApplication.isIdleTimerDisabled): from a play or a tap until
/// five minutes after the last one, so a session never dims mid-chord but a forgotten iPad
/// still locks.
public enum KeepAwake {
    public static let window = 5.0 * 60

    public static func shouldKeepAwake(lastActivity: Double?, now: Double) -> Bool {
        guard let lastActivity else { return false }
        return now - lastActivity < window
    }
}
