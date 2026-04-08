// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Markyd",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "Markyd", targets: ["Markyd"]),
    ],
    dependencies: [
        .package(path: "../Demark"),
    ],
    targets: [
        .target(
            name: "MarkydCore",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .executableTarget(
            name: "Markyd",
            dependencies: [
                "MarkydCore",
                .product(name: "Demark", package: "Demark"),
            ],
            resources: [],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "MarkydCoreTests",
            dependencies: ["MarkydCore"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .enableExperimentalFeature("SwiftTesting"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
