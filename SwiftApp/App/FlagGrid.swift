import ElisaKit
import SwiftUI

/// The level's flags in rows that share the height left (the #flag-holder grid).
struct FlagGrid: View {
    let chords: [Chord]
    let landscape: Bool
    let gap: CGFloat
    let marked: String?
    let dimmed: Bool
    let noteStyle: NoteDisplay.Style?
    let onTap: (String) -> Void

    var body: some View {
        GeometryReader { geo in
            let columns = FlagLayout.columns(count: chords.count, landscape: landscape)
            let rows = stride(from: 0, to: chords.count, by: columns).map {
                Array(chords[$0..<min($0 + columns, chords.count)])
            }
            let width = (geo.size.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
            let height = (geo.size.height - gap * CGFloat(max(rows.count, 1) - 1)) / CGFloat(max(rows.count, 1))
            VStack(alignment: .leading, spacing: gap) {
                ForEach(rows.indices, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(rows[row]) { chord in
                            Button { onTap(chord.id) } label: {
                                FlagView(chord: chord, marked: marked == chord.id, dimmed: dimmed,
                                         noteStyle: noteStyle)
                            }
                            .buttonStyle(FlagButtonStyle())
                            .frame(width: width, height: height)
                            .accessibilityIdentifier("flag-\(chord.id)")
                            .accessibilityValue(marked == chord.id ? "correct" : dimmed ? "dimmed" : "")
                        }
                    }
                }
            }
        }
    }
}

/// A flag reacts to a tap by sounding its chord, not by changing its look.
struct FlagButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.contentShape(Rectangle())
    }
}

/// One flag: the chord's color, its notes when they show, and the green check on a right answer.
struct FlagView: View {
    let chord: Chord
    let marked: Bool
    let dimmed: Bool
    let noteStyle: NoteDisplay.Style?

    var body: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(Color(hex: chord.hex))
            // The shadow belongs to the flag alone, not to the note shapes on it.
            .shadow(color: .black.opacity(0.15), radius: 0, y: 5)
            .overlay {
                if let noteStyle {
                    NoteMarks(marks: NoteDisplay.marks(for: chord, shapes: noteStyle.shapes),
                              letters: noteStyle.letters)
                }
            }
            .overlay {
                if marked {
                    CorrectCheck()
                    // div.flag-correct: outline 4px solid green, outside the flag.
                    RoundedRectangle(cornerRadius: 26)
                        .strokeBorder(Theme.correctGreen, lineWidth: 4)
                        .padding(-4)
                }
            }
            // #flag-holder.awaiting-play .flag: grayscale(1), opacity 0.4.
            .grayscale(dimmed ? 1 : 0)
            .opacity(dimmed ? 0.4 : 1)
    }
}

/// i.answer-icon.correct: a green check outlined in black, a little see-through.
struct CorrectCheck: View {
    private static let outline: [CGSize] = (0..<12).map { step in
        let angle = Double(step) / 12 * 2 * .pi
        return CGSize(width: cos(angle) * 2.5, height: sin(angle) * 2.5)
    }

    private var mark: some View {
        Image(systemName: "checkmark").font(.system(size: 76, weight: .black))
    }

    var body: some View {
        ZStack {
            ForEach(Array(Self.outline.enumerated()), id: \.offset) { item in
                mark.foregroundStyle(.black).offset(item.element)
            }
            mark.foregroundStyle(Theme.correctGreen)
        }
        .opacity(0.75)
    }
}
