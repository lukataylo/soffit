// swift-tools-version: 5.9
import PackageDescription
import Foundation

// SOFFIT_PRO=1 in the environment switches the package over to the Pro
// variant: pulls in Sparkle (auto-update via DMG appcast) and SwiftTerm
// (embedded terminal pane). The App Store variant resolves and links
// neither — Apple disallows third-party update mechanisms for sandboxed
// MAS apps, and subprocess execution under the sandbox is forbidden.
//
// Set by `scripts/build-app.sh` when SOFFIT_VARIANT=pro.
let isPro = ProcessInfo.processInfo.environment["SOFFIT_PRO"] == "1"

var packageDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0")
]

var targetDependencies: [Target.Dependency] = [
    .product(name: "MarkdownUI", package: "swift-markdown-ui")
]

if isPro {
    packageDependencies.append(.package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"))
    packageDependencies.append(.package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.2.0"))
    targetDependencies.append(.product(name: "Sparkle", package: "Sparkle"))
    targetDependencies.append(.product(name: "SwiftTerm", package: "SwiftTerm"))
}

let package = Package(
    name: "Soffit",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Soffit", targets: ["Soffit"])
    ],
    dependencies: packageDependencies,
    targets: [
        .executableTarget(
            name: "Soffit",
            dependencies: targetDependencies,
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
