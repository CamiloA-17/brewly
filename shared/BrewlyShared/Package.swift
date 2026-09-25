// swift-tools-version: 6.0
import PackageDescription

/// Code shared by the iOS app and the server.
///
/// - `BrewlyCore`: domain vocabulary (enums mirroring database domains/checks),
///   brewing math and validation rules.
/// - `BrewlyAPI`: the HTTP API contract (request/response DTOs).
let package = Package(
    name: "BrewlyShared",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "BrewlyCore", targets: ["BrewlyCore"]),
        .library(name: "BrewlyAPI", targets: ["BrewlyAPI"]),
    ],
    targets: [
        .target(name: "BrewlyCore"),
        .target(name: "BrewlyAPI", dependencies: ["BrewlyCore"]),
        .testTarget(name: "BrewlyCoreTests", dependencies: ["BrewlyCore"]),
        .testTarget(name: "BrewlyAPITests", dependencies: ["BrewlyAPI"]),
    ]
)
