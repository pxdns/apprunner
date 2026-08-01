// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AppRunner",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "AppRunner",
            path: "Sources/AppRunner"
        )
    ]
)
