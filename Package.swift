// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AppRunner",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.11.0")
    ],
    targets: [
        .executableTarget(
            name: "AppRunner",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Sources/AppRunner"
        )
    ]
)
