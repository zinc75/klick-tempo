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

    func testTheLiveViewOpensWithThePlayAndClosesOnRequest() throws {
        let (model, _) = try makeModel()
        XCTAssertFalse(model.showsLiveView)
        model.togglePlayback()
        XCTAssertTrue(model.showsLiveView)
        model.leaveLiveView()
        XCTAssertFalse(model.showsLiveView)
        XCTAssertEqual(model.page, .metronome)
        XCTAssertTrue(model.isPlaying, "the settings can be changed while it plays")
        model.enterLiveView()
        XCTAssertTrue(model.showsLiveView)
        model.show(.map)
        XCTAssertFalse(model.showsLiveView, "choosing a page leaves the live view")
        model.togglePlayback()
        XCTAssertFalse(model.showsLiveView)
        model.show(.sounds)
        model.togglePlayback()
        XCTAssertFalse(model.showsLiveView, "the settings pages stay in view")
        model.enterLiveView()
        model.stop()
        XCTAssertFalse(model.showsLiveView)
    }

    func testTheWayBackLeadsToThePageOfWhatPlays() throws {
        let (model, _) = try makeModel()
        model.show(.sounds)
        model.togglePlayback()
        model.show(.sounds)
        model.enterLiveView()
        model.leaveLiveView()
        XCTAssertEqual(model.page, .metronome, "not the last page that was open")
        model.choose(.map)
        model.enterLiveView()
        model.leaveLiveView()
        XCTAssertEqual(model.page, .map, "the mode chosen in the live view")
        model.stop()
    }

    func testEditingSavingAndOpeningAMap() throws {
        let (model, _) = try makeModel()
        XCTAssertEqual(model.document.sections.count, 1)
        XCTAssertFalse(model.document.isModified)
        model.updateSection(at: 0) { $0.bars = 4; $0.tempo = 90 }
        XCTAssertTrue(model.document.isModified)
        model.addSection(MapSection(label: "verse", bars: 8, tempo: 100, tempoEnd: 120))
        XCTAssertEqual(model.document.sections.map(\.label), ["intro", "verse"])
        XCTAssertEqual(model.selectedSection, 1, "the new section is selected")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("klick-map-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("song.klick")
        try model.saveMap(to: file)
        XCTAssertFalse(model.document.isModified)
        XCTAssertEqual(model.document.name, "song.klick")
        model.newMap()
        XCTAssertEqual(model.document.sections.count, 1)
        try model.openMap(at: file)
        XCTAssertEqual(model.document.sections.map(\.bars), [4, 8])
        XCTAssertEqual(model.document.sections[1].tempoEnd, 120)
        XCTAssertFalse(model.document.isModified)
        model.removeSection(at: 1)
        model.removeSection(at: 0)
        XCTAssertEqual(model.document.sections.count, 1, "the last section stays")
    }

    func testAnUnreadableFileLeavesTheMapAlone() throws {
        let (model, _) = try makeModel()
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("klick-bad-\(UUID().uuidString).klick")
        try "this is not a map".write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertThrowsError(try model.openMap(at: file))
        XCTAssertEqual(model.document.sections.first?.label, "intro")
    }

    func testListeningToASoundIsNotPlaying() throws {
        let (model, _) = try makeModel()
        model.preview(.accent, sound: .builtIn(.sine))
        XCTAssertTrue(model.isPreviewing)
        XCTAssertFalse(model.isPlaying, "a short click is not the metronome")
        XCTAssertFalse(model.showsLiveView)
        XCTAssertEqual(model.settings.sound, .builtIn(.square), "the sound in use is left alone")
        model.togglePlayback()
        XCTAssertFalse(model.isPreviewing, "starting ends the listening")
        XCTAssertTrue(model.isPlaying)
        model.preview(.bar, sound: .builtIn(.click))
        XCTAssertFalse(model.isPreviewing, "no listening while it plays")
        model.stop()
    }

    func testTheDisplayOffsetIsKeptPerOutput() throws {
        let (model, _) = try makeModel()
        model.outputName = "Speakers"
        model.displayOffset = 0
        XCTAssertNil(model.settings.displayOffsets["Speakers"], "an offset of 0 is not stored")
        model.displayOffset = 180
        XCTAssertEqual(model.player.displayOffsetMilliseconds, 180)
        model.outputName = "Headphones"
        XCTAssertEqual(model.displayOffset, 0, "another output has its own offset")
        XCTAssertEqual(model.player.displayOffsetMilliseconds, 0)
        model.outputName = "Speakers"
        XCTAssertEqual(model.displayOffset, 180)
        model.displayOffset = 0
        XCTAssertNil(model.settings.displayOffsets["Speakers"])
    }

    func testAnOutputThatIsNotThereFallsBackToTheSystem() throws {
        let (model, _) = try makeModel()
        model.chooseOutput(uid: "klick-test-no-such-device")
        XCTAssertTrue(model.isChosenOutputMissing)
        XCTAssertEqual(model.settings.outputDeviceUID, "klick-test-no-such-device", "the choice is kept for when it is plugged in")
        XCTAssertNil(model.errorMessage)
        model.chooseOutput(uid: nil)
        XCTAssertFalse(model.isChosenOutputMissing)
        XCTAssertNil(model.settings.outputDeviceUID)
    }

    func testSettingsWithoutAnOutputStillLoad() throws {
        var saved = ClickSettings()
        saved.tempo = 100
        saved.outputDeviceUID = "something"
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(saved)) as? [String: Any])
        json["outputDeviceUID"] = nil   // as written before the choice of the output existed
        let store = MemoryStore()
        store.data = try JSONSerialization.data(withJSONObject: json)
        let (model, _) = try makeModel(store: store)
        XCTAssertEqual(model.settings.tempo, 100)
        XCTAssertNil(model.settings.outputDeviceUID)
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
