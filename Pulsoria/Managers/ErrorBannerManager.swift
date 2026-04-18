import Combine
import Foundation
import SwiftUI

/// Centralized channel for user-facing error messages.
///
/// Call sites report via `ErrorBannerManager.shared.report(...)` instead of
/// swallowing errors in `catch { }` blocks; `ContentView` subscribes and
/// shows a single alert so presentation is consistent everywhere and
/// there is only one place to change the UX later (e.g. swap to a banner).
@MainActor
final class ErrorBannerManager: ObservableObject {
    static let shared = ErrorBannerManager()

    @Published var errorToShow: AppError?

    private init() {}

    /// Report a pre-localized, user-friendly message.
    func report(_ message: String) {
        errorToShow = AppError(message: message)
    }

    /// Report an error. If `fallback` is provided it is preferred over
    /// `error.localizedDescription` — most Swift errors (URLError,
    /// NSError) produce technical strings unsuitable for end users.
    func report(_ error: Error, fallback: String? = nil) {
        let message = fallback ?? error.localizedDescription
        errorToShow = AppError(message: message)
    }

    func dismiss() {
        errorToShow = nil
    }
}

struct AppError: Identifiable, Equatable {
    let id = UUID()
    let message: String
}
