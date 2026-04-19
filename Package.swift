// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Workbench",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Workbench", targets: ["Workbench"])
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0")
    ],
    targets: [
        .executableTarget(
            name: "Workbench",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ],
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "WorkbenchTests",
            dependencies: ["Workbench"]
        )
    ]
)
