// swift-tools-version: 5.9
// SPDX-License-Identifier: MIT
import PackageDescription

let package = Package(
    name: "UpdateKit",
    platforms: [.macOS("15.0")],
    products: [.library(name: "UpdateKit", targets: ["UpdateKit"])],
    dependencies: [
        .package(path: "../AppearanceKit"),
    ],
    targets: [
        .target(name: "UpdateKit", dependencies: ["AppearanceKit"]),
        .testTarget(name: "UpdateKitTests", dependencies: ["UpdateKit"]),
    ]
)
