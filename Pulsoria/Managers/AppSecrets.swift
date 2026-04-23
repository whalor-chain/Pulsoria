import Foundation
import OSLog

/// Tiny accessor for build-time secrets that must not live in source
/// control. Values come from `AppSecrets.plist` (gitignored) which is
/// a copy of `AppSecrets.example.plist`.
///
/// Setup (once per developer machine / CI):
///   1. `cp Pulsoria/AppSecrets.example.plist Pulsoria/AppSecrets.plist`
///   2. Fill in the real values.
///   3. In Xcode, make sure the file is in the Pulsoria target's
///      "Copy Bundle Resources" phase.
///
/// If the file is missing, the accessor returns empty strings — the app
/// still builds (handy for CI with no secrets), features that require
/// the secret just no-op silently.
enum AppSecrets {
    /// Genius API access token. Used to hit `api.genius.com` from
    /// `GeniusManager` + the inline library search in `LibraryView`.
    /// Rotate periodically at <https://genius.com/api-clients>.
    static var geniusToken: String {
        string(for: "GeniusAPIToken")
    }

    // MARK: - Internal

    private static let cache: [String: String] = load()

    private static func load() -> [String: String] {
        guard let url = Bundle.main.url(forResource: "AppSecrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(
                from: data, format: nil
              ) as? [String: Any] else {
            Logger.beatStore.info(
                "AppSecrets.plist not found in bundle — features needing secrets will no-op"
            )
            return [:]
        }
        var dict: [String: String] = [:]
        for (key, value) in plist {
            if let s = value as? String { dict[key] = s }
        }
        return dict
    }

    private static func string(for key: String) -> String {
        cache[key] ?? ""
    }
}
