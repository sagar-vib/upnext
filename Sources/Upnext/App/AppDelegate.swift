import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var prefs: Preferences!
    private var clock: Clock!
    private var store: CalendarStore!
    private var statusItem: StatusItemController!
    private var panel: HostingPanel!
    private var panelSession: PanelSession!
    private var alerts: MeetingAlertController!
    private var settings: SettingsWindowController!
    private var widget: WidgetPublisher!
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()

        prefs = Preferences.shared
        settings = SettingsWindowController()
        clock = Clock()
        store = CalendarStore(prefs: prefs)
        statusItem = StatusItemController(store: store, clock: clock, prefs: prefs)
        alerts = MeetingAlertController(store: store, clock: clock, prefs: prefs)
        widget = WidgetPublisher(store: store, prefs: prefs)

        panel = HostingPanel(closesOnOutsideClick: true)
        panelSession = PanelSession()
        panel.setContent(PanelView(
            store: store,
            clock: clock,
            prefs: prefs,
            session: panelSession,
            commands: PanelCommands(
                openSettings: { [weak self] in self?.openSettings() },
                refresh: { [weak self] in
                    self?.store.syncAccounts()
                    self?.store.reload()
                },
                quit: { NSApp.terminate(nil) }
            )
        ))
        panel.placement = { [weak self] size in self?.panelOrigin(for: size) ?? .zero }
        panel.onVisibilityChange = { [weak self] visible in
            self?.statusItem.setHighlighted(visible)
            if visible {
                self?.store.syncAccounts()
            } else {
                self?.panelSession.didClose()
            }
        }
        panel.keyHandler = { [weak self] event in self?.handlePanelKey(event) ?? false }
        statusItem.onClick = { [weak self] in self?.togglePanel() }

        prefs.$globalShortcuts
            .sink { [weak self] enabled in self?.configureShortcuts(enabled: enabled) }
            .store(in: &cancellables)
        prefs.$appearance
            .sink { [weak self] appearance in self?.applyAppearance(appearance) }
            .store(in: &cancellables)

        if store.access == .notDetermined {
            Task { await store.requestAccess() }
        }
    }

    /// The desktop widget opens upnext://open when clicked, to show the dropdown.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.contains(where: { $0.scheme == "upnext" }), let panel, !panel.isVisible else { return }
        panel.show(makeKey: true)
    }

    @objc func openSettings() {
        panel.close()
        settings.show(store: store, prefs: prefs)
    }

    private func togglePanel() {
        if panel.isVisible {
            panel.close()
        } else if !panel.closedMomentsAgo {
            panel.show(makeKey: true)
        }
    }

    private func joinUpcoming() {
        guard let event = store.joinable(at: Date()) else {
            NSSound.beep()
            return
        }
        panel.close()
        EventActions.join(event)
    }

    /// Ends the top card's meeting early, so the dropdown and menu bar move on to the next one.
    private func markCurrentDone() {
        let now = Date()
        guard let event = store.featured(at: now), event.isOngoing(at: now) else {
            NSSound.beep()
            return
        }
        store.markDone(event)
    }

    private func handlePanelKey(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53: // Esc
            panel.close()
            return true
        case 36, 76: // Return, Enter
            joinUpcoming()
            return true
        case 2 where event.modifierFlags.intersection([.command, .shift, .option, .control]) == .command: // ⌘D
            markCurrentDone()
            return true
        default:
            return false
        }
    }

    /// Light or dark for the dropdown, meeting alerts and Settings, whatever the system uses.
    /// Set per window, so the menu bar item keeps following the menu bar.
    private func applyAppearance(_ appearance: AppAppearance) {
        let nsAppearance: NSAppearance? = switch appearance {
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        case .system: nil
        }
        panel.window.appearance = nsAppearance
        alerts.appearance = nsAppearance
        settings.appearance = nsAppearance
    }

    private func configureShortcuts(enabled: Bool) {
        let hotKeys = HotKeyCenter.shared
        hotKeys.unregisterAll()
        guard enabled else { return }
        hotKeys.register(.togglePanel) { [weak self] in self?.togglePanel() }
        hotKeys.register(.joinMeeting) { [weak self] in self?.joinUpcoming() }
    }

    /// Drops the panel from the left edge of the menu bar item, kept on screen.
    private func panelOrigin(for size: CGSize) -> NSPoint {
        guard let anchor = statusItem.buttonFrame else {
            let frame = NSScreen.main?.visibleFrame ?? .zero
            return NSPoint(x: frame.maxX - size.width - 8, y: frame.maxY - size.height - 4)
        }
        let anchorCenter = NSPoint(x: anchor.midX, y: anchor.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(anchorCenter) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        let x = min(max(anchor.minX, visible.minX + 8), visible.maxX - size.width - 8)
        return NSPoint(x: x, y: anchor.minY - size.height - 5)
    }

    /// A menu bar app has no visible menu, but this keeps Cmd-W, Cmd-Q and Cmd-, working in the Settings window.
    private func installMainMenu() {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appMenu.addItem(withTitle: "Quit Upnext", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        let mainMenu = NSMenu()
        mainMenu.addItem(appItem)
        NSApp.mainMenu = mainMenu
    }
}
