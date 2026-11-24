import AppKit
import Combine

/// The menu bar item: a calendar icon with today's date, plus the upcoming
/// event's title and countdown when it's close enough.
@MainActor
final class StatusItemController: NSObject {
    var onClick: (() -> Void)?

    private let statusItem: NSStatusItem
    private let store: CalendarStore
    private let clock: Clock
    private let prefs: Preferences
    private var cancellables = Set<AnyCancellable>()
    private var renderedDay = 0
    private var renderedTitle: String?

    init(store: CalendarStore, clock: Clock, prefs: Preferences) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.store = store
        self.clock = clock
        self.prefs = prefs
        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(buttonClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
            button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        }

        // @Published fires before the value changes, so render on the next run loop pass.
        Publishers.Merge4(
            clock.$now.map { _ in () },
            store.$events.map { _ in () },
            store.$markedDone.map { _ in () },
            prefs.objectWillChange.map { _ in () }
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] in self?.render() }
        .store(in: &cancellables)

        render()
    }

    /// Frame of the menu bar button in screen coordinates, used to anchor the panel.
    var buttonFrame: NSRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    func setHighlighted(_ highlighted: Bool) {
        statusItem.button?.highlight(highlighted)
    }

    @objc private func buttonClicked() {
        onClick?()
    }

    private func render() {
        guard let button = statusItem.button else { return }
        let now = clock.now

        let day = Calendar.current.component(.day, from: prefs.workDay.start(containing: now))
        let title = menuBarTitle(now: now)
        guard title != renderedTitle || day != renderedDay else { return }
        renderedTitle = title
        renderedDay = day

        // Like Notion Calendar: a bar before the event text. The date icon only appears
        // when there's no event to show, so the item never shrinks to nothing.
        button.title = title
        button.image = title.isEmpty ? Self.calendarIcon(day: day) : Self.eventBar
        button.imagePosition = title.isEmpty ? .imageOnly : .imageLeading
    }

    private func menuBarTitle(now: Date) -> String {
        guard store.access == .granted, let event = store.featured(at: now) else { return "" }
        guard event.isOngoing(at: now) || prefs.previewLead.includes(event.start.timeIntervalSince(now)) else { return "" }
        return Fmt.menuBarTitle(
            event,
            now: now,
            showTitle: prefs.showEventTitle,
            showTime: prefs.showEventTime,
            maxLength: prefs.titleLength
        )
    }

    /// Template image of a rounded vertical bar, shown before the event text.
    private static let eventBar: NSImage = {
        let image = NSImage(size: NSSize(width: 5, height: 16), flipped: false) { _ in
            NSColor.black.set()
            NSBezierPath(roundedRect: NSRect(x: 1, y: 2, width: 3, height: 12), xRadius: 1.5, yRadius: 1.5).fill()
            return true
        }
        image.isTemplate = true
        return image
    }()

    /// Template image of a calendar page showing the day of the month.
    private static func calendarIcon(day: Int) -> NSImage {
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            let page = rect.insetBy(dx: 1.5, dy: 1.5)
            let outline = NSBezierPath(roundedRect: page, xRadius: 3, yRadius: 3)
            outline.lineWidth = 1.2
            NSColor.black.set()
            outline.stroke()

            let bandHeight: CGFloat = 3.5
            NSGraphicsContext.saveGraphicsState()
            outline.addClip()
            NSBezierPath(rect: NSRect(x: page.minX, y: page.maxY - bandHeight, width: page.width, height: bandHeight)).fill()
            NSGraphicsContext.restoreGraphicsState()

            let number = "\(day)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 8, weight: .bold),
                .foregroundColor: NSColor.black,
            ]
            let textSize = number.size(withAttributes: attributes)
            let body = NSRect(x: page.minX, y: page.minY, width: page.width, height: page.height - bandHeight)
            number.draw(at: NSPoint(x: body.midX - textSize.width / 2, y: body.midY - textSize.height / 2), withAttributes: attributes)
            return true
        }
        image.isTemplate = true
        return image
    }
}
