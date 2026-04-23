import Foundation

/// Central registry of UserDefaults keys used across the app.
///
/// Consolidating keys here prevents typo-induced silent data loss — a mistyped
/// string literal would write to a key no reader ever looks at. Every
/// `UserDefaults.standard.{set,string,integer,bool,…}(forKey:)` call in the
/// project should reference one of these constants.
enum UserDefaultsKey {

    // MARK: - Theme & Appearance
    static let appTheme = "appTheme"
    static let appAppearance = "appAppearance"
    static let sliderIcon = "sliderIcon"
    static let customSliderSymbol = "customSliderSymbol"
    static let appLanguage = "appLanguage"
    static let recentSliderSymbols = "recentSliderSymbols"
    static let useCoverGradient = "useCoverGradient"

    // MARK: - Auth (Sign in with Apple)
    static let appleUserID = "appleUserID"
    static let appleUserName = "appleUserName"
    static let appleUserEmail = "appleUserEmail"
    static let appleSignedIn = "appleSignedIn"
    static let didPassSignIn = "didPassSignIn"
    static let userNickname = "userNickname"

    // MARK: - Onboarding
    static let hasCompletedOnboarding = "hasCompletedOnboarding"

    // MARK: - Beat store
    static let userRole = "userRole"

    // MARK: - Library / tracks
    static let favoriteTrackIDs = "favoriteTrackIDs"
    static let trackPlayCounts = "trackPlayCounts"
    static let trackLastPlayed = "trackLastPlayed"
    static let trackDateAdded = "trackDateAdded"
    static let trackOrder = "trackOrder"

    // MARK: - Favorites (artists / albums)
    static let favoriteArtists = "favoriteArtists"
    static let favoriteAlbums = "favoriteAlbums"

    // MARK: - Playback
    static let crossfadeDuration = "crossfadeDuration"
    static let totalListeningSeconds = "totalListeningSeconds"

    // MARK: - Playlists
    static let userPlaylists = "userPlaylists"

    // MARK: - Stats
    static let statsHourlyPlays = "stats_hourlyPlays"
    static let statsCurrentStreak = "stats_currentStreak"
    static let statsBestStreak = "stats_bestStreak"
    static let statsUnlocked = "stats_unlocked"
    static let statsXP = "stats_xp"
    static let statsLevel = "stats_level"
    static let statsQueueAdds = "stats_queueAdds"
    static let statsWeekendPlays = "stats_weekendPlays"
    static let statsTotalDaysListened = "stats_totalDaysListened"
    static let statsLastPlayDate = "stats_lastPlayDate"
    static let statsLastCountedDay = "stats_lastCountedDay"

    // MARK: - Daily stats (date-parameterized)
    static func playsToday(_ day: String) -> String { "playsToday_\(day)" }
    static func listeningToday(_ day: String) -> String { "listeningToday_\(day)" }

    // MARK: - TON wallet
    static let tonConnectSession = "tonConnectSession"
    static let tonWalletAddress = "tonWalletAddress"
}
