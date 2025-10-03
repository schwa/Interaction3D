// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Interaction3D",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "Interaction3D",
            targets: ["Interaction3D"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/schwa/GeometryLite3D", branch: "main"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "Interaction3D",
            dependencies: [
                "GeometryLite3D",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ]
        ),
        .testTarget(
            name: "Interaction3DTests",
            dependencies: ["Interaction3D"]
        ),
    ]
)
