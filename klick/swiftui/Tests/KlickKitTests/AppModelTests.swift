// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import XCTest
import KlickEngine
@testable import KlickKit

/// Settings kept in memory: the tests leave nothing in the preferences of the user.
final class MemoryStore: SettingsStore {
    var data: Data?
    func load() -> Data? { data }
    func save(_ data: Data) { self.data = data }
}

@MainActor
final class AppModelTests: XCTestCase {
    func makeModel(store: SettingsStore? = nil) throws -> (AppModel, Engine) {
        let engine = try Engine(offline: true, rate: 48000)
        let player = Player(engine: engine, soundsDirectory: PlayerTests.sounds)
        return (AppModel(player: player, store: store), engine)
    }

    func testThePlayButtonStartsWhatThePageIsAbout() throws {
        let (model, _) = try makeModel()
        XCTAssertEqual(model.mode, .simple)
        model.show(.map)
        XCTAssertEqual(model.mode, .map)
        model.show(.sounds)
        XCTAssertEqual(model.mode, .map, "the settings pages keep the last of the two")
        model.show(.metronome)
        model.show(.output)
        XCTAssertEqual(model.mode, .simple)
    }

    func testPlayingAndStopping() throws {
        let (model, engine) = try makeModel()
        model.togglePlayback()
        XCTAssertTrue(model.isPlaying)
        XCTAssertNil(model.errorMessage)
        _ = engine.render(frames: 512)
        model.player.update()
        model.togglePlayback()
        XCTAssertFalse(model.isPlaying)
        model.show(.map)
        model.togglePlayback()
        XCTAssertTrue(model.isPlaying)
        XCTAssertEqual(model.player.mode, .map)
        model.stop()
    }

    func testAFailureIsShownNotThrown() throws {
        let engine = try Engine(offline: true, rate: 48000)
        let model = AppModel(player: Player(engine: engine, soundsDirectory: URL(fileURLWithPath: "/nonexistent")), store: nil)
        model.togglePlayback()
        XCTAssertFalse(model.isPlaying)
        XCTAssertNotNil(model.errorMessage)
    }

    func testSettingsAreKeptBetweenLaunches() throws {
        let store = MemoryStore()
        let (first, _) = try makeModel(store: store)
        first.settings.tempo = 97
        first.settings.countIn = .twoBars
        let (second, _) = try makeModel(store: store)
        XCTAssertEqual(second.settings.tempo, 97)
        XCTAssertEqual(second.settings.countIn, .twoBars)
        let (fresh, _) = try makeModel(store: nil)
        XCTAssertEqual(fresh.settings.tempo, 120)
    }

    func testAChangeWhilePlayingReachesTheEngine() throws {
        let (model, engine) = try makeModel()
        model.start(.simple)
        for _ in 0..<50 { _ = engine.render(frames: 512); model.player.update() }
        model.settings.tempo = 180
        for _ in 0..<80 { _ = engine.render(frames: 512); model.player.update() }
        XCTAssertEqual(model.player.tempo, 180, accuracy: 0.01)
        model.stop()
    }

    func testTheDisplayOffsetFollowsTheOutput() throws {
        let (model, _) = try makeModel()
        model.settings.displayOffsets = ["AirPods": 80]
        XCTAssertEqual(model.player.displayOffsetMilliseconds, 0)
        model.outputName = "AirPods"
        XCTAssertEqual(model.player.displayOffsetMilliseconds, 80)
        model.outputName = "Speakers"
        XCTAssertEqual(model.player.displayOffsetMilliseconds, 0)
    }

    func testTapTempoAppliesOnlyWhenItIsReliable() throws {
        let (model, _) = try makeModel()
        model.tap(at: 0); model.tap(at: 0.4)
        model.applyTap()
        XCTAssertEqual(model.settings.tempo, 120, "two taps are not enough")
        model.tap(at: 0.8)
        model.applyTap()
        XCTAssertEqual(model.settings.tempo, 150)
        model.resetTap()
        XCTAssertEqual(model.tapTempo.count, 0)
    }

    func testTheTempoStaysInRange() throws {
        let (model, _) = try makeModel()
        model.settings.tempo = 255
        model.nudgeTempo(10)
        XCTAssertEqual(model.settings.tempo, 260)
        model.settings.tempo = 35
        model.nudgeTempo(-10)
        XCTAssertEqual(model.settings.tempo, 30)
    }

    func testEditingTheMapKeepsTheSelectionValid() throws {
        let (model, _) = try makeModel()
        model.edit { $0.insert(MapSection(label: "b", bars: 4, tempo: 100), after: 0) }
        XCTAssertTrue(model.document.isModified)
        model.select(section: 1)
        model.edit { $0.sections.removeLast() }
        XCTAssertEqual(model.selectedSection, 0)
        XCTAssertFalse(model.document.isModified, "back to the map as it was")
    }
}
