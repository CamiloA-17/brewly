// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BrewlyServer",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.100.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.9.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.8.0"),
        .package(url: "https://github.com/vapor/sql-kit.git", from: "3.28.0"),
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.21.0"),
        .package(url: "https://github.com/vapor/jwt.git", from: "5.0.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", "3.0.0" ..< "5.0.0"),
        .package(path: "../shared/BrewlyShared"),
    ],
    targets: [
        .executableTarget(
            name: "BrewlyServer",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "SQLKit", package: "sql-kit"),
                .product(name: "PostgresNIO", package: "postgres-nio"),
                .product(name: "JWT", package: "jwt"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "BrewlyAPI", package: "BrewlyShared"),
            ]
        ),
        .testTarget(
            name: "BrewlyServerTests",
            dependencies: [
                .target(name: "BrewlyServer"),
                .product(name: "XCTVapor", package: "vapor"),
            ],
            // XCTVapor's callback-based helpers predate strict concurrency checking.
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
