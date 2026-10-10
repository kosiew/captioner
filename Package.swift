// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Captioner",
    platforms: [.macOS("27.0")],
    targets: [
        .executableTarget(name: "Captioner", path: "Sources/Captioner")
    ]
)
