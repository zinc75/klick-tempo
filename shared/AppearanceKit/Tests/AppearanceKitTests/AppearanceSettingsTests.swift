// SPDX-License-Identifier: MIT

import XCTest
import SwiftUI
@testable import AppearanceKit

@MainActor
final class AppearanceSettingsTests: XCTestCase {
    private var suites: [String] = []

    /// An empty store of its own, removed at the end.
    private func store() -> UserDefaults {
        let name = "AppearanceKitTests.\(UUID().uuidString)"
        suites.append(name)
        return UserDefaults(suiteName: name)!
    }

    override func tearDown() {
        for name in suites { UserDefaults.standard.removePersistentDomain(forName: name) }
        suites = []
    }

    func testDefaultsAreDarkAndTheColourOfTheApplication() {
        let settings = AppearanceSettings(appAccent: .orange, defaults: store())
        XCTAssertEqual(settings.mode, .dark)
        XCTAssertEqual(settings.accent, .app)
        XCTAssertEqual(settings.effectiveAccent, .orange)
        XCTAssertNotNil(settings.tint)
    }

    func testTheApplicationCanGiveItsOwnColour() {
        let own = Color(red: 1, green: 0.45, blue: 0.1)
        let settings = AppearanceSettings(appAccent: .orange, appColor: own, defaults: store())
        XCTAssertEqual(settings.appTint, own)
        XCTAssertEqual(settings.tint, own)
        settings.accent = .orange
        XCTAssertEqual(settings.tint, Color.orange)
        settings.accent = .system
        XCTAssertNil(settings.tint)
    }

    func testChoicesAreKeptBetweenLaunches() {
        let defaults = store()
        let first = AppearanceSettings(appAccent: .red, defaults: defaults)
        first.mode = .system
        first.accent = .green
        let second = AppearanceSettings(appAccent: .red, defaults: defaults)
        XCTAssertEqual(second.mode, .system)
        XCTAssertEqual(second.accent, .green)
        XCTAssertEqual(second.effectiveAccent, .green)
    }

    func testFollowingMacOSLeavesNoTint() {
        let settings = AppearanceSettings(appAccent: .red, defaults: store())
        settings.accent = .system
        XCTAssertNil(settings.effectiveAccent)
        XCTAssertNil(settings.tint)
    }

    func testUnknownStoredValuesFallBackToTheDefaults() {
        let defaults = store()
        defaults.set("sepia", forKey: AppearanceSettings.modeKey)
        defaults.set("yellow", forKey: AppearanceSettings.accentKey)
        let settings = AppearanceSettings(appAccent: .orange, defaults: defaults)
        XCTAssertEqual(settings.mode, .dark)
        XCTAssertEqual(settings.accent, .app)
    }

    /// The first versions kept "light" or "dark" under the same key.
    func testTheChoiceOfTheFirstVersionsIsRead() {
        let defaults = store()
        defaults.set("light", forKey: AppearanceSettings.modeKey)
        XCTAssertEqual(AppearanceSettings(appAccent: .red, defaults: defaults).mode, .light)
    }

    func testTheColourOfTheApplicationHasToBeOneOfThePalette() {
        XCTAssertEqual(AppearanceSettings(appAccent: .system, defaults: store()).appAccent, .blue)
        XCTAssertEqual(AppearanceSettings(appAccent: .app, defaults: store()).appAccent, .blue)
        XCTAssertEqual(AppearanceSettings(appAccent: .green, defaults: store()).appAccent, .green)
    }

    func testThePaletteHasSixColoursAndEachHasAColour() {
        XCTAssertEqual(AccentChoice.palette.count, 6)
        XCTAssertEqual(Set(AccentChoice.palette.map(\.rawValue)), ["blue", "purple", "pink", "red", "orange", "green"])
        for choice in AccentChoice.palette { XCTAssertNotNil(choice.color, choice.rawValue) }
        XCTAssertNil(AccentChoice.app.color)
        XCTAssertNil(AccentChoice.system.color)
    }

    func testAppearanceOfEachMode() {
        XCTAssertEqual(AppearanceMode.dark.nsAppearance?.name, .darkAqua)
        XCTAssertEqual(AppearanceMode.light.nsAppearance?.name, .aqua)
        XCTAssertNil(AppearanceMode.system.nsAppearance)
    }
}
