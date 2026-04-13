// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Interaction3D",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
    ],
    products: [
        .library(
            name: "Interaction3D",
            targets: ["Interaction3D"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/schwa/GeometryLite3D", from: "0.1.0"),
        .package(url: "https://github.com/schwa/SwiftFormats", from: "0.3.6"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.2.0"),
        .package(path: "/Users/schwa/Projects/Scratch/SpaceMouseWS"),
    ],
    targets: [
        .target(
            name: "Interaction3D",
            dependencies: [
                "GeometryLite3D",
                "SwiftFormats",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "SpaceMouse", package: "SpaceMouseWS"),
            ]
        ),
        .testTarget(
            name: "Interaction3DTests",
            dependencies: ["Interaction3D"]
        ),
    ]
)
