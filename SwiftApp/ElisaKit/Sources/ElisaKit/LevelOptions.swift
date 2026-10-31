/// One option of the level picker.
public struct LevelOption: Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
}

/// The level selector's options (index.html #chord-selector).
public enum LevelOptions {
    private static let solfegeNames: [Character: String] = [
        "C": "Do", "D": "Re", "E": "Mi", "F": "Fa", "G": "Sol", "A": "La", "B": "Si",
    ]

    /// "C#4" → "Do♯", "Bb3" → "Si♭", "G4" → "Sol".
    public static func solfege(_ note: String) -> String {
        guard let letter = note.first, let name = solfegeNames[letter] else { return note }
        switch note.dropFirst().first {
        case "#": return name + "♯"
        case "b": return name + "♭"
        default: return name
        }
    }

    /// "Nivel 1: Amarillo (Do Fa La)". White levels count from red (0), black ones from gray (1).
    public static func label(for chord: Chord) -> String {
        let index = Chords.ids.firstIndex(of: chord.id) ?? 0
        let number = index >= Chords.firstBlackIndex ? index - Chords.firstBlackIndex + 1 : index
        let notes = chord.notes.map(solfege).joined(separator: " ")
        return "Nivel \(number): \(chord.spanishName) (\(notes))"
    }

    /// "Acordes blancos". Red only once it is unlocked (ui.ts triggerEasterEgg) or already the level.
    public static func white(includingRed: Bool) -> [LevelOption] {
        Chords.all.prefix(Chords.firstBlackIndex)
            .filter { includingRed || $0.id != "red" }
            .map { LevelOption(id: $0.id, label: label(for: $0)) }
    }

    /// "Acordes negros".
    public static var black: [LevelOption] {
        Chords.all.dropFirst(Chords.firstBlackIndex).map { LevelOption(id: $0.id, label: label(for: $0)) }
    }
}

extension Chords {
    public static func chord(_ id: String) -> Chord? {
        all.first { $0.id == id }
    }
}

extension Instrument {
    /// As the instrument selector names it.
    public var spanishName: String {
        switch self {
        case .piano: "Piano"
        case .guitar: "Guitarra"
        case .guitarStrummed: "Guitarra (rasgueo)"
        }
    }
}
