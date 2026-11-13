// swift-tools-version: 5.9
// SPDX-License-Identifier: MIT
import PackageDescription

let package = Package(
    name: "AppearanceKit",
    platforms: [.macOS("15.0")],
    products: [.library(name: "AppearanceKit", targets: ["AppearanceKit"])],
    targets: [
        .target(name: "AppearanceKit"),
        .testTarget(name: "AppearanceKitTests", dependencies: ["AppearanceKit"]),
    ]
)
