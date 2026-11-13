// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import Foundation
import KlickEngine

/// What to write: the settings of the file.
public struct AudioExportOptions: Equatable, Sendable {
    public enum BitDepth: Int, CaseIterable, Sendable { case int16 = 16, int24 = 24, float32 = 32 }

    public var rate = 48000
    public var bitDepth = BitDepth.int24
    /// The count-in of the settings is written before the clicks, heard.
    public var includeCountIn = false
    public init() {}
}

/// What is rendered: a number of bars of the metronome, or the tempo map from a bar.
public enum ExportSource: Equatable, Sendable {
    case metronome(bars: Int)
    case map(fromBar: Int)
}

/// Writes the clicks to a WAV file by running the engine without an output device: the file is what the speaker would play, as fast
/// as the machine can compute it. One channel.
public enum AudioExporter {
    public struct Failure: Error, LocalizedError, Equatable {
        public let message: String
        public var errorDescription: String? { message }
    }

    /// Renders to `url`. `progress` is called with a number from 0 to 1 now and then; `isCancelled` is asked at each block, and
    /// a cancelled export removes its file and throws `CancellationError`.
    public static func export(source: ExportSource, settings: ClickSettings, map: [MapSection], options: AudioExportOptions,
                              soundsDirectory: URL, to url: URL,
                              progress: (Double) -> Void = { _ in }, isCancelled: () -> Bool = { false }) throws {
        let engine = try Engine(offline: true, rate: options.rate)
        let files = settings.soundFiles(in: soundsDirectory)
        try engine.loadSound(accent: files.accent, normal: files.normal, accentVolume: settings.accentVolume, normalVolume: settings.normalVolume,
                             accentPitch: settings.pitchFactor, normalPitch: settings.pitchFactor)
        engine.setVolume(settings.masterVolume)

        let mode: Mode
        var expectedSeconds: Double
        var stopAfterBeats: Int?      // the metronome stops after that many beats (the count-in not counted)
        var beatsPerBar = settings.beats
        switch source {
        case .metronome(let bars):
            guard bars > 0 else { throw Failure(message: "no bars to write") }
            try engine.setSimple(tempo: settings.tempo, beats: settings.beats, denominator: settings.denominator, pattern: settings.pattern,
                                 trainerStart: 0, trainerIncrement: settings.trainer.engineIncrement, trainerLimit: settings.trainer.engineLimit)
            mode = .simple
            stopAfterBeats = bars * settings.beats
            expectedSeconds = Double(bars * settings.beats) * 60 / max(settings.tempo, 1) * 4 / Double(settings.denominator)
        case .map(let fromBar):
            guard !map.isEmpty else { throw Failure(message: "no section to write") }
            let (played, _, _) = MapSection.played(map, fromBar: fromBar)
            try engine.setMap(played.map(\.engineSection))
            mode = .map
            beatsPerBar = played[0].beats
            expectedSeconds = played.reduce(0) { $0 + $1.seconds }
        }
        if options.includeCountIn, settings.countIn != .none {
            let count = settings.countIn.engineParameters(beatsPerBar: beatsPerBar)
            try engine.setCountIn(bars: count.bars, beatsPerBar: count.beatsPerBar, volume: 0.66)
            expectedSeconds += Double(count.bars * count.beatsPerBar) * 60 / max(settings.tempo, 1)
        } else {
            try engine.setCountIn(bars: 0, beatsPerBar: beatsPerBar, volume: 0)
        }

        let writer = try WavWriter(url: url, rate: options.rate, depth: options.bitDepth)
        var finished = false
        defer { if !finished { writer.discard() } }
        try engine.start(mode)

        // The end of the metronome is known when the engine schedules the beat after the last bar, a little before it is rendered: the
        // last blocks are held back, so that the file can be cut exactly at that frame.
        let block = 4096
        let holdBack = 2 * block
        var held: [Float] = []
        var produced = 0, flushed = 0
        var mainBeats = 0
        var endFrame: Int?
        var tailLeft = Int(0.3 * Double(options.rate))
        while true {
            if isCancelled() { throw CancellationError() }
            for beat in engine.pollBeats() where !beat.isCountIn {
                if let limit = stopAfterBeats, endFrame == nil {
                    if mainBeats == limit { endFrame = Int(beat.frame) }
                    mainBeats += 1
                }
            }
            var frames = block
            if let endFrame {
                if produced >= endFrame { break }
                frames = min(block, endFrame - produced)
            } else if mode == .map, !engine.isPlaying {
                if tailLeft <= 0 { break }
                frames = min(block, tailLeft)
                tailLeft -= frames
            }
            held += engine.render(frames: frames)
            produced += frames
            if held.count > holdBack {
                let n = held.count - holdBack
                try writer.append(Array(held[0..<n]))
                held.removeFirst(n)
                flushed += n
            }
            progress(min(0.99, Double(produced) / max(expectedSeconds * Double(options.rate), 1)))
            if produced > options.rate * 3600 { throw Failure(message: "the file would be longer than an hour") }
        }
        let keep = endFrame.map { max(0, min(held.count, $0 - flushed)) } ?? held.count
        try writer.append(Array(held[0..<keep]))
        try writer.finish()
        finished = true
        progress(1)
    }
}

/// A WAV file written as it is rendered: the header is filled in when the end is known.
final class WavWriter {
    private let url: URL
    private let handle: FileHandle
    private let rate: Int
    private let depth: AudioExportOptions.BitDepth
    private var dataBytes = 0

    init(url: URL, rate: Int, depth: AudioExportOptions.BitDepth) throws {
        self.url = url; self.rate = rate; self.depth = depth
        FileManager.default.createFile(atPath: url.path, contents: nil)
        handle = try FileHandle(forWritingTo: url)
        try handle.write(contentsOf: Data(count: 44))
    }

    func append(_ samples: [Float]) throws {
        var data = Data(capacity: samples.count * (depth.rawValue / 8))
        for sample in samples {
            let x = max(-1, min(1, sample))
            switch depth {
            case .int16:
                var v = Int16((x * 32767).rounded()).littleEndian
                withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
            case .int24:
                let v = Int32((x * 8388607).rounded())
                data.append(contentsOf: [UInt8(truncatingIfNeeded: v), UInt8(truncatingIfNeeded: v >> 8), UInt8(truncatingIfNeeded: v >> 16)])
            case .float32:
                var v = x.bitPattern.littleEndian
                withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
            }
        }
        try handle.write(contentsOf: data)
        dataBytes += data.count
    }

    func finish() throws {
        func le32(_ v: Int) -> [UInt8] { (0..<4).map { UInt8(truncatingIfNeeded: v >> (8 * $0)) } }
        func le16(_ v: Int) -> [UInt8] { (0..<2).map { UInt8(truncatingIfNeeded: v >> (8 * $0)) } }
        let bytesPerSample = depth.rawValue / 8
        var header = [UInt8]()
        header += Array("RIFF".utf8) + le32(36 + dataBytes) + Array("WAVE".utf8)
        header += Array("fmt ".utf8) + le32(16) + le16(depth == .float32 ? 3 : 1) + le16(1) + le32(rate)
        header += le32(rate * bytesPerSample) + le16(bytesPerSample) + le16(depth.rawValue)
        header += Array("data".utf8) + le32(dataBytes)
        try handle.seek(toOffset: 0)
        try handle.write(contentsOf: Data(header))
        try handle.close()
    }

    func discard() {
        try? handle.close()
        try? FileManager.default.removeItem(at: url)
    }
}
