// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "NowPlayingCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "NowPlayingCore", targets: ["NowPlayingCore"])
    ],
    targets: [
        .target(name: "NowPlayingCore"),
        .testTarget(name: "NowPlayingCoreTests", dependencies: ["NowPlayingCore"]),
    ]
)
