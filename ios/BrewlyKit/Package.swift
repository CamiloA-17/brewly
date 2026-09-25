// swift-tools-version: 6.0
import PackageDescription

/// All the code of the Brewly iOS app, split by layer and feature.
///
/// Dependency rule (Clean Architecture):
///   Features (Presentation) → BrewlyDomain ← BrewlyData → BrewlyNetworking
/// Features never import BrewlyData or BrewlyNetworking; AppFeature wires everything together.
let package = Package(
    name: "BrewlyKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "AppFeature", targets: ["AppFeature"]),
    ],
    dependencies: [
        .package(path: "../../shared/BrewlyShared"),
    ],
    targets: [
        // MARK: Domain
        .target(
            name: "BrewlyDomain",
            dependencies: [.product(name: "BrewlyCore", package: "BrewlyShared")]
        ),

        // MARK: Data
        .target(
            name: "BrewlyNetworking",
            dependencies: [.product(name: "BrewlyAPI", package: "BrewlyShared")]
        ),
        .target(
            name: "BrewlyData",
            dependencies: [
                "BrewlyDomain",
                "BrewlyNetworking",
                .product(name: "BrewlyAPI", package: "BrewlyShared"),
            ]
        ),

        // MARK: Presentation
        .target(
            name: "BrewlyDesignSystem",
            dependencies: ["BrewlyDomain"],
            resources: [.process("Resources")]
        ),
        .target(name: "AuthFeature", dependencies: ["BrewlyDomain", "BrewlyDesignSystem"], resources: [.process("Resources")]),
        .target(name: "BeansFeature", dependencies: ["BrewlyDomain", "BrewlyDesignSystem"], resources: [.process("Resources")]),
        .target(name: "RecipesFeature", dependencies: ["BrewlyDomain", "BrewlyDesignSystem"], resources: [.process("Resources")]),
        .target(name: "MethodsFeature", dependencies: ["BrewlyDomain", "BrewlyDesignSystem"], resources: [.process("Resources")]),
        .target(name: "FeedFeature", dependencies: ["BrewlyDomain", "BrewlyDesignSystem"], resources: [.process("Resources")]),
        .target(name: "ProfileFeature", dependencies: ["BrewlyDomain", "BrewlyDesignSystem"], resources: [.process("Resources")]),

        // MARK: Composition root
        .target(
            name: "AppFeature",
            dependencies: [
                "BrewlyDomain",
                "BrewlyData",
                "BrewlyNetworking",
                "BrewlyDesignSystem",
                "AuthFeature",
                "BeansFeature",
                "RecipesFeature",
                "MethodsFeature",
                "FeedFeature",
                "ProfileFeature",
            ],
            resources: [.process("Resources")]
        ),

        // MARK: Tests
        .testTarget(name: "BrewlyDomainTests", dependencies: ["BrewlyDomain"]),
        .testTarget(name: "BrewlyNetworkingTests", dependencies: ["BrewlyNetworking"]),
        .testTarget(name: "BrewlyDesignSystemTests", dependencies: ["BrewlyDesignSystem"]),
        .testTarget(name: "BrewlyDataTests", dependencies: ["BrewlyData", "BrewlyDomain", "BrewlyNetworking"]),
        .testTarget(name: "BeansFeatureTests", dependencies: ["BeansFeature", "BrewlyDomain"]),
        .testTarget(name: "RecipesFeatureTests", dependencies: ["RecipesFeature", "BrewlyDomain"]),
    ]
)
