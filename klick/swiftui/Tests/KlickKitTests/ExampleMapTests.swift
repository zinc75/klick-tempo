// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import XCTest
import KlickEngine
@testable import KlickKit

@MainActor
final class ExampleMapTests: XCTestCase {
    /// .../Tests/KlickKitTests/ExampleMapTests.swift -> .../Examples
    static let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("Examples")

    func testEveryExampleIsAValidMap() throws {
        for example in ExampleMap.all {
            let sections = try example.sections(in: Self.directory)
            XCTAssertGreaterThan(sections.count, 1, example.id)
            XCTAssertFalse(example.title.isEmpty)
            XCTAssertFalse(example.detail.isEmpty)
            // the engine accepts it as it is
            let engine = try Engine(offline: true, rate: 48000)
            XCTAssertNoThrow(try engine.setMap(sections.map(\.engineSection)), example.id)
        }
    }

    func testTheExamplesShowWhatTheyAreAbout() throws {
        let silent = try ExampleMap(id: "silent-bars").sections(in: Self.directory)
        XCTAssertTrue(silent.contains { $0.muted })
        let ramp = try ExampleMap(id: "slow-ramp").sections(in: Self.directory)
        XCTAssertEqual(ramp.first?.tempoEnd, 120)
        let meters = try ExampleMap(id: "meter-changes").sections(in: Self.directory)
        XCTAssertEqual(meters.map { "\($0.beats)/\($0.denominator)" }, ["4/4", "6/8", "7/8", "5/4", "4/4"])
    }

    func testAnExampleOpensAsANewMap() throws {
        let engine = try Engine(offline: true, rate: 48000)
        let model = AppModel(player: Player(engine: engine, soundsDirectory: PlayerTests.sounds), store: nil)
        let example = ExampleMap(id: "practice-ramp")
        try model.openExample(example, in: Self.directory)
        XCTAssertEqual(model.document.sections.count, 5)
        XCTAssertNil(model.document.url, "the file of the example is never the one that is saved")
        XCTAssertEqual(model.document.displayName, example.title)
        XCTAssertFalse(model.document.isModified)
    }
}
