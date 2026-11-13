// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import Foundation

/// Where the application finds what it ships: the sounds of klick and the example maps.
enum KlickResources {
    /// The sounds of klick: in the application bundle; in a development run, where the build scripts put them.
    static var soundsDirectory: URL {
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("klick/samples"),
           FileManager.default.fileExists(atPath: bundled.path) { return bundled }
        if let path = ProcessInfo.processInfo.environment["KLICK_SOUNDS"] { return URL(fileURLWithPath: path) }
        // .../klick/swiftui/Sources/KlickUI/KlickResources.swift -> .../klick/build/samples
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("build/samples")
    }

    /// The example maps: in the application bundle; in a development run, the folder of the sources.
    static var examplesDirectory: URL {
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("Examples"),
           FileManager.default.fileExists(atPath: bundled.path) { return bundled }
        // .../klick/swiftui/Sources/KlickUI/KlickResources.swift -> .../klick/swiftui/Examples
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Examples")
    }
}
