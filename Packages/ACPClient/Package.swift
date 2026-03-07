// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ACPClient",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "ACPClient",
            targets: ["ACPClient"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/wiedymi/swift-acp", branch: "main"),
    ],
    targets: [
        .target(
            name: "ACPClient",
            dependencies: [
                .product(name: "ACP", package: "swift-acp"),
                .product(name: "ACPModel", package: "swift-acp"),
            ]
        ),
        .testTarget(
            name: "ACPClientTests",
            dependencies: [
                "ACPClient",
                .product(name: "ACPModel", package: "swift-acp"),
            ]
        ),
    ]
)