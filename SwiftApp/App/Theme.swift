import SwiftUI

/// The web app's bluey.tv look (src/scss/_bluey.scss).
enum Theme {
    static let ink = Color(hex: 0x5A5A87)
    static let edge = Color(hex: 0xABE0FA)
    static let skyTop = Color(hex: 0x8FD3FB)
    static let skyBottom = Color(hex: 0xC2E3FE)
    static let grass = Color(hex: 0xDBE98A)
    /// $bluey-grass darkened 12%, the bottom of the grass gradient.
    static let grassDark = Color(hex: 0xCBDF56)
    /// $bluey-ink-pressed: the round buttons' lower edge.
    static let inkPressed = Color(hex: 0x4E4E7A)
    /// Note shapes (div.note: #333 at 95 %) and their letters ($fg-color-dark).
    static let noteInk = Color(hex: 0x333333)
    static let noteLetter = Color(hex: 0xDADADA)
    /// The outline and check of a right answer.
    static let correctGreen = Color(hex: 0x008000)

    static func headline(_ size: CGFloat) -> Font { .custom("HelloHeadline", size: size) }

    static func text(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "OpenSans-Bold" : "OpenSans-Regular", size: size)
    }
}

extension Color {
    /// 0xRRGGBB, as in the SCSS and in `Chord.hex`.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
