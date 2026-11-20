import Combine
import Foundation

/// Ticks once a second so countdowns, alerts and the menu bar title stay current.
@MainActor
final class Clock: ObservableObject {
    @Published private(set) var now = Date()
    private var timer: AnyCancellable?

    init() {
        timer = Timer.publish(every: 1, tolerance: 0.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in self?.now = date }
    }
}
