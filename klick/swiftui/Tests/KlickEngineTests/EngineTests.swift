// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import XCTest
@testable import KlickEngine

/// Tests on an engine that renders offline: no audio device, no sound. The sounds are those of klick/build/samples.
final class EngineTests: XCTestCase {
    static let sounds = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("build/samples")

    func makeEngine(sounds: Bool = true) throws -> Engine {
        let engine = try Engine(offline: true, offlineRate: 48000)
        if sounds {
            try engine.loadSound(accent: Self.sounds.appendingPathComponent("square_emphasis.wav"),
                                 normal: Self.sounds.appendingPathComponent("square_normal.wav"))
        }
        return engine
    }

    /// Renders `seconds` in blocks like a device does, and returns the signal with the beats.
    func play(_ engine: Engine, seconds: Double) -> (signal: [Float], beats: [Beat]) {
        var signal: [Float] = []
        var beats: [Beat] = []
        for _ in 0..<Int(seconds * 48000 / 512) + 1 {
            signal += engine.render(frames: 512)
            beats += engine.pollBeats()
        }
        return (signal, beats)
    }

    func peak(_ signal: [Float], at frame: UInt64, base: UInt64 = 0, width: Int = 200) -> Float {
        let start = Int(frame - base)
        return signal[start..<min(start + width, signal.count)].map { abs($0) }.max() ?? 0
    }

    func testSimpleMetronomeReportsEveryBeat() throws {
        let engine = try makeEngine()
        XCTAssertEqual(engine.sampleRate, 48000)
        try engine.setSimple(tempo: 150, beats: 3, denominator: 4, pattern: "X.x")
        try engine.start(.simple)
        XCTAssertTrue(engine.isPlaying)
        let (signal, beats) = play(engine, seconds: 2.1)
        XCTAssertGreaterThanOrEqual(beats.count, 6)
        XCTAssertEqual(beats.prefix(3).map(\.type), [.accent, .silent, .normal])
        XCTAssertEqual(beats.prefix(3).map(\.frame), [0, 19200, 38400])
        XCTAssertEqual(beats[0].beats, 3)
        XCTAssertEqual(beats[0].denominator, 4)
        XCTAssertEqual(beats[0].tempo, 150, accuracy: 0.01)
        XCTAssertEqual(beats[3].bar, 1)
        XCTAssertEqual(beats[3].beat, 0)
        XCTAssertGreaterThan(peak(signal, at: beats[0].frame), 0.3)
        XCTAssertEqual(peak(signal, at: beats[1].frame), 0)
        XCTAssertGreaterThan(peak(signal, at: beats[2].frame), 0.2)
        XCTAssertEqual(engine.lostBeats, 0)
    }

    func testChangesWhilePlayingReachTheBeats() throws {
        let engine = try makeEngine()
        try engine.setSimple(tempo: 120, beats: 4, denominator: 4)
        try engine.start(.simple)
        _ = play(engine, seconds: 1)
        try engine.setSimple(tempo: 300, beats: 3, denominator: 4, pattern: "Xxx")
        let (_, beats) = play(engine, seconds: 1)
        let last = try XCTUnwrap(beats.last)
        XCTAssertEqual(last.tempo, 300, accuracy: 0.01)
        XCTAssertEqual(last.beats, 3)
        let gaps = zip(beats, beats.dropFirst()).map { $1.frame - $0.frame }
        XCTAssertTrue(gaps.suffix(3).allSatisfy { $0 == 9600 })
    }

    func testTempoMapSectionsTemposAndSilence() throws {
        let engine = try makeEngine()
        try engine.setMap([
            Section(label: "intro", bars: 1, beats: 4, denominator: 4, tempo: 120, pattern: "Xxxx"),
            Section(bars: 1, beats: 3, denominator: 4, tempo: 90, tempoEnd: 120),
            Section(label: "quiet", bars: 1, beats: 5, denominator: 8, tempo: 140, pattern: "X.xxx", volume: 0),
        ])
        try engine.start(.map)
        XCTAssertTrue(engine.isPlaying)
        let (signal, beats) = play(engine, seconds: 5.5)
        XCTAssertEqual(beats.count, 12)
        XCTAssertEqual(beats.map(\.section), [0, 0, 0, 0, 1, 1, 1, 2, 2, 2, 2, 2])
        XCTAssertEqual(beats[7].tempo, 140, accuracy: 0.05)
        XCTAssertEqual(beats[7].denominator, 8)
        XCTAssertTrue(beats[4].tempo > 90 && beats[4].tempo < beats[6].tempo && beats[6].tempo < 120)
        XCTAssertEqual(beats[7].volume, 0)
        XCTAssertEqual(beats[0].volume, 1)
        XCTAssertEqual(peak(signal, at: beats[7].frame), 0)
        XCTAssertGreaterThan(peak(signal, at: beats[0].frame), 0.3)
        XCTAssertFalse(engine.isPlaying, "the map is over")
    }

    func testRestartBeginsAgain() throws {
        let engine = try makeEngine()
        try engine.setMap([Section(bars: 2, tempo: 120)])
        try engine.start(.map)
        _ = play(engine, seconds: 1)
        engine.stop()
        XCTAssertFalse(engine.isPlaying)
        try engine.start(.map)
        let (_, beats) = play(engine, seconds: 0.6)
        XCTAssertEqual(beats.first?.section, 0)
        XCTAssertEqual(beats.first?.bar, 0)
        XCTAssertEqual(beats.first?.beat, 0)
    }

    func testWithoutSoundsTheEngineIsSilentButStillCounts() throws {
        let engine = try makeEngine(sounds: false)
        try engine.setSimple(tempo: 120, beats: 4, denominator: 4)
        try engine.start(.simple)
        let (signal, beats) = play(engine, seconds: 1.2)
        XCTAssertGreaterThanOrEqual(beats.count, 2)
        XCTAssertEqual(signal.map { abs($0) }.max(), 0)
    }

    /// The real output device, at volume 0 (no sound): beats flow from the audio thread, changes made while it plays are
    /// applied, and the device reports no dropout. Opt in with KLICK_TEST_DEVICE=1 (needs an output device).
    func testRealDeviceSilently() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["KLICK_TEST_DEVICE"] == "1", "set KLICK_TEST_DEVICE=1 to run")
        let engine = try Engine()
        try engine.loadSound(accent: Self.sounds.appendingPathComponent("square_emphasis.wav"),
                             normal: Self.sounds.appendingPathComponent("square_normal.wav"))
        engine.setVolume(0)
        try engine.setSimple(tempo: 240, beats: 4, denominator: 4)
        try engine.start(.simple)
        var beats: [Beat] = []
        for step in 0..<30 {
            Thread.sleep(forTimeInterval: 0.1)
            if step == 10 { try engine.setSimple(tempo: 120, beats: 3, denominator: 4, pattern: "Xx.") }
            beats += engine.pollBeats()
        }
        engine.stop()
        XCTAssertGreaterThanOrEqual(beats.count, 8)   // about 4 beats at 240 BPM, then 4 more at 120 BPM
        XCTAssertEqual(beats.last?.beats, 3, "the change made while playing reached the audio thread")
        XCTAssertEqual(beats.last?.tempo ?? 0, 120, accuracy: 0.01)
        XCTAssertEqual(engine.lostBeats, 0)
        XCTAssertEqual(engine.dropouts, 0)
        let rate = Double(engine.sampleRate)
        let first = try XCTUnwrap(beats.first)
        let ok = zip(beats, beats.dropFirst()).prefix(3).allSatisfy { abs(Double($1.frame - $0.frame) - 0.25 * rate) < 2 }
        XCTAssertTrue(ok, "the first beats are 0.250 s apart at 240 BPM, from frame \(first.frame)")
        print("device: \(engine.sampleRate) Hz, \(beats.count) beats, lateness \(engine.maxLatenessMicroseconds) us")
    }

    func testInvalidInputIsReportedNotCrashed() throws {
        let engine = try makeEngine()
        XCTAssertThrowsError(try engine.start(.map)) { XCTAssertTrue(($0 as? EngineError)?.message.contains("no tempo map") == true) }
        XCTAssertThrowsError(try engine.setSimple(tempo: 5, beats: 4, denominator: 4))
        XCTAssertThrowsError(try engine.setSimple(tempo: 120, beats: 3, denominator: 4, pattern: "Xx"))
        XCTAssertThrowsError(try engine.setSimple(tempo: 120, beats: 0, denominator: 4))
        XCTAssertThrowsError(try engine.setMap([]))
        XCTAssertThrowsError(try engine.setMap([Section(bars: 0, tempo: 120)]))
        XCTAssertThrowsError(try engine.setMap([Section(bars: nil, tempo: 120), Section(bars: 2, tempo: 120)]),
                             "only the last section may play forever")
        XCTAssertThrowsError(try engine.loadSound(accent: URL(fileURLWithPath: "/nonexistent.wav"), normal: nil))
        // the engine is still usable
        try engine.setSimple(tempo: 120, beats: 4, denominator: 4)
        try engine.start(.simple)
        XCTAssertFalse(play(engine, seconds: 0.6).beats.isEmpty)
    }
}
