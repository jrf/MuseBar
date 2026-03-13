// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MuseBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MuseBar",
            path: "Sources"
        )
    ]
)
