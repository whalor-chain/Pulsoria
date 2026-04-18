import Foundation
import OSLog

/// Namespaced `Logger` instances for structured, category-filterable logging.
///
/// Use `Logger.audio.error(...)` instead of `print(...)` so log output
/// lands in the unified logging system (Console.app + `log stream`) with
/// a subsystem/category tag and a severity level, and so release builds
/// can redact or drop debug noise via OSLog's runtime filtering rather
/// than leaking strings to stdout.
extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Pulsoria"

    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let beatStore = Logger(subsystem: subsystem, category: "beatStore")
    static let genius = Logger(subsystem: subsystem, category: "genius")
    static let stats = Logger(subsystem: subsystem, category: "stats")
    static let ton = Logger(subsystem: subsystem, category: "tonWallet")
}
