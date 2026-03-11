// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodeXEditor",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CodeXEditor", targets: ["CodeXEditor"]),
    ],
    dependencies: [
        // Indentation rules and bracket pair completion
        .package(url: "https://github.com/ChimeHQ/TextFormation", from: "0.8.2"),
        // Language detection and pre-built tree-sitter grammars
        .package(url: "https://github.com/CodeEditApp/CodeEditLanguages", exact: "0.1.20"),
        // Tree-sitter Swift bindings (transitive via CodeEditLanguages, declared explicitly for direct import)
        .package(url: "https://github.com/ChimeHQ/SwiftTreeSitter.git", from: "0.9.0"),
    ],
    targets: [
        .target(
            name: "CodeXEditor",
            dependencies: [
                .product(name: "TextFormation", package: "TextFormation"),
                .product(name: "CodeEditLanguages", package: "CodeEditLanguages"),
                .product(name: "SwiftTreeSitter", package: "SwiftTreeSitter"),
            ]
        ),
    ]
)
