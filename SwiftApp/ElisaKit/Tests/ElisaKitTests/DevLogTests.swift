import Foundation
import Testing
@testable import ElisaKit

@Suite struct DevLogTests {
    private let enabled: [String: Any] = [
        DevLog.urlInfoKey: "http://macmini.local:19482/api/devlog",
        "CFBundleShortVersionString": "1.0.4",
        "CFBundleVersion": "6",
    ]

    @Test func staysOffWithoutAUsableURL() {
        #expect(DevLogSink(infoDictionary: nil) == nil)
        #expect(DevLogSink(infoDictionary: [DevLog.urlInfoKey: ""]) == nil)
        #expect(DevLogSink(infoDictionary: [DevLog.urlInfoKey: "$(ELISA_MUSICA_DEVLOG_URL)"]) == nil)
        #expect(DevLogSink(infoDictionary: [DevLog.urlInfoKey: "ftp://macmini.local/api/devlog"]) == nil)
    }

    @Test func turnsOnWithAnHTTPURL() {
        #expect(DevLogSink(infoDictionary: enabled, startsTimer: false) != nil)
    }

    @Test func disabledEventDoesNotBuildItsFields() {
        // The test runner's Info.plist has no DevLog URL, so DevLog is off.
        #expect(!DevLog.isEnabled)
        var built = false
        func fields() -> [String: String] { built = true; return [:] }
        DevLog.event("test", fields())
        #expect(!built)
    }

    @Test func recordsCarryKindFieldsSessionBuildAndTime() throws {
        let sink = try #require(DevLogSink(infoDictionary: enabled, startsTimer: false))
        sink.append(kind: "game.start", fields: ["phase": "fast"])
        sink.append(kind: "game.advance", fields: [:])

        let records = sink.takeBuffered()
        #expect(records.count == 2)
        let first = records[0]
        #expect(first["kind"] as? String == "game.start")
        #expect(first["meta"] as? [String: String] == ["phase": "fast"])
        #expect(first["build"] as? String == "1.0.4 (6)")
        #expect((first["t"] as? String)?.isEmpty == false)
        #expect(first["session"] as? String == records[1]["session"] as? String)
        #expect(sink.takeBuffered().isEmpty)
    }

    @Test func bufferIsBounded() throws {
        let sink = try #require(DevLogSink(infoDictionary: enabled, startsTimer: false))
        for i in 0..<(DevLogSink.maxBufferedRecords + 50) {
            sink.append(kind: "n", fields: ["i": "\(i)"])
        }
        #expect(sink.takeBuffered().count == DevLogSink.maxBufferedRecords)
    }
}
