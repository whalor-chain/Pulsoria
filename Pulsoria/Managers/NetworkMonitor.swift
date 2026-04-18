import Foundation
import Network

/// App-lifetime reachability observer.
///
/// The previous implementation created an `NWPathMonitor` inside
/// `ContentView.onAppear` and let it go out of scope; the monitor stayed
/// alive only because its GCD queue retained it, and the `pathUpdateHandler`
/// wrote back to a `@State` via `DispatchQueue.main.async` — a pattern that
/// sidestepped SwiftUI's observation model and could not be reused by
/// other screens.
///
/// `NetworkMonitor.shared` is constructed once at first access, runs for
/// the life of the process, and exposes `isOffline` as an `@Published`
/// `@MainActor` property so any view can subscribe via `@ObservedObject`.
@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isOffline: Bool = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "Pulsoria.NetworkMonitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let offline = path.status != .satisfied
            Task { @MainActor [weak self] in
                self?.isOffline = offline
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
