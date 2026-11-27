import Combine
import Foundation
import UpnextShared
import WidgetKit

/// Keeps the desktop widget's snapshot file current, and asks WidgetKit to redraw the widget
/// when what it shows changes, and at least hourly.
@MainActor
final class WidgetPublisher {
    private let store: CalendarStore
    private let prefs: Preferences
    private var written: WidgetSnapshot?
    private var reloaded: Date?
    private var cancellables = Set<AnyCancellable>()

    init(store: CalendarStore, prefs: Preferences) {
        self.store = store
        self.prefs = prefs
        self.written = WidgetSnapshotFile.read()

        Publishers.Merge4(
            store.$events.map { _ in () },
            store.$markedDone.map { _ in () },
            store.$access.map { _ in () },
            prefs.objectWillChange.map { _ in () }
        )
        .debounce(for: .seconds(1), scheduler: RunLoop.main)
        .sink { [weak self] in self?.publish() }
        .store(in: &cancellables)

        // Keeps the minute-by-minute moments ahead of the widget, which rereads the file at its
        // hourly reload.
        Timer.publish(every: 15 * 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.publish() }
            .store(in: &cancellables)
    }

    private func publish() {
        let now = Date()
        let snapshot = WidgetSnapshotBuilder.snapshot(store: store, prefs: prefs, now: now)
        guard snapshot != written else { return }
        let reload = WidgetSnapshotBuilder.needsReload(from: written, to: snapshot, lastReload: reloaded, now: now)
        do {
            let url = WidgetSnapshotFile.url
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
            written = snapshot
        } catch {
            NSLog("Upnext couldn't write the widget snapshot: \(error.localizedDescription)")
            return
        }
        if reload {
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshotFile.kind)
            reloaded = now
        }
    }
}
