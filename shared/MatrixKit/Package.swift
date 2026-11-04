// swift-tools-version: 5.9
// SPDX-License-Identifier: MIT
import PackageDescription

let package = Package(
    name: "MatrixKit",
    platforms: [.macOS("15.0")],
    products: [.library(name: "MatrixKit", targets: ["MatrixKit"])],
    targets: [
        .target(name: "MatrixKit"),
        .testTarget(name: "MatrixKitTests", dependencies: ["MatrixKit"]),
    ]
)
