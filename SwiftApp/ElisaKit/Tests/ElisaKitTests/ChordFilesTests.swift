import Foundation
import Testing
@testable import ElisaKit

@Suite struct ChordFilesTests {
    /// bsharp/static/chords, found from this file's path.
    let chordsFolder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "static/chords")

    @Test func pianoHasThreeTakesAndEachGuitarOne() {
        #expect(ChordFiles.paths(for: .piano, color: "red") == [
            "piano/ceg_red_short.mp3", "piano/ceg_red_medium.mp3", "piano/ceg_red_long.mp3",
        ])
        #expect(ChordFiles.paths(for: .guitar, color: "gray") == ["guitar/a3cs4e4_gray.mp3"])
        #expect(ChordFiles.paths(for: .guitarStrummed, color: "skyblue") == ["guitar-strummed/ds4g4as4_skyblue.mp3"])
        #expect(ChordFiles.paths(for: .piano, color: "nope").isEmpty)
    }

    @Test func everyRecordingExistsAndNoneIsLeftOut() throws {
        let paths = Instrument.allCases.flatMap { instrument in
            Chords.ids.flatMap { ChordFiles.paths(for: instrument, color: $0) }
        }
        #expect(paths.count == 70)
        for path in paths {
            #expect(FileManager.default.fileExists(atPath: chordsFolder.appending(path: path).path(percentEncoded: false)), "\(path)")
        }
        var onDisk = 0
        for folder in ["piano", "guitar", "guitar-strummed"] {
            onDisk += try FileManager.default
                .contentsOfDirectory(atPath: chordsFolder.appending(path: folder).path(percentEncoded: false))
                .filter { $0.hasSuffix(".mp3") }.count
        }
        #expect(onDisk == 70)
    }
}
