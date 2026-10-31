import SwiftUI

/// A white card with a pale-blue ring (#panel-area > .panel), in place of the flags and the
/// play button while a panel is open.
struct PanelCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .foregroundStyle(Theme.ink)
            .background(RoundedRectangle(cornerRadius: 28).fill(.white))
            // box-shadow: 0 0 0 6px $bluey-edge
            .background(RoundedRectangle(cornerRadius: 34).fill(Theme.edge).padding(-6))
    }
}
