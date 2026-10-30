import Foundation

/// The shape a note is drawn with (src/scss/_note-shapes.scss). Raw values are the asset names
/// after "note-".
public enum NoteShape: String, CaseIterable, Sendable {
    case circle, triangle, triangleDown = "triangle-down", moon, moonFlipped = "moon-flipped"
    case heart, heartDown = "heart-down", pentagon, hexagon, octagon
    case roundedSquare = "rounded-square", roundedDiamond = "rounded-diamond", teardrop
    case trapezoid, trapezoidDown = "trapezoid-down", star, clover, cloverRotated = "clover-rotated"
}

/// One note drawn on a flag.
public struct NoteMark: Equatable, Sendable {
    /// With its octave, e.g. "C#4".
    public let note: String
    /// What is printed, e.g. "C♯".
    public let letter: String
    public let shape: NoteShape
    /// Moves the letter onto the shape's visual centre, as a share of the letter's size
    /// (the CSS translate on .note-text-span).
    public let letterDX: Double
    public let letterDY: Double
    /// The star is drawn bigger than the rest (2.5em instead of 2em).
    public let scale: Double
}

/// Which notes a flag shows and how (ui.ts setChordDisplayMode/populateFlags, game.ts
/// changeSelector).
public enum NoteDisplay {
    public struct Style: Equatable, Sendable {
        public let shapes: Bool
        public let letters: Bool

        public init(shapes: Bool, letters: Bool) {
            self.shapes = shapes
            self.letters = letters
        }
    }

    /// chord_display_mode: shapes_and_letters (the default), shapes_only or letters_only.
    public static func style(for mode: String) -> Style {
        Style(shapes: mode != "letters_only", letters: mode != "shapes_only")
    }

    /// A level with black-key chords: gray onwards.
    public static func isBlackLevel(_ level: String) -> Bool {
        (Chords.ids.firstIndex(of: level) ?? 0) >= Chords.firstBlackIndex
    }

    /// Whether the level's flags carry notes at all (show_chord_mode: always, black_only, never).
    public static func chordsOn(showChordMode: String, level: String) -> Bool {
        showChordMode == "always" || (showChordMode == "black_only" && isBlackLevel(level))
    }

    /// Whether the notes are drawn right now. With reveal_chord_mode after_guess they show only
    /// while a right answer is on screen.
    public static func notesVisible(profile: Profile, level: String, answerShown: Bool) -> Bool {
        guard chordsOn(showChordMode: profile.showChordMode, level: level) else { return false }
        return profile.revealChordMode != "after_guess" || answerShown
    }

    /// The chord's notes, low to high. Without shapes every note is a plain circle.
    public static func marks(for chord: Chord, shapes: Bool) -> [NoteMark] {
        chord.notes.map { note in
            let look = shapes ? (looks[note] ?? Look(shape: .circle)) : Look(shape: .circle)
            return NoteMark(note: note, letter: letter(for: note), shape: look.shape,
                            letterDX: look.dx, letterDY: look.dy, scale: look.scale)
        }
    }

    /// "C#4" → "C♯", "Bb3" → "B♭".
    public static func letter(for note: String) -> String {
        String(note.filter { !$0.isNumber })
            .replacingOccurrences(of: "#", with: "♯")
            .replacingOccurrences(of: "b", with: "♭")
    }

    private struct Look {
        let shape: NoteShape
        var dx = 0.0
        var dy = 0.0
        var scale = 1.0
    }

    /// div.use-shapes in _note-shapes.scss: the clip path and letter nudge of each note.
    private static let looks: [String: Look] = [
        "A3": Look(shape: .triangleDown, dy: -0.10),
        "A4": Look(shape: .triangle, dy: 0.10),
        "B3": Look(shape: .roundedDiamond, dx: 0.07, dy: 0.02),
        "B4": Look(shape: .roundedSquare),
        "Bb3": Look(shape: .trapezoid, dy: 0.05),
        "Bb4": Look(shape: .trapezoidDown, dy: -0.07),
        "C4": Look(shape: .moon, dx: -0.20, dy: 0.12),
        "C5": Look(shape: .moonFlipped, dx: 0.20, dy: 0.12),
        "C#4": Look(shape: .pentagon, dy: 0.10),
        "D4": Look(shape: .clover),
        "D5": Look(shape: .cloverRotated, dx: 0.05),
        "E4": Look(shape: .heart, dx: -0.05),
        "E5": Look(shape: .heartDown, dx: -0.05, dy: 0.05),
        "Eb4": Look(shape: .teardrop, dx: 0.09, dy: 0.10),
        "F4": Look(shape: .circle),
        "F#4": Look(shape: .hexagon),
        "G4": Look(shape: .octagon),
        "G#4": Look(shape: .star, scale: 1.25),
    ]
}
