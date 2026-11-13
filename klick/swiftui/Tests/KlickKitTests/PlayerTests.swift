// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import XCTest
import KlickEngine
@testable import KlickKit

/// The player on an engine that renders offline: no audio device, no sound. The sounds are those of klick/build/samples.
@MainActor
final class PlayerTests: XCTestCase {
    static let sounds = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("build/samples")

    func makePlayer(sounds: URL = PlayerTests.sounds) throws -> (Player, Engine) {
        let engine = try Engine(offline: true, rate: 48000)
        return (Player(engine: engine, soundsDirectory: sounds), engine)
    }

    /// Renders like a device does and lets the player look after each block; `watch` is called after each update.
    func run(_ engine: Engine, _ player: Player, seconds: Double, watch: () -> Void = {}) {
        for _ in 0..<Int(seconds * 48000 / 512) + 1 {
            _ = engine.render(frames: 512)
            player.update()
            watch()
        }
    }

    func testTheSimpleMetronomeIsHeardBeatByBeat() throws {
        let (player, engine) = try makePlayer()
        var settings = ClickSettings()
        settings.tempo = 120
        var seen: [Int] = []
        try player.start(.simple, settings: settings)
        XCTAssertEqual(player.phase, .playing, "no count-in: playing at once")
        run(engine, player, seconds: 2.1) { if let b = player.beat, seen.last != b.beat || seen.isEmpty { seen.append(b.beat) } }
        XCTAssertGreaterThanOrEqual(player.beatCount, 4)
        XCTAssertEqual(Array(seen.prefix(5)), [0, 1, 2, 3, 0])
        XCTAssertEqual(player.barCount, 2, "bars begin at 0 s and 2 s")
        XCTAssertEqual(player.beatDuration, 0.5, accuracy: 0.001)
        XCTAssertGreaterThan(player.lastBeatTime, Date.distantPast)
        XCTAssertEqual(player.tempo, 120, accuracy: 0.01)
        XCTAssertEqual(player.phase, .playing)
        player.stop()
        XCTAssertEqual(player.phase, .stopped)
        XCTAssertNil(player.beat)
    }

    func testTheCountInThenTheMetronome() throws {
        let (player, engine) = try makePlayer()
        var settings = ClickSettings()
        settings.countIn = .oneBar
        try player.start(.simple, settings: settings)
        XCTAssertEqual(player.phase, .countIn)
        var remaining: [Int] = []
        var phases: [Player.Phase] = []
        run(engine, player, seconds: 3) {
            if phases.last != player.phase { phases.append(player.phase) }
            if player.phase == .countIn, remaining.last != player.countInRemaining { remaining.append(player.countInRemaining) }
        }
        XCTAssertEqual(remaining, [4, 3, 2, 1])
        XCTAssertEqual(phases, [.countIn, .playing])
        XCTAssertEqual(player.countInRemaining, 0)
        XCTAssertGreaterThanOrEqual(player.beatCount, 4 + 2)
    }

    func testTheMapIsFollowedAndStopsAtTheEnd() throws {
        let (player, engine) = try makePlayer()
        try player.setMap([
            MapSection(label: "a", bars: 1, tempo: 120),
            MapSection(label: "b", bars: 1, beats: 3, tempo: 120),
            MapSection(label: "c", bars: 2, beats: 2, tempo: 120),
        ])
        try player.start(.map, settings: ClickSettings())
        var sections: [Int] = []
        var progress: [Double] = []
        run(engine, player, seconds: 7) {
            if player.phase != .stopped {
                if sections.last != player.sectionIndex { sections.append(player.sectionIndex) }
                progress.append(player.mapProgress)
            }
        }
        XCTAssertEqual(sections, [0, 1, 2])
        XCTAssertEqual(progress, progress.sorted(), "the position only moves forward")
        XCTAssertGreaterThan(progress.last ?? 0, 0.8)
        XCTAssertEqual(player.phase, .stopped, "the map is over")
        XCTAssertNil(player.mode)
    }

    func testTheMapCanStartFromASection() throws {
        let (player, engine) = try makePlayer()
        let sections = [
            MapSection(label: "a", bars: 2, tempo: 120),
            MapSection(label: "b", bars: 1, beats: 3, tempo: 120),
            MapSection(label: "c", bars: 1, beats: 2, tempo: 120),
        ]
        try player.setMap(sections, startingAtBar: 2)
        try player.start(.map, settings: ClickSettings())
        var seen: [Int] = []
        var firstPosition: Double?
        run(engine, player, seconds: 7) {
            if player.phase != .stopped {
                if seen.last != player.sectionIndex { seen.append(player.sectionIndex) }
                if firstPosition == nil { firstPosition = player.mapPosition }
            }
        }
        XCTAssertEqual(seen, [1, 2], "the sections before are skipped, the numbers are those of the whole map")
        XCTAssertEqual(firstPosition, 2, "the position counts the bars that were skipped")
        XCTAssertEqual(player.phase, .stopped)
    }

    func testTheMapCanStartInTheMiddleOfASection() throws {
        let (player, engine) = try makePlayer()
        try player.setMap([MapSection(label: "ramp", bars: 4, tempo: 100, tempoEnd: 140), MapSection(label: "b", bars: 1, tempo: 140)], startingAtBar: 2)
        try player.start(.map, settings: ClickSettings())
        var first: (section: Int, bar: Int, position: Double, tempo: Double)?
        run(engine, player, seconds: 2) {
            if first == nil, player.phase == .playing, player.beat != nil {
                first = (player.sectionIndex, player.sectionBar, player.mapPosition, player.tempo)
            }
        }
        XCTAssertEqual(first?.section, 0)
        XCTAssertEqual(first?.bar, 2, "the section counts from its own first bar")
        XCTAssertEqual(first?.position, 2)
        XCTAssertEqual(first?.tempo ?? 0, 120, accuracy: 2, "the ramp starts where it has got to (100 to 140 over 4 bars, 2 bars in)")
    }

    func testTheDisplayWaitsForTheOffsetButNotWhenQuiet() throws {
        func framesBeforeFirstBeat(quiet: Bool) throws -> Int {
            let (player, engine) = try makePlayer()
            var settings = ClickSettings()
            settings.isQuiet = quiet
            player.displayOffsetMilliseconds = 200
            try player.start(.simple, settings: settings)
            var frames = 0
            while player.beatCount == 0 && frames < 48000 {
                _ = engine.render(frames: 512); frames += 512
                player.update()
            }
            player.stop()
            return frames
        }
        XCTAssertGreaterThanOrEqual(try framesBeforeFirstBeat(quiet: false), 9600, "200 ms at 48 kHz")
        XCTAssertLessThanOrEqual(try framesBeforeFirstBeat(quiet: true), 512, "nothing to wait for without a sound")
    }

    func testSettingsChangedWhilePlayingReachTheBeats() throws {
        let (player, engine) = try makePlayer()
        var settings = ClickSettings()
        try player.start(.simple, settings: settings)
        run(engine, player, seconds: 1)
        settings.tempo = 150
        try player.apply(settings)
        run(engine, player, seconds: 1)
        XCTAssertEqual(player.tempo, 150, accuracy: 0.01)
    }

    func testSoundsAreFoundOrReported() throws {
        let (player, _) = try makePlayer(sounds: URL(fileURLWithPath: "/nonexistent"))
        XCTAssertThrowsError(try player.start(.simple, settings: ClickSettings()))
        XCTAssertEqual(player.phase, .stopped)
        let (good, _) = try makePlayer()
        var settings = ClickSettings()
        for sound in ClickSound.BuiltIn.allCases {
            settings.sound = .builtIn(sound)
            XCTAssertNoThrow(try good.apply(settings), "built-in sound \(sound)")
        }
        settings.sound = .files(accent: "/nonexistent/a.wav", normal: "/nonexistent/n.wav")
        XCTAssertThrowsError(try good.apply(settings))
    }

    /// The real output device at volume 0 (no sound), with the real display loop: beats are heard in time, with the latency of
    /// the output. Opt in with KLICK_TEST_DEVICE=1 (needs an output device).
    func testTheRealDisplayLoopOnTheDeviceSilently() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["KLICK_TEST_DEVICE"] == "1", "set KLICK_TEST_DEVICE=1 to run")
        let engine = try Engine()
        let player = Player(engine: engine, soundsDirectory: Self.sounds)
        var settings = ClickSettings()
        settings.tempo = 240
        settings.masterVolume = 0          // not quiet: the latency of the output is applied, but nothing is heard
        settings.countIn = .twoBeats
        try player.start(.simple, settings: settings)
        let latency = engine.outputLatency
        var firstCountIn: Date?
        var lampTimes: [Date] = []
        var last = 0
        let began = Date()
        while Date().timeIntervalSince(began) < 3 {
            try await Task.sleep(for: .milliseconds(5))
            if player.beatCount != last {
                last = player.beatCount
                lampTimes.append(Date())
                if firstCountIn == nil { firstCountIn = Date() }
            }
        }
        player.stop()
        XCTAssertGreaterThanOrEqual(lampTimes.count, 10, "about 4 beats a second for 3 seconds")
        let gaps = zip(lampTimes, lampTimes.dropFirst()).map { $1.timeIntervalSince($0) }
        XCTAssertTrue(gaps.allSatisfy { abs($0 - 0.25) < 0.04 }, "lamps every 250 ms, within the 16 ms display loop: \(gaps.map { Int($0 * 1000) })")
        print("player on the device: latency \(latency) frames, \(lampTimes.count) beats, first after \(Int((firstCountIn ?? began).timeIntervalSince(began) * 1000)) ms")
    }

    func testAMapNeedsToBeSetBeforeItStarts() throws {
        let (player, _) = try makePlayer()
        XCTAssertThrowsError(try player.start(.map, settings: ClickSettings()))
        XCTAssertThrowsError(try player.setMap([MapSection(bars: 1, tempo: 5)]), "tempo out of range")
        XCTAssertEqual(player.phase, .stopped)
    }
}
