import ElisaKit
import SwiftUI

/// The current profile's past sessions, newest first (#stats-history-container).
struct HistoryPanel: View {
    let rows: [HistoryRow]

    var body: some View {
        if rows.isEmpty {
            Text("Todavía no hay sesiones.")
                .font(Theme.text(18))
                .accessibilityIdentifier("history-empty")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 12) {
                            Rectangle()
                                .fill(Color(hex: Chords.chord(row.level)?.hex ?? 0xFFFFFF))
                                .overlay(Rectangle().strokeBorder(.black, lineWidth: 1))
                                .frame(width: 36, height: 36)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(row.date()).font(Theme.text(16))
                                summary(row.summary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("history-row")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// The face is drawn in the system font: Open Sans has no emoji and the fallback shows a box.
    private func summary(_ text: String) -> Text {
        guard let space = text.lastIndex(of: " ") else {
            return Text(text).font(Theme.text(20, bold: true))
        }
        let score = String(text[..<space])
        let face = String(text[text.index(after: space)...])
        return Text(score + " ").font(Theme.text(20, bold: true)) + Text(face).font(.system(size: 20))
    }
}

#Preview {
    PanelCard {
        HistoryPanel(rows: [HistoryRow(level: "yellow", startTime: 1_793_400_000, correct: 24, answers: 25)])
    }
    .padding()
}
