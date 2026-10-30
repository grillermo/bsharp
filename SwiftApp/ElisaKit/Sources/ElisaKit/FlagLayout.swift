/// Columns of the flag grid (#flag-holder in _bluey.scss): one wide flag per row while there
/// are few, more columns as flags are added, and more again when the screen is wider than tall.
public enum FlagLayout {
    public static func columns(count: Int, landscape: Bool) -> Int {
        if landscape { return count > 9 ? 5 : 3 }
        if count < 4 { return 1 }
        return count > 9 ? 3 : 2
    }
}
