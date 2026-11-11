// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TheGipher",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "GipherCore"),
        .executableTarget(name: "TheGipher", dependencies: ["GipherCore"]),
        .testTarget(name: "GipherCoreTests", dependencies: ["GipherCore"]),
    ]
)
