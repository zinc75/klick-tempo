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
    /// Volume of the section (of the count-in for its beats; 1 for the simple metronome).
    public var volume: Double
    /// True for a beat of the count-in (then `section` is 0 and `bar` counts the bars of the count-in).
    public var isCountIn: Bool
    /// Beats of the count-in still to come, this one included (0 outside the count-in).
    public var countInRemaining: Int
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
    /// One tempo per beat of the section (`bars * beats` values); then `tempo` and `tempoEnd` are ignored.
    public var tempi: [Double]?

    public init(label: String = "", bars: Int?, beats: Int = 4, denominator: Int = 4, tempo: Double, tempoEnd: Double? = nil,
                pattern: String? = nil, volume: Double = 1, tempi: [Double]? = nil) {
        self.label = label; self.bars = bars; self.beats = beats; self.denominator = denominator; self.tempo = tempo
        self.tempoEnd = tempoEnd; self.pattern = pattern; self.volume = volume; self.tempi = tempi
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
    /// The engine works at `rate` Hz; CoreAudio converts to the device, so a change of device does not matter.
    public init(offline: Bool = false, rate: Int = 48000) throws {
        var message = [CChar](repeating: 0, count: 256)
        guard let h = klick_engine_create(offline ? 1 : 0, UInt32(rate), &message, message.count) else {
            throw EngineError(message: String(cString: message))
        }
        handle = h
    }

    /// An engine on a backend of its own (another library than this one provides it, JACK for instance): the engine owns the
    /// backend from here on, whether this succeeds or not. The engine works at the sample rate of the backend.
    public init(backend: KlickBackend) throws {
        var message = [CChar](repeating: 0, count: 256)
        var b = backend
        guard let h = klick_engine_create_with_backend(&b, &message, message.count) else {
            throw EngineError(message: String(cString: message))
        }
        handle = h
    }

    deinit { klick_engine_destroy(handle) }

    /// The handle of the engine in the C interface, for the functions of the library that provided the backend (JACK: the ports).
    /// It stays valid as long as this object lives.
    public var rawHandle: OpaquePointer { handle }

    /// The id of the backend: "coreaudio", "offline", or the one a library gave ("jack").
    public var backendID: String { String(cString: klick_engine_backend_id(handle)) }

    /// The AudioInterface of the backend as an opaque pointer, for the functions of the library that provided it.
    public var backendAudio: UnsafeMutableRawPointer? { klick_engine_backend_audio(handle) }

    /// True when the backend has stopped by itself (a JACK server that is gone).
    public var isBackendShutdown: Bool { klick_engine_backend_is_shutdown(handle) != 0 }

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
        var ownedTempi: [UnsafeMutablePointer<Float>] = []
        defer { owned.forEach { free($0) }; ownedTempi.forEach { $0.deallocate() } }
        func cString(_ s: String?) -> UnsafePointer<CChar>? {
            guard let s else { return nil }
            let p = strdup(s)!
            owned.append(p)
            return UnsafePointer(p)
        }
        func floats(_ values: [Double]?) -> UnsafePointer<Float>? {
            guard let values else { return nil }
            let p = UnsafeMutablePointer<Float>.allocate(capacity: max(values.count, 1))
            for (i, v) in values.enumerated() { p[i] = Float(v) }
            ownedTempi.append(p)
            return UnsafePointer(p)
        }
        let c = sections.map { s in
            KlickSection(label: cString(s.label), bars: Int32(s.bars ?? -1), beats: Int32(s.beats), denom: Int32(s.denominator),
                         tempo: Float(s.tempo), tempo_end: Float(s.tempoEnd ?? 0), pattern: cString(s.pattern),
                         volume: Float(s.volume), tempi: floats(s.tempi), tempo_count: Int32(s.tempi?.count ?? 0))
        }
        let ok = klick_engine_set_map(handle, c, c.count, Float(tempoMultiplier), &message, message.count)
        if ok == 0 { throw EngineError(message: String(cString: message)) }
    }

    /// Count-in played before the next start: `bars` bars of `beatsPerBar` beats (0 bars for none), at the tempo and beat unit
    /// of the metronome or of the first section. `volume` 0 makes it silent (visual only), about 0.66 audible. The main
    /// metronome begins exactly when it ends.
    public func setCountIn(bars: Int, beatsPerBar: Int = 4, volume: Double = 0) throws {
        var message = [CChar](repeating: 0, count: 256)
        if klick_engine_set_countin(handle, Int32(bars), Int32(beatsPerBar), Float(volume), &message, message.count) == 0 {
            throw EngineError(message: String(cString: message))
        }
    }

    public func start(_ mode: Mode) throws {
        var message = [CChar](repeating: 0, count: 256)
        let ok = klick_engine_start(handle, mode == .simple ? KLICK_MODE_SIMPLE : KLICK_MODE_MAP, &message, message.count)
        if ok == 0 { throw EngineError(message: String(cString: message)) }
    }

    public func stop() { klick_engine_stop(handle) }

    /// True when the next start will wait for an extension of the engine (a backend that brings its own signal) instead of playing at
    /// once; and when what plays now does. No count-in then.
    public var startIsGated: Bool { klick_engine_start_is_gated(handle) != 0 }
    public var runIsGated: Bool { klick_engine_run_is_gated(handle) != 0 }

    /// True while something plays; a tempo map that has reached its end is no longer playing.
    public var isPlaying: Bool { klick_engine_is_playing(handle) != 0 }

    /// Frames handed to the output so far, on the scale of `Beat.frame`.
    public var position: UInt64 { klick_engine_position(handle) }

    /// Frames between a block being handed to the output and being heard (0 for an offline engine). Asks the system: read it
    /// now and then, not on every display frame.
    public var outputLatency: Int { Int(klick_engine_output_latency(handle)) }

    /// The output device in use (an AudioDeviceID); 0 for an offline engine.
    public var outputDevice: UInt32 { klick_engine_output_device(handle) }

    /// Plays on the device with that AudioDeviceID, or, with 0, on the output device of the system, which is then followed (see
    /// `followSystemOutput`). Can be called while it plays: the output is interrupted for a moment. If the device cannot be used
    /// the previous one stays.
    public func setOutputDevice(_ device: UInt32) throws {
        var message = [CChar](repeating: 0, count: 256)
        if klick_engine_set_output_device(handle, device, &message, message.count) == 0 { throw EngineError(message: String(cString: message)) }
    }

    /// While following the system: moves to its output device when it has changed. Returns true when the output changed.
    @discardableResult
    public func followSystemOutput() throws -> Bool {
        var message = [CChar](repeating: 0, count: 256)
        let result = klick_engine_follow_system_output(handle, &message, message.count)
        if result < 0 { throw EngineError(message: String(cString: message)) }
        return result == 1
    }

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
                                   tempo: Double(b.tempo), volume: Double(b.volume), isCountIn: b.count_in != 0,
                                   countInRemaining: Int(b.count_in_left)))
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
