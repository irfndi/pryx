// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PryxKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "PryxKit", targets: ["PryxKit"])
    ],
    targets: [
        .target(
            name: "PryxKit",
            swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "PryxKitTests",
            dependencies: ["PryxKit"]
        ),
    ]
)
