import Foundation

/// Ships diagnostic events to the developer's Mac (`scripts/devlog/server.py`)
/// so a device build can be debugged without Xcode. Only `./deploy --devlog`
/// bakes the server URL into Info.plist; every other build has none, and
/// `event` then does nothing, not even build its fields.
///
/// Emitting only appends to a bounded buffer under a lock. Sending happens on a
/// utility queue once a second, and failed batches are dropped, so the code
/// being observed never waits on the network.
public enum DevLog {
    public static let urlInfoKey = "ElisaMusicaDevLogURL"

    private static let sink = DevLogSink(infoDictionary: Bundle.main.infoDictionary)

    public static var isEnabled: Bool { sink != nil }

    public static func event(_ kind: String, _ fields: @autoclosure () -> [String: String] = [:]) {
        sink?.append(kind: kind, fields: fields())
    }

    /// Sends a file (e.g. a screenshot) to the server, stored under
    /// `log/screens/<name>`. Files skip the record buffer, and are dropped when
    /// too many are already in flight.
    public static func upload(_ name: String, _ data: Data) {
        sink?.upload(name: name, data: data)
    }
}

final class DevLogSink: @unchecked Sendable {
    static let maxBufferedRecords = 2_000
    private static let flushInterval: DispatchTimeInterval = .seconds(1)
    private static let maxUploadsInFlight = 4

    private let endpoint: URL
    private let session = UUID().uuidString
    private let build: String
    private let lock = NSLock()
    private var buffer: [[String: Any]] = []
    private let queue = DispatchQueue(label: "elisa-musica.devlog", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var uploadsInFlight = 0

    nonisolated(unsafe) private static let timestamp: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    init?(infoDictionary: [String: Any]?, startsTimer: Bool = true) {
        guard let value = infoDictionary?[DevLog.urlInfoKey] as? String,
              let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              url.host?.isEmpty == false
        else { return nil }
        endpoint = url
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let number = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        build = "\(version) (\(number))"
        if startsTimer { startTimer() }
    }

    func append(kind: String, fields: [String: String]) {
        let record: [String: Any] = [
            "t": Self.timestamp.string(from: Date()),
            "kind": kind,
            "meta": fields,
            "session": session,
            "build": build,
        ]
        lock.lock()
        if buffer.count < Self.maxBufferedRecords { buffer.append(record) }
        lock.unlock()
    }

    /// Empties the buffer and returns what it held.
    func takeBuffered() -> [[String: Any]] {
        lock.lock()
        defer { lock.unlock() }
        let records = buffer
        buffer.removeAll(keepingCapacity: true)
        return records
    }

    func upload(name: String, data: Data) {
        guard var components = URLComponents(url: endpoint.appendingPathComponent("screen"),
                                             resolvingAgainstBaseURL: false) else { return }
        components.queryItems = [URLQueryItem(name: "name", value: name)]
        guard let url = components.url else { return }
        lock.lock()
        guard uploadsInFlight < Self.maxUploadsInFlight else {
            lock.unlock()
            return
        }
        uploadsInFlight += 1
        lock.unlock()
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        URLSession.shared.uploadTask(with: request, from: data) { [weak self] _, _, _ in
            guard let self else { return }
            self.lock.lock()
            self.uploadsInFlight -= 1
            self.lock.unlock()
        }.resume()
    }

    private func startTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + Self.flushInterval, repeating: Self.flushInterval)
        timer.setEventHandler { [weak self] in self?.flush() }
        self.timer = timer
        timer.resume()
    }

    private func flush() {
        let records = takeBuffered()
        guard !records.isEmpty,
              let body = try? JSONSerialization.data(withJSONObject: ["records": records]) else { return }
        var request = URLRequest(url: endpoint, timeoutInterval: 5)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        // Fire and forget: a failed batch is dropped, never retried.
        URLSession.shared.dataTask(with: request).resume()
    }
}
