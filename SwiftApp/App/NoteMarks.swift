import ElisaKit
import SwiftUI

/// A flag's three notes on a diagonal, low note bottom left to high note top right
/// (.chord-notes-container), each a dark shape with its letter.
struct NoteMarks: View {
    let marks: [NoteMark]
    let letters: Bool

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let size = min(height * 0.3, width * 0.22)
            let inset = height * 0.03
            let centers = [
                CGPoint(x: width / 6, y: height - inset - size / 2),
                CGPoint(x: width / 2, y: height / 2),
                CGPoint(x: width * 5 / 6, y: inset + size / 2),
            ]
            ForEach(Array(zip(marks, centers).enumerated()), id: \.offset) { item in
                NoteMarkView(mark: item.element.0, size: size, letters: letters)
                    .position(item.element.1)
            }
        }
    }
}

struct NoteMarkView: View {
    let mark: NoteMark
    let size: CGFloat
    let letters: Bool

    var body: some View {
        ZStack {
            Image("note-\(mark.shape.rawValue)")
                .renderingMode(.template)
                .resizable()
                .foregroundStyle(Theme.noteInk.opacity(0.95))
                .frame(width: size * mark.scale, height: size * mark.scale)
            if letters {
                Text(mark.letter)
                    .font(Theme.text(size * 0.6, bold: true))
                    .foregroundStyle(Theme.noteLetter)
                    // The CSS nudge is a share of the letter's own box, about 0.6 of the shape.
                    .offset(x: size * 0.6 * mark.letterDX, y: size * 0.6 * mark.letterDY)
            }
        }
        .frame(width: size, height: size)
    }
}
