// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexMeter",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "CodexMeter",
            targets: ["CodexMeter"]
        )
    ],
    targets: [
        .executableTarget(
            name: "CodexMeter",
            path: "Sources/CodexMeter"
        ),
        .testTarget(
            name: "CodexMeterTests",
            dependencies: ["CodexMeter"],
            path: "Tests/CodexMeterTests",
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
