// swift-tools-version: 5.9
// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import Foundation
import PackageDescription

// The engine of klick, patched and with a CoreAudio backend, is one static library built by klick/engine/build_engine.sh
// (klick/build/libklickengine.a). It contains the libraries it needs.
let engineDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("build").path

let package = Package(
    name: "Klick",
    platforms: [.macOS("15.0")],
    targets: [
        // The C interface of the engine (klick_engine.h) and the link settings of its static library.
        .target(
            name: "CKlickEngine",
            linkerSettings: [
                .unsafeFlags(["-L\(engineDirectory)"]),
                .linkedLibrary("klickengine"),
                .linkedLibrary("c++"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("Accelerate"),
            ]
        ),
        // Swift view of the engine: playback, tempo map, beat events. No UI. Unit tested with an engine that renders
        // offline, so that the tests make no sound.
        .target(name: "KlickEngine", dependencies: ["CKlickEngine"]),
        .testTarget(name: "KlickEngineTests", dependencies: ["KlickEngine"]),
    ]
)
