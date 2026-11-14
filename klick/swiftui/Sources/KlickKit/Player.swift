// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import Foundation
import KlickEngine
import Observation

/// Plays the metronome or the tempo map and tells the interface what is heard: the beat, the count-in, the section and the
/// tempo. The engine schedules beats ahead of the sound; the player releases each one when it is heard (the position of the
/// output minus its latency), so that the lamps light with the click.
@MainActor
@Observable
public final class Player {
    public enum Phase: Equatable, Sendable { case stopped, countIn, playing }

    public private(set) var phase = Phase.stopped
    public private(set) var mode: Mode?
    /// The last beat heard (the count-in included); `nil` when stopped.
    public private(set) var beat: Beat?
    /// Goes up by one at each beat heard: the lamps flash when it changes.
    public private(set) var beatCount = 0
    /// Goes up by one at the first beat of each bar heard (the count-in included): what a ring or a flash follows.
    public private(set) var barCount = 0
    /// When the last beat was heard, and how long a beat lasts at its tempo, in seconds: for a pendulum that swings with the beat.
    public private(set) var lastBeatTime = Date.distantPast
    public private(set) var beatDuration = 0.5
    /// Beats of the count-in left, the one being heard included.
    public private(set) var countInRemaining = 0
    /// Tempo of the last beat heard, in quarter notes per minute (follows the speed trainer and the ramps of a map).
    public private(set) var tempo = 0.0
    public private(set) var sectionIndex = 0
    /// Bar of the section being heard, from 0 (a section started in the middle counts from its own first bar).
    public private(set) var sectionBar = 0
    /// Position in the tempo map, in bars from its start (the fraction is the beat).
    public private(set) var mapPosition = 0.0
    public private(set) var message: String?
    /// Called at each turn of the display loop, and when playing stops: a backend that has a state of its own to show reads it there.
    public var didUpdate: (() -> Void)?

    /// Extra delay of the display for the output in use, in milliseconds (set from `ClickSettings.displayOffsets`).
    public var displayOffsetMilliseconds = 0.0

    public var mapProgress: Double {
        let total = Double(map.reduce(0) { $0 + $1.bars })
        return total > 0 ? min(1, mapPosition / total) : 0
    }

    /// The engine in use; another one after `replaceEngine`.
    public private(set) var engine: Engine
    private let soundsDirectory: URL
    private var map: [MapSection] = []
    /// Where the map starts: the engine plays from there on, the counting stays that of the whole map. A bar of a section.
    private var startSection = 0
    private var startBarInSection = 0
    private var pending: [Beat] = []
    private var quiet = false
    private var latencyFrames = 0
    private var latencyReadAt = Date.distantPast
    private var soundKey: String?
    private var loop: Task<Void, Never>?

    /// `soundsDirectory` holds `square_emphasis.wav`, `square_normal.wav`, `sine_…`, `noise_…` and `click_…`.
    public init(engine: Engine, soundsDirectory: URL) {
        self.engine = engine
        self.soundsDirectory = soundsDirectory
    }

    public var isPlaying: Bool { phase != .stopped }

    /// The id of the backend the engine plays on.
    public var backendID: String { engine.backendID }

    /// The AudioInterface of the backend, for the functions of the library that provided it.
    public var backendAudio: UnsafeMutableRawPointer? { engine.backendAudio }

    /// True when the backend has stopped by itself (a JACK server that is gone).
    public var isBackendShutdown: Bool { engine.isBackendShutdown }

    /// Plays on another engine (another backend) from now on: what plays stops, the sounds are loaded again at the next start.
    public func replaceEngine(_ new: Engine) {
        stop()
        engine = new
        soundKey = nil
        latencyFrames = 0
        readLatency(force: true)
    }

    /// Rate of the engine, in Hz.
    public var sampleRate: Int { engine.sampleRate }

    /// The output device in use (an AudioDeviceID), 0 for an offline engine.
    public var outputDevice: UInt32 { engine.outputDevice }

    /// Plays on a device, or, with 0, on the output of the system (followed). The latency is read again.
    public func setOutputDevice(_ device: UInt32) throws {
        try engine.setOutputDevice(device)
        readLatency(force: true)
    }

    /// While following the system: moves to its output device when it has changed. Returns true when it did.
    @discardableResult
    public func followSystemOutput() throws -> Bool {
        let changed = try engine.followSystemOutput()
        if changed { readLatency(force: true) }
        return changed
    }

    // MARK: settings and map

    /// Passes the settings to the engine; can be called while it plays.
    public func apply(_ settings: ClickSettings) throws {
        try loadSounds(settings)
        quiet = settings.isQuiet
        engine.setVolume(settings.isQuiet ? 0 : settings.masterVolume)
        try engine.setSimple(tempo: settings.tempo, beats: settings.beats, denominator: settings.denominator, pattern: settings.pattern,
                             trainerStart: 0, trainerIncrement: settings.trainer.engineIncrement, trainerLimit: settings.trainer.engineLimit)
    }

    /// The tempo map to play, from its start or from the bar `startingAtBar` (counted from the start of the map, from 0; a bar
    /// that is not in the map means the start); takes effect at the next start.
    public func setMap(_ sections: [MapSection], tempoMultiplier: Double = 1, startingAtBar bar: Int = 0) throws {
        let (played, from, skipped) = MapSection.played(sections, fromBar: bar)
        try engine.setMap(played.map(\.engineSection), tempoMultiplier: tempoMultiplier)
        map = sections
        startSection = from
        startBarInSection = skipped
    }

    private func loadSounds(_ s: ClickSettings) throws {
        let key = "\(s.sound)|\(s.accentVolume)|\(s.normalVolume)|\(s.pitchFactor)"
        guard key != soundKey else { return }
        let accent: URL, normal: URL
        switch s.sound {
        case .builtIn(let sound):
            accent = soundsDirectory.appendingPathComponent("\(sound.fileName)_emphasis.wav")
            normal = soundsDirectory.appendingPathComponent("\(sound.fileName)_normal.wav")
        case .files(let a, let n):
            accent = URL(fileURLWithPath: a); normal = URL(fileURLWithPath: n)
        }
        try engine.loadSound(accent: accent, normal: normal, accentVolume: s.accentVolume, normalVolume: s.normalVolume,
                             accentPitch: s.pitchFactor, normalPitch: s.pitchFactor)
        soundKey = key
    }

    // MARK: playing

    public func start(_ mode: Mode, settings: ClickSettings) throws {
        stop()
        try apply(settings)
        let beatsPerBar = mode == .map ? (map.indices.contains(startSection) ? map[startSection].beats : settings.beats) : settings.beats
        // (when the start waits for a signal of the backend, there is no count-in: the song has its own)
        let count = engine.startIsGated ? (bars: 0, beatsPerBar: beatsPerBar) : settings.countIn.engineParameters(beatsPerBar: beatsPerBar)
        try engine.setCountIn(bars: count.bars, beatsPerBar: count.beatsPerBar, volume: settings.isCountInAudible && !settings.isQuiet ? 0.66 : 0)
        try engine.start(mode)
        self.mode = mode
        beat = nil; beatCount = 0; barCount = 0; tempo = 0; sectionIndex = 0; sectionBar = 0; mapPosition = 0; message = nil
        pending = []
        countInRemaining = 0
        phase = count.bars > 0 ? .countIn : .playing
        readLatency(force: true)
        loop = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.update()
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    public func stop() {
        loop?.cancel(); loop = nil
        if phase != .stopped || engine.isPlaying { engine.stop() }
        phase = .stopped
        mode = nil
        beat = nil
        countInRemaining = 0
        pending = []
        didUpdate?()
    }

    /// Releases the beats that are heard by now. Called by the display loop; public so that tests can drive it.
    public func update() {
        guard phase != .stopped else { return }
        pending += engine.pollBeats()
        readLatency(force: false)
        didUpdate?()
        // A lamp cannot light before the engine has scheduled its beat: the delay, the announced latency plus the offset, stays at 0
        // or above (a negative offset can take back what the output announces, not more).
        let delay = quiet ? 0 : max(0, latencyFrames + Int(displayOffsetMilliseconds * Double(engine.sampleRate) / 1000))
        let heardUntil = Int64(engine.position) - Int64(delay)
        while let next = pending.first, Int64(next.frame) <= heardUntil {
            pending.removeFirst()
            hear(next)
        }
        if mode == .map, pending.isEmpty, !engine.isPlaying { stop() }   // the map is over
    }

    private func hear(_ b: Beat) {
        beat = b
        beatCount += 1
        if b.beat == 0 { barCount += 1 }
        lastBeatTime = Date()
        beatDuration = b.tempo > 0 ? 240 / (b.tempo * Double(max(b.denominator, 1))) : 0.5
        tempo = b.tempo
        if b.isCountIn {
            phase = .countIn
            countInRemaining = b.countInRemaining
        } else {
            phase = .playing
            countInRemaining = 0
            if mode == .map {
                sectionIndex = b.section + startSection
                sectionBar = b.bar + (b.section == 0 ? startBarInSection : 0)
                let before = map.prefix(sectionIndex).reduce(0) { $0 + $1.bars }
                mapPosition = Double(before) + Double(sectionBar) + Double(b.beat) / Double(max(b.beats, 1))
            }
        }
    }

    /// The system is asked now and then, not at every display frame.
    private func readLatency(force: Bool) {
        guard force || Date().timeIntervalSince(latencyReadAt) > 1 else { return }
        latencyFrames = engine.outputLatency
        latencyReadAt = Date()
    }
}
