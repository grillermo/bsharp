import ElisaKit
import SwiftUI

/// The panels the menu opens. Nil is home: the game.
enum Panel: String {
    case trainer, info, history, profile
}

/// The gear and, once it is tapped, the five items beside it (div.menu-container): home, the
/// piano trainer, the info text, the stats history and the profile. The one showing is blue.
/// Hiding the items also closes the panel, so the game is never left behind one.
struct MenuBar: View {
    @Binding var open: Bool
    @Binding var panel: Panel?
    let profile: Profile
    let metrics: Metrics

    var body: some View {
        HStack(spacing: 12) {
            if open {
                HStack(spacing: metrics.menuSpacing) {
                    item("menu-home", "house.fill", active: panel == nil) { panel = nil }
                    item("menu-trainer", "music.note", active: panel == .trainer) { toggle(.trainer) }
                    item("menu-info", "info.circle.fill", active: panel == .info) { toggle(.info) }
                    item("menu-history", "chart.line.uptrend.xyaxis", active: panel == .history) { toggle(.history) }
                    Button { toggle(.profile) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: ProfileIcons.symbol(for: profile.icon))
                            Text(profile.name).font(Theme.text(metrics.menuIconSize * 1.1))
                        }
                        .foregroundStyle(panel == .profile ? Theme.active : Theme.ink)
                    }
                    .accessibilityIdentifier("menu-profile")
                    .accessibilityValue(panel == .profile ? "active" : "")
                }
                .font(.system(size: metrics.menuIconSize, weight: .semibold))
                .frame(maxWidth: .infinity)
                .transition(.opacity)
            } else {
                Spacer(minLength: 0)
            }
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    open.toggle()
                    if !open { panel = nil }
                }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: metrics.gearIconSize, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: metrics.gearSize, height: metrics.gearSize)
                    .background(Circle().fill(.white).shadow(color: .black.opacity(0.15), radius: 5, y: 4))
            }
            .accessibilityIdentifier("menu-gear")
        }
    }

    private func toggle(_ target: Panel) {
        panel = panel == target ? nil : target
    }

    private func item(_ id: String, _ symbol: String, active: Bool,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).foregroundStyle(active ? Theme.active : Theme.ink)
        }
        .accessibilityIdentifier(id)
        .accessibilityValue(active ? "active" : "")
    }
}
