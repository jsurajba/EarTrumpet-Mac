// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EarTrumpet",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "EarTrumpet", targets: ["EarTrumpet"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "EarTrumpet",
            dependencies: [],
            path: "Sources/EarTrumpet"
        )
    ]
)
