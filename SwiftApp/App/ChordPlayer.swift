import AVFAudio
import ElisaKit
import QuartzCore

/// Plays the chord recordings with no audible delay: every take of the current instrument is
/// decoded into memory when the instrument is loaded, so a tap only schedules a buffer. One
/// player node is enough because a new chord always cuts off the one sounding (game.ts
/// stopCurrentAudio).
@MainActor
final class ChordPlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    /// Chord id → its takes: three for piano, one for each guitar.
    private var takes: [String: [AVAudioPCMBuffer]] = [:]
    private var instrument: Instrument?

    init() {
        let session = AVAudioSession.sharedInstance()
        // .playback, so the silent switch doesn't mute the game.
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
        engine.attach(player)
    }

    /// Decodes the instrument's recordings and wires the player for their format (piano is
    /// 48 kHz stereo, both guitars 44.1 kHz mono).
    func load(_ instrument: Instrument) {
        guard instrument != self.instrument else { return }
        let started = CACurrentMediaTime()
        var loaded: [String: [AVAudioPCMBuffer]] = [:]
        for chord in Chords.all {
            loaded[chord.id] = ChordFiles.paths(for: instrument, color: chord.id).compactMap(Self.decode)
        }
        guard let format = loaded.values.lazy.compactMap(\.first).first?.format else {
            DevLog.event("audio.load-failed", ["instrument": instrument.rawValue])
            return
        }
        player.stop()
        engine.stop()
        engine.disconnectNodeOutput(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        takes = loaded
        self.instrument = instrument
        startEngine()
        let session = AVAudioSession.sharedInstance()
        DevLog.event("audio.loaded", [
            "instrument": instrument.rawValue,
            "decodeMs": Self.ms(CACurrentMediaTime() - started),
            "outputLatencyMs": Self.ms(session.outputLatency),
            "ioBufferMs": Self.ms(session.ioBufferDuration),
        ])
    }

    /// Cuts off whatever is sounding and plays one take of `color`, picked at random.
    func play(_ color: String) {
        guard let take = takes[color]?.randomElement() else { return }
        let started = CACurrentMediaTime()
        // An interruption (a call, Siri) or a route change stops the engine.
        if !engine.isRunning { startEngine() }
        // Playing a node on a stopped engine raises an Objective-C exception, so stay silent.
        guard engine.isRunning else {
            DevLog.event("audio.play-skipped", ["color": color])
            return
        }
        player.stop()
        player.scheduleBuffer(take, completionHandler: nil)
        player.play()
        DevLog.event("audio.play", ["color": color, "scheduleMs": Self.ms(CACurrentMediaTime() - started)])
    }

    private func startEngine() {
        // An interruption deactivates the session, so bring it back before restarting.
        try? AVAudioSession.sharedInstance().setActive(true)
        do {
            try engine.start()
        } catch {
            DevLog.event("audio.engine-error", ["error": "\(error)"])
        }
    }

    private static func decode(_ path: String) -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.resourceURL?.appending(path: "chords/\(path)"),
              let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil
        else {
            DevLog.event("audio.missing", ["path": path])
            return nil
        }
        return buffer
    }

    private static func ms(_ seconds: Double) -> String {
        String(format: "%.1f", seconds * 1000)
    }
}
