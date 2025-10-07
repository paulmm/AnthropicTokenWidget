// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AnthropicTokenWidget",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .executable(
            name: "AnthropicTokenWidget",
            targets: ["AnthropicTokenWidget"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-algorithms", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "AnthropicTokenWidget",
            dependencies: [
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "Collections", package: "swift-collections")
            ],
            path: ".",
            exclude: [
                "Tests",
                "Configuration",
                "Info.plist",
                "Entitlements.plist",
                "README.md",
                "Package.swift",
                ".gitignore",
                "open_in_xcode.sh"
            ],
            sources: [
                "Models",
                "Services",
                "Widget",
                "App"
            ],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-enable-dynamic-replacement-chaining"])
            ]
        ),
        .testTarget(
            name: "AnthropicTokenWidgetTests",
            dependencies: ["AnthropicTokenWidget"],
            path: "Tests"
        )
    ]
)