import AppKit
import ServiceManagement
import SwiftUI

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show(store: CalendarStore, prefs: Preferences) {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(store: store, prefs: prefs)))
            window.title = "Upnext Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}

struct SettingsView: View {
    @ObservedObject var store: CalendarStore
    @ObservedObject var prefs: Preferences

    var body: some View {
        TabView {
            GeneralSettings(prefs: prefs)
                .tabItem { Label("General", systemImage: "gearshape") }
            MenuBarSettings(prefs: prefs)
                .tabItem { Label("Menu bar", systemImage: "menubar.rectangle") }
            CalendarSettings(store: store, prefs: prefs)
                .tabItem { Label("Calendars", systemImage: "calendar") }
            NotificationSettings(prefs: prefs)
                .tabItem { Label("Notifications", systemImage: "bell") }
        }
        .frame(width: 520, height: 470)
    }
}

private struct GeneralSettings: View {
    @ObservedObject var prefs: Preferences
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                Toggle("Open Upnext at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
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
        if actual != launchAtLogin {
            launchAtLogin = actual
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
                Picker("Sound", selection: $prefs.alertSound) {
                    ForEach(AlertSound.all, id: \.self) { Text($0).tag($0) }
                }
                .disabled(prefs.alertLead == .off)
                .onChange(of: prefs.alertSound) { _, name in
                    NSSound(named: NSSound.Name(name))?.play()
                }
            }
            Section {
                Text("A floating card with a Join button appears for timed events that have a video link or other guests. It shows over full screen apps and stays until you join, dismiss it, or 10 minutes pass.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
