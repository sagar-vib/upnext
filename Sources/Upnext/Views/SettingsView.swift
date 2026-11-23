import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show(store: CalendarStore, prefs: Preferences) {
        if window == nil {
            window = Self.makeWindow(store: store, prefs: prefs)
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    /// Standard Mac settings window: one toolbar button per pane.
    private static func makeWindow(store: CalendarStore, prefs: Preferences) -> NSWindow {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(pane("General", symbol: "gearshape", GeneralSettings(prefs: prefs)))
        tabs.addTabViewItem(pane("Menu bar", symbol: "menubar.rectangle", MenuBarSettings(prefs: prefs)))
        tabs.addTabViewItem(pane("Calendars", symbol: "calendar", CalendarSettings(store: store, prefs: prefs)))
        tabs.addTabViewItem(pane("Notifications", symbol: "bell", NotificationSettings(prefs: prefs)))

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    private static func pane<Content: View>(_ title: String, symbol: String, _ content: Content) -> NSTabViewItem {
        let controller = NSHostingController(rootView: content.frame(width: 500, height: 420))
        controller.title = title
        let item = NSTabViewItem(viewController: controller)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        return item
    }
}

private struct GeneralSettings: View {
    @ObservedObject var prefs: Preferences
    private let launchAtLogin = State(initialValue: SMAppService.mainApp.status == .enabled) // see IconButton

    var body: some View {
        Form {
            Section {
                Toggle("Open Upnext at login", isOn: launchAtLogin.projectedValue)
                    .onChange(of: launchAtLogin.wrappedValue) { _, enabled in setLaunchAtLogin(enabled) }
                Picker("Open events in", selection: $prefs.calendarApp) {
                    ForEach(CalendarApp.allCases) { Text($0.title).tag($0) }
                }
            }
            Section("Keyboard shortcuts") {
                Toggle("Enable system-wide shortcuts", isOn: $prefs.globalShortcuts)
                LabeledContent("Show or hide menu bar calendar", value: HotKey.togglePanel.display)
                LabeledContent("Join upcoming meeting", value: HotKey.joinMeeting.display)
            }
            Section("In the menu bar calendar") {
                LabeledContent("Join current or next meeting", value: "Return")
                LabeledContent("Close", value: "Esc")
            }
        }
        .formStyle(.grouped)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Upnext: could not update login item: \(error.localizedDescription)")
        }
        let actual = SMAppService.mainApp.status == .enabled
        if actual != launchAtLogin.wrappedValue {
            launchAtLogin.wrappedValue = actual
        }
    }
}

private struct MenuBarSettings: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        Form {
            Section("Upcoming event in menu bar") {
                Picker("Preview upcoming event", selection: $prefs.previewLead) {
                    ForEach(PreviewLead.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Event title", isOn: $prefs.showEventTitle)
                Toggle("Event time", isOn: $prefs.showEventTime)
                Stepper("Title length: \(prefs.titleLength) characters", value: $prefs.titleLength, in: 8...60, step: 2)
                    .disabled(!prefs.showEventTitle)
            }
            Section("Include events") {
                Picker("Days", selection: $prefs.dayRange) {
                    ForEach(DayRange.allCases) { Text($0.title).tag($0) }
                }
                Toggle("All-day events", isOn: $prefs.includeAllDay)
                Toggle("Events without guests", isOn: $prefs.includeWithoutGuests)
                Toggle("Events without video link or location", isOn: $prefs.includeWithoutLocation)
                Picker("New day starts at", selection: $prefs.dayStartHour) {
                    ForEach(0...6, id: \.self) { hour in
                        Text(hour == 0 ? "Midnight" : "\(hour) AM").tag(hour)
                    }
                }
                Text("Meetings before this time show with the previous day, for late-night calls across time zones.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

@MainActor
private struct CalendarSettings: View {
    @ObservedObject var store: CalendarStore
    @ObservedObject var prefs: Preferences

    var body: some View {
        Form {
            if store.calendarGroups.isEmpty {
                Text("No calendars yet. Allow calendar access, or add accounts in System Settings > Internet Accounts.")
                    .foregroundStyle(.secondary)
            }
            ForEach(store.calendarGroups) { group in
                Section(group.id) {
                    ForEach(group.calendars) { calendar in
                        Toggle(isOn: shown(calendar.id)) {
                            HStack(spacing: 8) {
                                Circle().fill(calendar.color).frame(width: 10, height: 10)
                                Text(calendar.title)
                            }
                        }
                    }
                }
            }
            Section {
                Text("Hidden calendars don't appear in the menu bar and don't trigger meeting alerts.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func shown(_ id: String) -> Binding<Bool> {
        Binding(
            get: { !prefs.hiddenCalendarIDs.contains(id) },
            set: { visible in
                if visible {
                    prefs.hiddenCalendarIDs.remove(id)
                } else {
                    prefs.hiddenCalendarIDs.insert(id)
                }
            }
        )
    }
}

private struct NotificationSettings: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        Form {
            Section("Upcoming meeting alert") {
                Picker("Show alert", selection: $prefs.alertLead) {
                    ForEach(AlertLead.allCases) { Text($0.title).tag($0) }
                }
                Group {
                    Picker("Sound", selection: $prefs.alertSound) {
                        ForEach(AlertSound.system, id: \.self) { Text($0).tag($0) }
                        if AlertSound.isFile(prefs.alertSound) {
                            Text(AlertSound.displayName(prefs.alertSound)).tag(prefs.alertSound)
                        }
                    }
                    .onChange(of: prefs.alertSound) { _, sound in AlertSound.play(sound) }
                    LabeledContent("Use a sound file") {
                        HStack {
                            Button("Play") { AlertSound.play(prefs.alertSound) }
                            Button("Choose…", action: chooseSoundFile)
                        }
                    }
                }
                .disabled(prefs.alertLead == .off)
            }
            Section {
                Text("To match Notion Calendar, click Choose… and pick its sound. The picker opens inside Notion Calendar's app folder when it's installed in Applications.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("A floating card with a Join button appears for timed events that have a video link or other guests. It shows over full screen apps and stays until you join, dismiss it, or 10 minutes pass.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func chooseSoundFile() {
        let panel = NSOpenPanel()
        panel.message = "Choose a sound for meeting alerts"
        panel.allowedContentTypes = [.audio]
        panel.treatsFilePackagesAsDirectories = true
        panel.directoryURL = AlertSound.notionCalendarResources
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard AlertSound.canPlay(url) else {
            let alert = NSAlert()
            alert.messageText = "macOS can't play \(url.lastPathComponent)"
            alert.informativeText = "Convert it to .wav, .m4a or .mp3 first, for example with:\nffmpeg -i \"\(url.lastPathComponent)\" \"\(url.deletingPathExtension().lastPathComponent).wav\""
            alert.runModal()
            return
        }
        prefs.alertSound = url.path
    }
}
