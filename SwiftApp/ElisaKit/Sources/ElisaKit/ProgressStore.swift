import Foundation

/// The saved progress on disk: one JSON file in the shape of the web app's state download
/// (`{"state": …, "history": …}`), so a download from bluey.chiq.me imports as is.
public struct ProgressStore: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// Application Support/ElisaMusica/progress.json
    public static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "ElisaMusica/progress.json")
    }

    /// The saved progress, or nil when there is none. A file that can't be read is moved aside
    /// (`progress.unreadable-<time>.json`) so the next save doesn't overwrite it.
    public func load(now: Double) -> SavedProgress? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        if let progress = try? Self.decode(data) { return progress }
        try? FileManager.default.moveItem(at: url, to: sibling("unreadable", now: now))
        return nil
    }

    public func save(_ progress: SavedProgress) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Self.encode(progress).write(to: url, options: .atomic)
    }

    /// Copies the file to `progress.<label>-<time>.json`, e.g. before an import replaces it.
    public func archive(_ label: String, now: Double) throws {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        try FileManager.default.copyItem(at: url, to: sibling(label, now: now))
    }

    /// A web app download, or a copy of this app's own file.
    public static func decode(_ data: Data) throws -> SavedProgress {
        try JSONDecoder().decode(SavedProgress.self, from: data)
    }

    public static func encode(_ progress: SavedProgress) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(progress)
    }

    private func sibling(_ label: String, now: Double) -> URL {
        url.deletingLastPathComponent().appending(path: "progress.\(label)-\(Int(now)).json")
    }
}
