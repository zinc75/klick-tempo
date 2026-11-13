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
    // What an application of the family that adds a backend uses (the version of the collection, with JACK): the window, the model,
    // the engine and its C interface.
    products: [
        .library(name: "KlickUI", targets: ["KlickUI"]),
        .library(name: "KlickKit", targets: ["KlickKit"]),
        .library(name: "KlickEngine", targets: ["KlickEngine"]),
        .library(name: "CKlickEngine", targets: ["CKlickEngine"]),
        .executable(name: "Klick", targets: ["Klick"]),
    ],
    dependencies: [
        // Look and feel shared with the other tools (glass blocks, window fill), MIT.
        .package(path: "../../shared/MatrixKit"),
        // The look (dark, system, light) and the accent, with the content of the settings window, MIT.
        .package(path: "../../shared/AppearanceKit"),
    ],
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
        // What the application knows, without any UI: tempo map files and documents, tap tempo, meters, settings,
        // the equivalent command line. Unit tested.
        .target(name: "KlickKit", dependencies: ["KlickEngine"]),
        .testTarget(name: "KlickKitTests", dependencies: ["KlickKit"]),
        // The window, the pages and the menus of the application, shared by the applications of the family (Klick, and the version of
        // the collection that has JACK). As in JackMate, UI code is main-actor isolated by default.
        .target(
            name: "KlickUI",
            dependencies: [
                "KlickKit", "KlickEngine",
                .product(name: "MatrixKit", package: "MatrixKit"),
                .product(name: "AppearanceKit", package: "AppearanceKit"),
            ],
            swiftSettings: [.unsafeFlags(["-Xfrontend", "-default-isolation", "-Xfrontend", "MainActor"])]
        ),
        // The application: its name, its colour and the backends it offers; nothing else.
        .executableTarget(
            name: "Klick",
            dependencies: ["KlickUI", .product(name: "AppearanceKit", package: "AppearanceKit")]
        ),
    ]
)
