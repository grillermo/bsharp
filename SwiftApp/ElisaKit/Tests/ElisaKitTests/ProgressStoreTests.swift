import Foundation
import Testing
@testable import ElisaKit

@Suite struct ProgressStoreTests {
    let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    var store: ProgressStore { ProgressStore(url: folder.appending(path: "progress.json")) }

    private func files() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)).sorted()
    }

    @Test func nothingSavedLoadsAsNil() {
        #expect(store.load(now: 1000) == nil)
    }

    @Test func whatIsSavedLoadsBack() throws {
        let progress = try ProgressStore.decode(Fixtures.webExport)
        try store.save(progress)
        #expect(store.load(now: 1000) == progress)
    }

    @Test func anUnreadableFileIsMovedAsideNotLost() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.url)
        #expect(store.load(now: 1000) == nil)
        #expect(try files() == ["progress.unreadable-1000.json"])
    }

    @Test func aPresentButUnreadableFileIsMovedAside() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let original = Data("{\"secret\": true}".utf8)
        try original.write(to: store.url)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: store.url.path(percentEncoded: false))
        defer {
            for name in (try? files()) ?? [] {
                try? FileManager.default.setAttributes([.posixPermissions: 0o644],
                                                       ofItemAtPath: folder.appending(path: name).path(percentEncoded: false))
            }
        }
        // Skip when this user can read a chmod 000 file anyway (e.g. root).
        if (try? Data(contentsOf: store.url)) != nil { return }

        #expect(store.load(now: 1000) == nil)
        #expect(try files() == ["progress.unreadable-1000.json"])
        let moved = folder.appending(path: "progress.unreadable-1000.json")
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: moved.path(percentEncoded: false))
        #expect(try Data(contentsOf: moved) == original)
    }

    @Test func theMovedAsideFileKeepsItsBytes() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let original = Data("not json".utf8)
        try original.write(to: store.url)
        #expect(store.load(now: 1000) == nil)
        #expect(try Data(contentsOf: folder.appending(path: "progress.unreadable-1000.json")) == original)
    }

    @Test func twoArchivesInTheSameSecondBothSucceed() throws {
        try store.save(.fresh(now: 5))
        try store.archive("before-import", now: 2000)
        try store.archive("before-import", now: 2000)
        #expect(try files() == ["progress.before-import-2000-1.json",
                                "progress.before-import-2000.json",
                                "progress.json"])
    }

    @Test func movingAsideNeverOverwritesAnEarlierUnreadableFile() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("first".utf8).write(to: store.url)
        #expect(store.load(now: 1000) == nil)
        try Data("second".utf8).write(to: store.url)
        #expect(store.load(now: 1000) == nil)
        #expect(try Data(contentsOf: folder.appending(path: "progress.unreadable-1000.json")) == Data("first".utf8))
        #expect(try Data(contentsOf: folder.appending(path: "progress.unreadable-1000-1.json")) == Data("second".utf8))
    }

    @Test func archiveKeepsACopyBesideTheFile() throws {
        try store.save(.fresh(now: 5))
        try store.archive("before-import", now: 2000)
        #expect(try files() == ["progress.before-import-2000.json", "progress.json"])
    }

    @Test func archivingNothingDoesNothing() throws {
        try store.archive("before-import", now: 2000)
        #expect(!FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)))
    }

    @Test func aWebAppDownloadDecodes() throws {
        let progress = try ProgressStore.decode(Fixtures.webExport)
        #expect(progress.state.profiles.count == 2)
    }

    @Test func somethingElseDoesNot() {
        #expect(throws: (any Error).self) { try ProgressStore.decode(Data("{\"hello\": 1}".utf8)) }
    }
}
