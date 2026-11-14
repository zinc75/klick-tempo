// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import XCTest
import KlickEngine
@testable import KlickKit

struct NoServer: LocalizedError {
    var errorDescription: String? { "no server" }
}

/// A second backend for the tests: an engine that renders offline at 44.1 kHz (so that it is told from the first one), an output of
/// its own name, and the options of availability and failure.
@MainActor
final class OtherBackend: AudioBackend {
    let id = "other"
    let name = "Other"
    var availability = BackendAvailability.available
    var fails = false
    private(set) var refreshes = 0

    func makeEngine() throws -> Engine {
        if fails { throw NoServer() }
        return try Engine(offline: true, rate: 44100)
    }

    func refresh(player: Player, host: BackendHost) -> OutputInfo? {
        refreshes += 1
        var info = OutputInfo()
        info.name = "server"
        info.sampleRate = Double(player.sampleRate)
        return info
    }

    func displayOffsetKey(for info: OutputInfo) -> String { "other:" + info.name }
}

@MainActor
final class BackendTests: XCTestCase {
    func makeModel(store: SettingsStore? = nil, other given: OtherBackend? = nil) throws -> (AppModel, OtherBackend) {
        let other = given ?? OtherBackend()
        let engine = try Engine(offline: true, rate: 48000)
        let player = Player(engine: engine, soundsDirectory: PlayerTests.sounds)
        return (AppModel(player: player, store: store, backends: [OfflineBackend(), other]), other)
    }

    func testTheFirstBackendIsTheDefault() throws {
        let (model, _) = try makeModel()
        XCTAssertEqual(model.backend.id, "offline")
        XCTAssertEqual(model.backends.map(\.id), ["offline", "other"])
        XCTAssertNil(model.settings.backendID, "nothing is kept before the user chooses")
    }

    func testSwitchingMakesAnotherEngineAndKeepsTheChoice() throws {
        let store = MemoryStore()
        let (model, other) = try makeModel(store: store)
        XCTAssertEqual(model.player.sampleRate, 48000)
        model.switchBackend(to: "other")
        XCTAssertEqual(model.backend.id, "other")
        XCTAssertEqual(model.player.sampleRate, 44100, "the engine is made again, on the new backend")
        XCTAssertEqual(model.settings.backendID, "other")
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.output.name, "server", "what the new output says is read at once")
        XCTAssertEqual(model.outputName, "other:server", "the key of the display offset is the backend's")
        XCTAssertGreaterThan(other.refreshes, 0)
        // and back
        model.switchBackend(to: "offline")
        XCTAssertEqual(model.backend.id, "offline")
        XCTAssertEqual(model.player.sampleRate, 48000)
        let saved = try JSONDecoder().decode(ClickSettings.self, from: try XCTUnwrap(store.data))
        XCTAssertEqual(saved.backendID, "offline")
    }

    func testSwitchingStopsWhatPlaysAndTheNewEngineCanPlay() throws {
        let (model, _) = try makeModel()
        model.start(.simple)
        XCTAssertTrue(model.isPlaying)
        model.switchBackend(to: "other")
        XCTAssertFalse(model.isPlaying)
        model.start(.simple)
        XCTAssertTrue(model.isPlaying, "the sounds are loaded again on the new engine")
        XCTAssertNil(model.errorMessage)
        model.stop()
    }

    func testABackendThatCannotBeUsedLeavesThingsAsTheyAre() throws {
        let other = OtherBackend()
        other.availability = .unavailable("JACK is not running")
        let (model, _) = try makeModel(other: other)
        model.switchBackend(to: "other")
        XCTAssertEqual(model.backend.id, "offline")
        XCTAssertEqual(model.errorMessage, "JACK is not running")
        XCTAssertEqual(model.player.sampleRate, 48000)
        XCTAssertNil(model.settings.backendID)
    }

    func testAnEngineThatCannotBeMadeLeavesThingsAsTheyAre() throws {
        let other = OtherBackend()
        other.fails = true
        let (model, _) = try makeModel(other: other)
        model.switchBackend(to: "other")
        XCTAssertEqual(model.backend.id, "offline")
        XCTAssertEqual(model.errorMessage, "no server")
        XCTAssertEqual(model.player.sampleRate, 48000)
        XCTAssertNil(model.settings.backendID)
    }

    func testAnUnknownBackendIsIgnored() throws {
        let (model, _) = try makeModel()
        model.switchBackend(to: "nothing")
        XCTAssertEqual(model.backend.id, "offline")
        XCTAssertNil(model.errorMessage)
    }

    func testTheBackendKeptLastTimeIsTakenAtLaunch() throws {
        var saved = ClickSettings()
        saved.backendID = "other"
        saved.tempo = 90
        let store = MemoryStore()
        store.data = try JSONEncoder().encode(saved)
        let (model, _) = try makeModel(store: store)
        XCTAssertEqual(model.backend.id, "other")
        XCTAssertEqual(model.player.sampleRate, 44100)
        XCTAssertEqual(model.settings.tempo, 90)
    }

    func testABackendThatIsNotOnOfferIsIgnoredAtLaunch() throws {
        var saved = ClickSettings()
        saved.backendID = "jack"   // kept by the version of the collection, opened by another one
        let store = MemoryStore()
        store.data = try JSONEncoder().encode(saved)
        let (model, _) = try makeModel(store: store)
        XCTAssertEqual(model.backend.id, "offline")
        XCTAssertEqual(model.player.sampleRate, 48000)
        XCTAssertNil(model.errorMessage)
    }

    func testABackendThatCouldNotBeUsedAtLaunchCanBeTriedAgain() throws {
        var saved = ClickSettings()
        saved.backendID = "other"
        let store = MemoryStore()
        store.data = try JSONEncoder().encode(saved)
        let other = OtherBackend()
        other.fails = true
        let (model, _) = try makeModel(store: store, other: other)
        XCTAssertEqual(model.backend.id, "offline", "the first backend plays meanwhile")
        XCTAssertEqual(model.errorMessage, "no server")
        XCTAssertEqual(model.fallenBackFrom?.id, "other", "the window offers to try it again")
        XCTAssertEqual(model.settings.backendID, "other", "the choice of the user is kept")
        model.switchBackend(to: "other")
        XCTAssertEqual(model.backend.id, "offline", "still not there")
        XCTAssertNotNil(model.fallenBackFrom)
        other.fails = false
        model.switchBackend(to: "other")
        XCTAssertEqual(model.backend.id, "other")
        XCTAssertNil(model.fallenBackFrom)
        XCTAssertNil(model.errorMessage)
    }

    func testAFallBackIsNotAChoice() throws {
        let (model, _) = try makeModel()
        model.switchBackend(to: "other", remember: false)
        XCTAssertEqual(model.backend.id, "other")
        XCTAssertNil(model.settings.backendID)
    }

    // MARK: settings

    func testSettingsWrittenBeforeTheBackendsStillLoad() throws {
        // Only a few keys, as an older version wrote them: the rest keeps its default value.
        let old = Data(#"{"tempo": 100, "beats": 3, "denominator": 4, "pattern": "Xxx"}"#.utf8)
        let s = try JSONDecoder().decode(ClickSettings.self, from: old)
        XCTAssertEqual(s.tempo, 100)
        XCTAssertEqual(s.beats, 3)
        XCTAssertNil(s.backendID)
        XCTAssertEqual(s.backendOptions, [:])
        XCTAssertEqual(s.accentVolume, ClickSettings().accentVolume)
        XCTAssertEqual(try JSONDecoder().decode(ClickSettings.self, from: Data("{}".utf8)), ClickSettings())
    }

    func testTheOptionsOfABackendAreKeptPerBackend() throws {
        var s = ClickSettings()
        XCTAssertNil(s.option("autoconnect", backend: "jack"))
        s.setOption("autoconnect", "1", backend: "jack")
        s.setOption("port", "system:playback_1", backend: "jack")
        s.setOption("x", "y", backend: "other")
        XCTAssertEqual(s.option("autoconnect", backend: "jack"), "1")
        XCTAssertNil(s.option("autoconnect", backend: "other"))
        let back = try JSONDecoder().decode(ClickSettings.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back, s)
        s.setOption("autoconnect", nil, backend: "jack")
        s.setOption("port", nil, backend: "jack")
        XCTAssertNil(s.backendOptions["jack"], "a backend without options leaves no entry")
        XCTAssertNotNil(s.backendOptions["other"])
    }
}
