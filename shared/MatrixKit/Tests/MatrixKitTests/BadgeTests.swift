// SPDX-License-Identifier: MIT

import XCTest
@testable import MatrixKit

final class BadgeStyleTests: XCTestCase {
    func testAbbreviation() {
        XCTAssertEqual(BadgeStyle.abbreviation(of: "Ardour"), "Ar")
        XCTAssertEqual(BadgeStyle.abbreviation(of: "system (capture)"), "Sy")
        XCTAssertEqual(BadgeStyle.abbreviation(of: "x"), "X")
        XCTAssertEqual(BadgeStyle.abbreviation(of: "1234"), "?")
        XCTAssertEqual(BadgeStyle.abbreviation(of: "Émile"), "ÉM".prefix(1) + "m")
    }

    /// Values computed by the rule of JackMate's BadgeUtils.
    func testHueMatchesJackMate() {
        XCTAssertEqual(BadgeStyle.hue(abbreviation: "Ar", fullName: "Ardour"), 0.4111111, accuracy: 1e-6)
        XCTAssertEqual(BadgeStyle.hue(abbreviation: "Su", fullName: "SuperCollider"), 0.1361111, accuracy: 1e-6)
        XCTAssertEqual(BadgeStyle.hue(abbreviation: "Ca", fullName: "Carla"), 0.2305556, accuracy: 1e-6)
    }

    func testStyleIsStableAndCaptureIsCyan() {
        XCTAssertEqual(BadgeStyle(client: "Ardour"), BadgeStyle(client: "Ardour"))
        XCTAssertNotEqual(BadgeStyle(client: "Ardour").top, BadgeStyle(client: "Carla").top)
        let cap = BadgeStyle(client: "system", kind: .capture)
        XCTAssertGreaterThan(cap.top.b, cap.top.r)
        XCTAssertGreaterThan(cap.top.g, cap.top.r)
        XCTAssertGreaterThan(cap.top.g, cap.bottom.g)   // lighter at the top
    }
}

@MainActor
final class AppIconsTests: XCTestCase {
    func testAnInstalledApplicationHasAnIcon() {
        XCTAssertNotNil(AppIcons.icon(forBundleID: "com.apple.finder"))
    }

    func testAnUnknownIdentifierHasNone() {
        XCTAssertNil(AppIcons.icon(forBundleID: "org.example.no-such-app-\(UUID().uuidString)"))
        XCTAssertNil(AppIcons.accent(forBundleID: "org.example.no-such-app"))
    }
}
