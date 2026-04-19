// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Soffit",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Soffit", targets: ["Soffit"])
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0"),
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "Soffit",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "SoffitTests",
            dependencies: ["Soffit"]
        )
    ]
)
