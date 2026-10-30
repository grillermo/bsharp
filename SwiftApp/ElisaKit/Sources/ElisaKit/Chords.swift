/// One chord of the Eguchi method. Children know it only by its flag's color.
public struct Chord: Identifiable, Hashable, Sendable {
    /// The color name. Saved progress and audio file names use it as the key.
    public let id: String
    /// How the level selector names it, e.g. "Amarillo".
    public let spanishName: String
    public let symbol: String
    public let notes: [String]
    /// Flag color as 0xRRGGBB (src/scss/_cim.scss).
    public let hex: UInt32
}

/// The 14 chords in teaching order (src/ts/data.ts). Level N plays the first N+1 of them:
/// red alone is level 0, red + yellow is level 1.
public enum Chords {
    public static let all: [Chord] = [
        Chord(id: "red", spanishName: "Rojo", symbol: "C", notes: ["C4", "E4", "G4"], hex: 0xFF0000),
        Chord(id: "yellow", spanishName: "Amarillo", symbol: "F/C", notes: ["C4", "F4", "A4"], hex: 0xFFFF00),
        Chord(id: "blue", spanishName: "Azul", symbol: "G/B", notes: ["B3", "D4", "G4"], hex: 0x0000FF),
        Chord(id: "black", spanishName: "Negro", symbol: "F/A", notes: ["A3", "C4", "F4"], hex: 0x000000),
        Chord(id: "green", spanishName: "Verde", symbol: "G/D", notes: ["D4", "G4", "B4"], hex: 0x008000),
        Chord(id: "orange", spanishName: "Naranja", symbol: "C/E", notes: ["E4", "G4", "C5"], hex: 0xFF8200),
        Chord(id: "purple", spanishName: "Morado", symbol: "F", notes: ["F4", "A4", "C5"], hex: 0x800080),
        Chord(id: "pink", spanishName: "Rosa", symbol: "G", notes: ["G4", "B4", "D5"], hex: 0xFC0FC0),
        Chord(id: "brown", spanishName: "Café", symbol: "C/G", notes: ["G4", "C5", "E5"], hex: 0x81613C),
        Chord(id: "gray", spanishName: "Gris", symbol: "A", notes: ["A3", "C#4", "E4"], hex: 0x808080),
        Chord(id: "tan", spanishName: "Beige", symbol: "D", notes: ["D4", "F#4", "A4"], hex: 0xF0E68C),
        Chord(id: "lightgreen", spanishName: "Verde claro", symbol: "E", notes: ["E4", "G#4", "B4"], hex: 0x7FFF00),
        Chord(id: "lightpurple", spanishName: "Lila", symbol: "Bb", notes: ["Bb3", "D4", "F4"], hex: 0xDCD0FF),
        Chord(id: "skyblue", spanishName: "Celeste", symbol: "Eb", notes: ["Eb4", "G4", "Bb4"], hex: 0x87CEFA),
    ]

    /// Index of gray, the first chord with a black key.
    public static let firstBlackIndex = 9

    public static let ids: [String] = all.map(\.id)

    /// The chords on screen at `level` (a chord id): every chord up to and including it.
    public static func inPlay(upTo level: String) -> [Chord] {
        guard let index = ids.firstIndex(of: level) else { return [] }
        return Array(all.prefix(index + 1))
    }
}
