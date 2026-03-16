// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CLUMenuBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "CLUMenuBar",
            path: "CLUMenuBar"
        ),
    ]
)
