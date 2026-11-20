// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Upnext",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Upnext",
            path: "Sources/Upnext"
        )
    ]
)
