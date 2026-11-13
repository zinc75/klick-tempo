// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import CKlickEngine
import Foundation

/// Kind of a beat, as the engine reports it.
public enum BeatType: Int32, Sendable {
    case accent = 1
    case normal = 2
    case silent = 3
}

/// One beat, scheduled by the audio thread; silent beats are reported too.
public struct Beat: Equatable, Sendable {
    /// Position of the beat, in frames since the engine began rendering.
    public var frame: UInt64
    /// Section of the tempo map (0 for the simple metronome).
    public var section: Int
    /// Bar in the section and beat in the bar, both counted from 0.
    public var bar: Int
    public var beat: Int
    public var beats: Int
    public var denominator: Int
    public var type: BeatType
    /// Quarter notes per minute at this beat.
    public var tempo: Double
    /// Volume of the section (1 for the simple metronome).
    public var volume: Double
}

/// One section of a tempo map.
public struct Section: Equatable, Sendable {
    public var label: String
    /// Number of bars, or `nil` to play forever (last section only).
    public var bars: Int?
    public var beats: Int
    public var denominator: Int
    /// Quarter notes per minute.
    public var tempo: Double
    /// Tempo reached at the end of the section for a gradual change, `nil` for a constant tempo.
    public var tempoEnd: Double?
    /// One character per beat: `X` accent, `x` normal, `.` silent; `nil` for the default pattern.
    public var pattern: String?
    /// 1 normal, 0 silent.
    public var volume: Double

    public init(label: String = "", bars: Int?, beats: Int = 4, denominator: Int = 4, tempo: Double, tempoEnd: Double? = nil,
                pattern: String? = nil, volume: Double = 1) {
        self.label = label; self.bars = bars; self.beats = beats; self.denominator = denominator; self.tempo = tempo
        self.tempoEnd = tempoEnd; self.pattern = pattern; self.volume = volume
    }
}

public enum Mode: Sendable {
    /// One meter and tempo, played until stopped.
    case simple
    /// The tempo map, played once.
    case map
}

public struct EngineError: Error, LocalizedError, Equatable {
    public let message: String
    public var errorDescription: String? { message }
}

/// The metronome engine. One control thread (the main thread of the application) calls everything except `pollBeats()`,
/// which any single thread may call.
public final class Engine: @unchecked Sendable {
    private let handle: OpaquePointer

    /// Opens the default output device, or, with `offline`, an engine that renders only when `render(frames:)` is called.
    public init(offline: Bool = false, offlineRate: Int = 48000) throws {
        var message = [CChar](repeating: 0, count: 256)
        guard let h = klick_engine_create(offline ? 1 : 0, UInt32(offlineRate), &message, message.count) else {
            throw EngineError(message: String(cString: message))
        }
        handle = h
    }

    deinit { klick_engine_destroy(handle) }

    public var sampleRate: Int { Int(klick_engine_samplerate(handle)) }

    /// Loads the click sounds from files (any format of libsndfile); `nil` gives silence. The volumes and pitch factors
    /// are multipliers.
    public func loadSound(accent: URL?, normal: URL?, accentVolume: Double = 1, normalVolume: Double = 1,
                          accentPitch: Double = 1, normalPitch: Double = 1) throws {
        var message = [CChar](repeating: 0, count: 256)
        let ok = klick_engine_load_sound(handle, accent?.path, normal?.path, Float(accentVolume), Float(normalVolume),
                                         Float(accentPitch), Float(normalPitch), &message, message.count)
        if ok == 0 { throw EngineError(message: String(cString: message)) }
    }

    /// Master volume of the clicks.
    public func setVolume(_ volume: Double) { klick_engine_set_volume(handle, Float(volume)) }

    /// The simple metronome; can be called while it plays. `pattern` has one character per beat (`X`, `x`, `.`).
    /// Speed trainer: `trainerStart`, `trainerIncrement` (quarter notes per bar) and `trainerLimit`, all 0 for none.
    public func setSimple(tempo: Double, beats: Int, denominator: Int, pattern: String? = nil,
                          trainerStart: Double = 0, trainerIncrement: Double = 0, trainerLimit: Double = 0) throws {
        var message = [CChar](repeating: 0, count: 256)
        let ok = klick_engine_set_simple(handle, Float(tempo), Int32(beats), Int32(denominator), pattern,
                                         Float(trainerStart), Float(trainerIncrement), Float(trainerLimit),
                                         &message, message.count)
        if ok == 0 { throw EngineError(message: String(cString: message)) }
    }

    /// The tempo map; takes effect at the next `start(.map)`.
    public func setMap(_ sections: [Section], tempoMultiplier: Double = 1) throws {
        var message = [CChar](repeating: 0, count: 256)
        // The C strings must live until the call returns.
        var owned: [UnsafeMutablePointer<CChar>] = []
        defer { owned.forEach { free($0) } }
        func cString(_ s: String?) -> UnsafePointer<CChar>? {
            guard let s else { return nil }
            let p = strdup(s)!
            owned.append(p)
            return UnsafePointer(p)
        }
        let c = sections.map { s in
            KlickSection(label: cString(s.label), bars: Int32(s.bars ?? -1), beats: Int32(s.beats), denom: Int32(s.denominator),
                         tempo: Float(s.tempo), tempo_end: Float(s.tempoEnd ?? 0), pattern: cString(s.pattern),
                         volume: Float(s.volume))
        }
        let ok = klick_engine_set_map(handle, c, c.count, Float(tempoMultiplier), &message, message.count)
        if ok == 0 { throw EngineError(message: String(cString: message)) }
    }

    public func start(_ mode: Mode) throws {
        var message = [CChar](repeating: 0, count: 256)
        let ok = klick_engine_start(handle, mode == .simple ? KLICK_MODE_SIMPLE : KLICK_MODE_MAP, &message, message.count)
        if ok == 0 { throw EngineError(message: String(cString: message)) }
    }

    public func stop() { klick_engine_stop(handle) }

    /// True while something plays; a tempo map that has reached its end is no longer playing.
    public var isPlaying: Bool { klick_engine_is_playing(handle) != 0 }

    /// The beats scheduled since the last call, oldest first.
    public func pollBeats() -> [Beat] {
        var raw = [KlickBeat](repeating: KlickBeat(), count: 256)
        var result: [Beat] = []
        while true {
            let n = klick_engine_poll_beats(handle, &raw, raw.count)
            if n == 0 { break }
            for b in raw[0..<n] {
                result.append(Beat(frame: b.frame, section: Int(b.section), bar: Int(b.bar), beat: Int(b.beat), beats: Int(b.beats),
                                   denominator: Int(b.denom), type: BeatType(rawValue: b.type) ?? .normal,
                                   tempo: Double(b.tempo), volume: Double(b.volume)))
            }
            if n < raw.count { break }
        }
        return result
    }

    /// Beats lost because nobody polled fast enough.
    public var lostBeats: UInt64 { klick_engine_lost_beats(handle) }

    /// Offline engines only: renders `frames` mono frames.
    public func render(frames: Int) -> [Float] {
        var out = [Float](repeating: 0, count: frames)
        klick_engine_render(handle, &out, UInt32(frames))
        return out
    }

    /// Delivery diagnostics of the output device (0 for offline engines).
    public var dropouts: Int { Int(klick_engine_dropouts(handle)) }
    public var maxLatenessMicroseconds: Int { Int(klick_engine_max_lateness_us(handle)) }
}
