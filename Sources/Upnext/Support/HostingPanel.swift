import AppKit
import SwiftUI

/// Borderless panel that floats over every Space (including full screen apps)
/// and can take keyboard focus without activating the app.
final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Lets the first click on a non-key panel hit the button under the cursor.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Reports the natural size of its content so the panel can fit it.
private struct SizeReporting<Content: View>: View {
    let content: Content
    let onResize: (CGSize) -> Void

    var body: some View {
        content
            .fixedSize()
            .background(GeometryReader { proxy in
                Color.clear.onChange(of: proxy.size, initial: true) { _, size in onResize(size) }
            })
    }
}

/// A FloatingPanel that hosts SwiftUI content, sizes itself to that content and
/// is positioned by the caller.
@MainActor
final class HostingPanel: NSObject, NSWindowDelegate {
    let window: FloatingPanel
    /// Bottom-left origin for a panel of the given size, in screen coordinates.
    var placement: (CGSize) -> NSPoint = { _ in .zero }
    var onVisibilityChange: ((Bool) -> Void)?
    /// Key presses while the panel is key. Return true when handled.
    var keyHandler: ((NSEvent) -> Bool)?

    private let closesOnOutsideClick: Bool
    private var hostView: NSView?
    private var size: CGSize = .zero
    private var clickMonitor: Any?
    private var keyMonitor: Any?

    init(closesOnOutsideClick: Bool) {
        self.closesOnOutsideClick = closesOnOutsideClick
        window = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        super.init()
        window.isFloatingPanel = true
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.isMovable = false
        window.animationBehavior = .utilityWindow
        window.delegate = self
    }

    var isVisible: Bool { window.isVisible }

    func setContent<Content: View>(_ content: Content) {
        let host = FirstMouseHostingView(rootView: SizeReporting(content: content) { [weak self] size in
            self?.resize(to: size)
        })
        window.contentView = host
        hostView = host
    }

    func show(makeKey: Bool) {
        if let fitting = hostView?.fittingSize, fitting.width > 0, fitting.height > 0 {
            size = fitting
        }
        place()
        if makeKey {
            window.makeKeyAndOrderFront(nil)
        } else {
            window.orderFrontRegardless()
        }
        if closesOnOutsideClick && clickMonitor == nil {
            clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                MainActor.assumeIsolated { self?.close() }
            }
        }
        // A local monitor sees Esc and Return before SwiftUI does, so they always reach us.
        if makeKey && keyHandler != nil && keyMonitor == nil {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                let handled = MainActor.assumeIsolated { self?.handleKey(event) ?? false }
                return handled ? nil : event
            }
        }
        onVisibilityChange?(true)
    }

    func close() {
        guard window.isVisible else { return }
        window.orderOut(nil)
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        onVisibilityChange?(false)
    }

    func windowDidResignKey(_ notification: Notification) {
        if closesOnOutsideClick {
            close()
        }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        guard event.window === window else { return false }
        return keyHandler?(event) ?? false
    }

    private func resize(to newSize: CGSize) {
        guard newSize.width > 0, newSize.height > 0, newSize != size else { return }
        size = newSize
        if window.isVisible {
            place()
        }
    }

    private func place() {
        window.setFrame(NSRect(origin: placement(size), size: size), display: true)
        window.invalidateShadow()
        // SwiftUI redraws the rounded surface slightly later; refresh the shadow once it has.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            MainActor.assumeIsolated { self?.window.invalidateShadow() }
        }
    }
}
