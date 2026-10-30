/// The hidden gesture in front of parent-only actions (ui.ts enableDownload): six taps, each
/// within 1.5 s of the one before.
public struct TapUnlock: Sendable {
    private var count = 0
    private var last: Double?

    public init() {}

    /// Counts a tap at `time` (seconds). True on the tap that unlocks; the count then starts over.
    public mutating func tap(at time: Double) -> Bool {
        if let last, time - last > 1.5 {
            count = 0
        }
        last = time
        count += 1
        guard count >= 6 else { return false }
        count = 0
        return true
    }
}
