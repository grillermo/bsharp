import ElisaKit
import SwiftUI

/// A flag's three notes on a diagonal, low note bottom left to high note top right
/// (.chord-notes-container), each a dark shape with its letter.
struct NoteMarks: View {
    let marks: [NoteMark]
    let letters: Bool

    /// body font-size: 1.8em (1.6em up to 768 px wide) of 16 px; a note is 2em square.
    private var em: CGFloat { UIScreen.main.bounds.width <= 768 ? 25.6 : 28.8 }

    var body: some View {
        GeometryReader { geo in
            // div.chord-notes-container: width min(100%, 10em), height min(10rem, 100%), centred
            // in the flag. The three 2em notes shrink in width only when the flag is narrow.
            let containerWidth = min(geo.size.width, 10 * em)
            let containerHeight = min(160, geo.size.height)
            let noteWidth = min(2 * em, containerWidth / 3)
            let noteHeight = min(2 * em, containerHeight)
            let gap = (containerWidth - 3 * noteWidth) / 3 // justify-content: space-around
            let left = (geo.size.width - containerWidth) / 2
            let top = (geo.size.height - containerHeight) / 2
            let ys: [CGFloat] = [top + containerHeight - noteHeight / 2,
                                 top + containerHeight / 2,
                                 top + noteHeight / 2] // low note bottom, high note top
            let step: CGFloat = noteWidth + gap
            let x0: CGFloat = left + gap / 2 + noteWidth / 2
            let centers: [CGPoint] = (0..<3).map { index in
                CGPoint(x: x0 + CGFloat(index) * step, y: ys[index])
            }
            ForEach(Array(zip(marks, centers).enumerated()), id: \.offset) { item in
                NoteMarkView(mark: item.element.0, width: noteWidth, height: noteHeight,
                             letterSize: 1.2 * em, letters: letters)
                    .position(item.element.1)
            }
        }
    }
}

struct NoteMarkView: View {
    let mark: NoteMark
    let width: CGFloat
    let height: CGFloat
    let letterSize: CGFloat
    let letters: Bool

    var body: some View {
        ZStack {
            Image("note-\(mark.shape.rawValue)")
                .renderingMode(.template)
                .resizable()
                .foregroundStyle(Theme.noteInk.opacity(0.95))
                .frame(width: width * mark.scale, height: height * mark.scale)
            if letters {
                Text(mark.letter)
                    .font(Theme.text(letterSize, bold: true))
                    .foregroundStyle(Theme.noteLetter)
                    // B♭ is wider than its shape, as on the web; never let it truncate to "…".
                    .lineLimit(1)
                    .fixedSize()
                    // The CSS nudge is a share of the letter's own box.
                    .offset(x: letterSize * mark.letterDX, y: letterSize * mark.letterDY)
            }
        }
        .frame(width: width, height: height)
    }
}
