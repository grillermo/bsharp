/// The chord recordings in static/chords/ (src/ts/data.ts AUDIO_FILE_LIST), as paths under the
/// bundle's `chords/` folder. Piano has three takes per chord; each guitar has one.
public enum ChordFiles {
    /// File names spell the notes German style: h is B, s is sharp ("acse" is A C♯ E).
    static let pianoNotes = [
        "red": "ceg", "yellow": "cfa", "blue": "hdg", "black": "acf", "green": "dgh",
        "orange": "egc", "purple": "fac", "pink": "ghd", "brown": "gce", "gray": "acse",
        "tan": "dfsa", "lightgreen": "egsh", "lightpurple": "asdf", "skyblue": "dsgas",
    ]
    static let guitarNotes = [
        "red": "c4e4g4", "yellow": "c4f4a4", "blue": "h3d4g4", "black": "a3c4f4", "green": "d4g4h4",
        "orange": "e4g4c5", "purple": "f4a4c5", "pink": "g4h4d5", "brown": "g4c5e5", "gray": "a3cs4e4",
        "tan": "d4fs4a4", "lightgreen": "e4gs4h4", "lightpurple": "as3d4f4", "skyblue": "ds4g4as4",
    ]

    public static func paths(for instrument: Instrument, color: String) -> [String] {
        switch instrument {
        case .piano:
            guard let notes = pianoNotes[color] else { return [] }
            return ["short", "medium", "long"].map { "piano/\(notes)_\(color)_\($0).mp3" }
        case .guitar, .guitarStrummed:
            guard let notes = guitarNotes[color] else { return [] }
            return ["\(instrument.chordFolder)/\(notes)_\(color).mp3"]
        }
    }
}
