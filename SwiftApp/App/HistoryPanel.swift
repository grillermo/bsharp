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
                                Text(row.summary).font(Theme.text(20, bold: true))
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
}

#Preview {
    PanelCard {
        HistoryPanel(rows: [HistoryRow(level: "yellow", startTime: 1_793_400_000, correct: 24, answers: 25)])
    }
    .padding()
}
