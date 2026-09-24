// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BrewlyKit",
    defaultLocalization: "es",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "BrewlyDomain", targets: ["BrewlyDomain"]),
        .library(name: "BrewlyData", targets: ["BrewlyData"]),
        .library(name: "BrewlyFeatures", targets: ["BrewlyFeatures"]),
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.20.0"),
    ],
    targets: [
        // Modelos y contratos. Sin dependencias externas: fácil de probar.
        .target(name: "BrewlyDomain"),
        // Implementación de los repositorios contra Supabase.
        .target(
            name: "BrewlyData",
            dependencies: [
                "BrewlyDomain",
                .product(name: "Supabase", package: "supabase-swift"),
            ]
        ),
        // Pantallas SwiftUI + view models. Solo conoce los protocolos del dominio.
        .target(name: "BrewlyFeatures", dependencies: ["BrewlyDomain"]),
        .testTarget(name: "BrewlyDomainTests", dependencies: ["BrewlyDomain"]),
    ]
)
