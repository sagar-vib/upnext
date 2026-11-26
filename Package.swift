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
            path: "Sources/UpnextWidget",
            // Widget extensions start in NSExtensionMain, as Xcode links them. From the Swift entry
            // point the process exits before WidgetKit can ask for its widgets, so the gallery
            // never lists them.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-e", "-Xlinker", "_NSExtensionMain"])]
        ),
        // The snapshot the app writes for the widget, and the timeline pieces both draw.
        .target(
            name: "UpnextShared",
            path: "Sources/UpnextShared"
        ),
    ]
)
