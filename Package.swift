// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Upnext",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Upnext",
            dependencies: ["UpnextShared"],
            path: "Sources/Upnext"
        ),
        // The desktop widget, embedded in Upnext.app as PlugIns/UpnextWidget.appex.
        .executableTarget(
            name: "UpnextWidget",
            dependencies: ["UpnextShared"],
            path: "Sources/UpnextWidget"
        ),
        // The snapshot the app writes for the widget, and the timeline pieces both draw.
        .target(
            name: "UpnextShared",
            path: "Sources/UpnextShared"
        ),
    ]
)
