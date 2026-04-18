import Testing
import Foundation
@testable import Pulsoria

struct StatsManagerTests {

    // MARK: - AchievementRarity

    @Test func rarityOrdering() {
        #expect(AchievementRarity.common < .uncommon)
        #expect(AchievementRarity.uncommon < .rare)
        #expect(AchievementRarity.rare < .epic)
        #expect(AchievementRarity.epic < .legendary)
    }

    @Test func rarityXPRewardEscalates() {
        #expect(AchievementRarity.common.xp == 25)
        #expect(AchievementRarity.uncommon.xp == 50)
        #expect(AchievementRarity.rare.xp == 100)
        #expect(AchievementRarity.epic.xp == 200)
        #expect(AchievementRarity.legendary.xp == 500)

        let xps = [AchievementRarity.common, .uncommon, .rare, .epic, .legendary].map(\.xp)
        #expect(xps == xps.sorted())
    }

    @Test func rarityLocalizedTitles() {
        #expect(AchievementRarity.common.titleRu == "Обычная")
        #expect(AchievementRarity.common.titleEn == "Common")
        #expect(AchievementRarity.legendary.titleRu == "Легендарная")
        #expect(AchievementRarity.legendary.titleEn == "Legendary")
    }

    // MARK: - AchievementID

    @Test func achievementRarityMapping() {
        #expect(AchievementID.firstTrack.rarity == .common)
        #expect(AchievementID.collector10.rarity == .uncommon)
        #expect(AchievementID.hoarder50.rarity == .rare)
        #expect(AchievementID.vault100.rarity == .epic)
        #expect(AchievementID.librarian500.rarity == .legendary)
        #expect(AchievementID.god10000.rarity == .legendary)
    }

    @Test func achievementIconsAreAllNonEmpty() {
        for achievement in AchievementID.allCases {
            #expect(!achievement.icon.isEmpty, "Missing icon for \(achievement.rawValue)")
            #expect(!achievement.titleRu.isEmpty)
            #expect(!achievement.titleEn.isEmpty)
            #expect(!achievement.descRu.isEmpty)
            #expect(!achievement.descEn.isEmpty)
        }
    }

    @Test func achievementCategoryCoverage() {
        // Each category must have at least one achievement assigned.
        let categories = Set(AchievementID.allCases.map(\.category))
        #expect(categories.count == AchievementCategory.allCases.count)
    }

    // MARK: - AchievementID.progress

    private func zeroContext() -> AchievementContext {
        AchievementContext(
            tracks: 0, plays: 0, hours: 0, favorites: 0, playlists: 0,
            streak: 0, bestStreak: 0, artists: 0, listenedArtists: 0,
            nightOwlDone: false, earlyBirdDone: false, lunchDone: false,
            weekendPlays: 0, maxTrackPlays: 0, todayPlays: 0, queueAdds: 0,
            tracksOver50: 0, tracksOver100: 0, playlistsWith10: 0,
            totalDaysListened: 0
        )
    }

    @Test func firstTrackProgressCapsAtOne() {
        var ctx = zeroContext()
        #expect(AchievementID.firstTrack.progress(ctx) == (0, 1))

        ctx = AchievementContext(
            tracks: 1, plays: 0, hours: 0, favorites: 0, playlists: 0,
            streak: 0, bestStreak: 0, artists: 0, listenedArtists: 0,
            nightOwlDone: false, earlyBirdDone: false, lunchDone: false,
            weekendPlays: 0, maxTrackPlays: 0, todayPlays: 0, queueAdds: 0,
            tracksOver50: 0, tracksOver100: 0, playlistsWith10: 0,
            totalDaysListened: 0
        )
        let (cur, target) = AchievementID.firstTrack.progress(ctx)
        #expect(cur == 1)
        #expect(target == 1)
    }

    @Test func collectorProgressCapsAtTen() {
        let ctx = AchievementContext(
            tracks: 47, plays: 0, hours: 0, favorites: 0, playlists: 0,
            streak: 0, bestStreak: 0, artists: 0, listenedArtists: 0,
            nightOwlDone: false, earlyBirdDone: false, lunchDone: false,
            weekendPlays: 0, maxTrackPlays: 0, todayPlays: 0, queueAdds: 0,
            tracksOver50: 0, tracksOver100: 0, playlistsWith10: 0,
            totalDaysListened: 0
        )
        let (cur, target) = AchievementID.collector10.progress(ctx)
        #expect(cur == 10)
        #expect(target == 10)
    }

    @Test func hourProgressIsFractional() {
        let ctx = AchievementContext(
            tracks: 0, plays: 0, hours: 0.5, favorites: 0, playlists: 0,
            streak: 0, bestStreak: 0, artists: 0, listenedArtists: 0,
            nightOwlDone: false, earlyBirdDone: false, lunchDone: false,
            weekendPlays: 0, maxTrackPlays: 0, todayPlays: 0, queueAdds: 0,
            tracksOver50: 0, tracksOver100: 0, playlistsWith10: 0,
            totalDaysListened: 0
        )
        let (cur, target) = AchievementID.hour1.progress(ctx)
        #expect(cur == 0.5)
        #expect(target == 1)
    }

    @Test func nightOwlIsBinary() {
        var ctx = zeroContext()
        #expect(AchievementID.nightOwl.progress(ctx) == (0, 1))

        ctx = AchievementContext(
            tracks: 0, plays: 0, hours: 0, favorites: 0, playlists: 0,
            streak: 0, bestStreak: 0, artists: 0, listenedArtists: 0,
            nightOwlDone: true, earlyBirdDone: false, lunchDone: false,
            weekendPlays: 0, maxTrackPlays: 0, todayPlays: 0, queueAdds: 0,
            tracksOver50: 0, tracksOver100: 0, playlistsWith10: 0,
            totalDaysListened: 0
        )
        #expect(AchievementID.nightOwl.progress(ctx) == (1, 1))
    }

    @Test func theBeginningIsAlwaysComplete() {
        let ctx = zeroContext()
        // Secret: awarded on first open — progress is 1/1 regardless.
        #expect(AchievementID.theBeginning.progress(ctx) == (1, 1))
    }

    // MARK: - ListeningPersonality

    @Test func listeningPersonalityHasAllLabels() {
        let all: [ListeningPersonality] = [
            .casual, .dedicated, .explorer, .nightCrawler, .marathoner, .eclectic
        ]
        for p in all {
            #expect(!p.titleRu.isEmpty)
            #expect(!p.titleEn.isEmpty)
            #expect(!p.descRu.isEmpty)
            #expect(!p.descEn.isEmpty)
            #expect(!p.icon.isEmpty)
        }
    }

    // MARK: - StatsManager (state-dependent)

    @MainActor
    @Test func totalAchievementsEqualsCaseCount() {
        #expect(StatsManager.shared.totalAchievements == AchievementID.allCases.count)
    }

    @MainActor
    @Test func xpProgressAndToNextLevel() {
        let stats = StatsManager.shared
        let originalXP = stats.xp
        defer { stats.xp = originalXP }

        stats.xp = 0
        #expect(stats.xpProgress == 0)
        #expect(stats.xpToNextLevel == 300)

        stats.xp = 150 // halfway through the first level
        #expect(abs(stats.xpProgress - 0.5) < 0.0001)
        #expect(stats.xpToNextLevel == 150)

        stats.xp = 300 // exactly at level boundary — progress resets to 0
        #expect(stats.xpProgress == 0)
        #expect(stats.xpToNextLevel == 300)

        stats.xp = 450 // 150 into the second level
        #expect(abs(stats.xpProgress - 0.5) < 0.0001)
        #expect(stats.xpToNextLevel == 150)
    }

    @MainActor
    @Test func completedCountReflectsUnlockedSet() {
        let stats = StatsManager.shared
        let originalUnlocked = stats.unlockedAchievements
        defer { stats.unlockedAchievements = originalUnlocked }

        stats.unlockedAchievements = []
        #expect(stats.completedCount == 0)

        stats.unlockedAchievements = [
            AchievementID.firstTrack.rawValue,
            AchievementID.firstPlay.rawValue,
            AchievementID.firstHeart.rawValue
        ]
        #expect(stats.completedCount == 3)
    }
}
