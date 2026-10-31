import SwiftUI

/// The web app's clamp() sizes (_bluey.scss) for a screen of `size`.
struct Metrics {
    let size: CGSize

    private var vw: CGFloat { size.width / 100 }
    private var vh: CGFloat { size.height / 100 }
    private var vmin: CGFloat { min(size.width, size.height) / 100 }

    var landscape: Bool { size.width > size.height }
    var titleFont: CGFloat { TitleCard.fontSize(for: size) }
    /// .title-card bottom margin: clamp(8px, 2vh, 20px)
    var titleGap: CGFloat { clamp(2 * vh, 8, 20) }
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

    /// #character-reveal img height: portrait min(11vh, 130px), landscape min(30vh, 220px)
    var revealImageHeight: CGFloat { landscape ? min(30 * vh, 220) : min(11 * vh, 130) }
    /// img max-width: portrait 28vw, landscape 38vw
    var revealImageMaxWidth: CGFloat { landscape ? 38 * vw : 28 * vw }
    /// .character-name font: portrait 1.3rem, landscape 1.6rem
    var revealNameFont: CGFloat { landscape ? 25.6 : 20.8 }
    /// top: landscape 0.75rem. Portrait (9vh) stands the character on the flags instead, see HomeView.
    var revealTop: CGFloat { landscape ? 12 : 9 * vh }
    /// right: portrait 0.75rem, landscape 6.5rem (clear of the gear Plan 4 adds)
    var revealTrailing: CGFloat { landscape ? 104 : 12 }

    private func clamp(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat {
        min(high, max(low, value))
    }
}
