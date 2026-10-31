import Foundation
import Testing
@testable import ElisaKit

@Suite struct CharacterFilesTests {
    /// bsharp/static/characters, found from this file's path.
    let folder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "static/characters")

    @Test func everyCharacterHasAnImageAndNoImageIsLeftOut() throws {
        for name in Characters.all {
            #expect(FileManager.default.fileExists(atPath: folder.appending(path: "\(name).png").path(percentEncoded: false)), "\(name)")
        }
        let onDisk = try FileManager.default
            .contentsOfDirectory(atPath: folder.path(percentEncoded: false))
            .filter { $0.hasSuffix(".png") }.sorted()
        #expect(onDisk == Characters.all.map { "\($0).png" }.sorted())
    }
}
