// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AudioRemote",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "AudioRemote",
            targets: ["AudioRemote"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0")
        // Sparkle temporarily removed - will be added back later with proper configuration
        // .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "AudioRemote",
            dependencies: [
                .product(name: "Vapor", package: "vapor")
                // Sparkle temporarily removed
                // .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "AudioRemote",
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
