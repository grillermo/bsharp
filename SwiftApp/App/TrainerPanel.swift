import ElisaKit
import SwiftUI

/// Every chord's flag, to hear any of them without it counting (#trainer-infobox): three per
/// row (five when wider than tall), the last row spread out, all fitting without a scroll.
struct TrainerPanel: View {
    let landscape: Bool
    let onTap: (String) -> Void

    var body: some View {
        GeometryReader { geo in
            let columns = landscape ? 5 : 3
            let rows = stride(from: 0, to: Chords.all.count, by: columns).map {
                Array(Chords.all[$0..<min($0 + columns, Chords.all.count)])
            }
            let gap: CGFloat = 16
            let width = (geo.size.width - gap * CGFloat(columns)) / CGFloat(columns)
            let height = min(width * 0.8,
                             (geo.size.height - gap * CGFloat(rows.count - 1)) / CGFloat(rows.count))
            VStack(spacing: gap) {
                ForEach(rows.indices, id: \.self) { row in
                    // Half a gap either side of each flag: full rows fill the width, the last
                    // row spreads out (justify-content: space-around).
                    HStack(spacing: 0) {
                        ForEach(rows[row]) { chord in
                            Spacer(minLength: gap / 2)
                            Button { onTap(chord.id) } label: {
                                Rectangle()
                                    .fill(Color(hex: chord.hex))
                                    .overlay(Rectangle().strokeBorder(.black, lineWidth: 2))
                            }
                            .buttonStyle(FlagButtonStyle())
                            .frame(width: width, height: height)
                            .accessibilityIdentifier("trainer-\(chord.id)")
                            Spacer(minLength: gap / 2)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

#Preview { PanelCard { TrainerPanel(landscape: false, onTap: { _ in }) }.padding() }
