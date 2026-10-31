import SwiftUI

/// The web app's clamp() sizes (_bluey.scss) for a screen of `size`.
struct Metrics {
    let size: CGSize

    private var vw: CGFloat { size.width / 100 }
    private var vh: CGFloat { size.height / 100 }
    private var vmin: CGFloat { min(size.width, size.height) / 100 }

    var landscape: Bool { size.width > size.height }
    /// div.controls a: clamp(56px, min(14vmin, 11vh), 104px)
    var buttonSize: CGFloat { clamp(min(14 * vmin, 11 * vh), 56, 104) }
    /// div.controls i.fa: clamp(26px, min(6.5vmin, 5vh), 48px)
    var iconSize: CGFloat { clamp(min(6.5 * vmin, 5 * vh), 26, 48) }
    /// Both buttons' side margins: 2 × clamp(8px, 3vw, 14px)
    var buttonSpacing: CGFloat { 2 * clamp(3 * vw, 8, 14) }
    /// .control-wrapper bottom padding: clamp(6px, 1.5vh, 16px)
    var controlsGap: CGFloat { clamp(1.5 * vh, 6, 16) }
    /// .onboarding-arrow: clamp(1.8rem, 5vh, 3rem)
    var arrowSize: CGFloat { clamp(5 * vh, 28.8, 48) }
    /// #flag-holder gap: clamp(6px, 1.5vmin, 14px)
    var flagGap: CGFloat { clamp(1.5 * vmin, 6, 14) }
    /// div.hamburger a: clamp(40px, 10vmin, 56px) across, its gear clamp(24px, 6vmin, 3rem).
    var gearSize: CGFloat { clamp(10 * vmin, 40, 56) }
    var gearIconSize: CGFloat { clamp(6 * vmin, 24, 48) }
    /// The five menu icons and the gaps between them (about 25 pt and 33 pt on the iPad mini).
    var menuIconSize: CGFloat { clamp(3.4 * vmin, 20, 30) }
    var menuSpacing: CGFloat { clamp(4.5 * vmin, 14, 44) }

    /// #character-reveal --reveal-h: portrait min(7vh, 80px), landscape min(19vh, 140px)
    var revealHeight: CGFloat { landscape ? min(19 * vh, 140) : min(7 * vh, 80) }
    /// .character-oval width: 2.05 x --reveal-h, capped at portrait 30vw, landscape 40vw
    var revealOvalWidth: CGFloat { min(revealHeight * 2.05, landscape ? 40 * vw : 30 * vw) }
    /// .character-oval aspect-ratio 2.05 / 1.45
    var revealOvalHeight: CGFloat { revealOvalWidth / 2.05 * 1.45 }
    /// .character-name font: portrait 1.3rem, landscape 1.6rem
    var revealNameFont: CGFloat { landscape ? 25.6 : 20.8 }
    /// top: landscape 0.75rem. Portrait (9vh) stands the character on the flags instead, see HomeView.
    var revealTop: CGFloat { landscape ? 12 : 9 * vh }
    /// right: portrait 0.75rem, landscape 6.5rem
    var revealTrailing: CGFloat { landscape ? 104 : 12 }

    private func clamp(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat {
        min(high, max(low, value))
    }
}
