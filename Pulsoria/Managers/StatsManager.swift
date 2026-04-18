import Foundation
import Combine

// MARK: - Achievement Context

struct AchievementContext {
    let tracks: Int
    let plays: Int
    let hours: Double
    let favorites: Int
    let playlists: Int
    let streak: Int
    let bestStreak: Int
    let artists: Int
    let listenedArtists: Int
    let nightOwlDone: Bool
    let earlyBirdDone: Bool
    let lunchDone: Bool
    let weekendPlays: Int
    let maxTrackPlays: Int
    let todayPlays: Int
    let queueAdds: Int
    let tracksOver50: Int
    let tracksOver100: Int
    let playlistsWith10: Int
    let totalDaysListened: Int
}

// MARK: - Achievement Rarity

enum AchievementRarity: Int, Comparable {
    case common = 0
    case uncommon = 1
    case rare = 2
    case epic = 3
    case legendary = 4

    static func < (lhs: AchievementRarity, rhs: AchievementRarity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var titleRu: String {
        switch self {
        case .common: return "Обычная"
        case .uncommon: return "Необычная"
        case .rare: return "Редкая"
        case .epic: return "Эпическая"
        case .legendary: return "Легендарная"
        }
    }

    var titleEn: String {
        switch self {
        case .common: return "Common"
        case .uncommon: return "Uncommon"
        case .rare: return "Rare"
        case .epic: return "Epic"
        case .legendary: return "Legendary"
        }
    }

    var xp: Int {
        switch self {
        case .common: return 25
        case .uncommon: return 50
        case .rare: return 100
        case .epic: return 200
        case .legendary: return 500
        }
    }
}

// MARK: - Achievement Definition

enum AchievementID: String, CaseIterable, Identifiable {
    // --- Collection ---
    case firstTrack
    case collector10
    case hoarder50
    case vault100
    case archive200
    case librarian500

    // --- Playback ---
    case firstPlay
    case warming50
    case musicLover100
    case regular250
    case audiophile500
    case legend1000
    case titan2500
    case immortal5000
    case god10000

    // --- Listening Time ---
    case minute30
    case hour1
    case marathon5
    case dedicated24
    case obsessed100
    case noLife250
    case transcended500
    case eternal1000

    // --- Favorites ---
    case firstHeart
    case fan10
    case devotee25
    case loveCollector50
    case heartOverflow100

    // --- Playlists ---
    case playlistCreator
    case curator5
    case organizer10
    case architect20

    // --- Streaks ---
    case streak3
    case streak7
    case streak14
    case streak30
    case streak60
    case streak100
    case streak365

    // --- Time of Day ---
    case nightOwl
    case earlyBird
    case lunchBreak
    case weekendWarrior

    // --- Artists ---
    case explorer5
    case globetrotter15
    case cosmopolitan25
    case worldTraveler50

    // --- Track Mastery ---
    case repeatKing
    case trackObsession
    case hitFactory

    // --- Daily Intensity ---
    case productiveDay10
    case bingeDay25
    case insaneDay50

    // --- Queue ---
    case queueStarter
    case queueMaster50

    // --- Milestones ---
    case week1
    case month1
    case halfYear
    case year1

    // --- Playlist Size ---
    case bigPlaylist10
    case megaPlaylist25

    // --- Secret / Fun ---
    case theBeginning
    case fullCircle

    var id: String { rawValue }

    var rarity: AchievementRarity {
        switch self {
        case .firstTrack, .firstPlay, .firstHeart, .playlistCreator, .minute30, .queueStarter, .theBeginning:
            return .common
        case .collector10, .warming50, .hour1, .fan10, .streak3, .earlyBird, .nightOwl, .explorer5,
             .productiveDay10, .lunchBreak, .week1:
            return .uncommon
        case .hoarder50, .musicLover100, .regular250, .marathon5, .devotee25, .curator5, .streak7, .streak14,
             .globetrotter15, .repeatKing, .weekendWarrior, .bingeDay25, .queueMaster50, .bigPlaylist10, .month1:
            return .rare
        case .vault100, .audiophile500, .dedicated24, .obsessed100, .loveCollector50, .organizer10, .streak30,
             .streak60, .cosmopolitan25, .trackObsession, .insaneDay50, .megaPlaylist25, .halfYear, .fullCircle:
            return .epic
        case .archive200, .librarian500, .legend1000, .titan2500, .immortal5000, .god10000,
             .noLife250, .transcended500, .eternal1000, .heartOverflow100, .architect20,
             .streak100, .streak365, .worldTraveler50, .hitFactory, .year1:
            return .legendary
        }
    }

    var icon: String {
        switch self {
        // Collection
        case .firstTrack: return "square.and.arrow.down"
        case .collector10: return "tray.full"
        case .hoarder50: return "archivebox"
        case .vault100: return "building.columns"
        case .archive200: return "books.vertical"
        case .librarian500: return "book.closed.fill"
        // Playback
        case .firstPlay: return "play.circle"
        case .warming50: return "waveform"
        case .musicLover100: return "music.note"
        case .regular250: return "music.note.tv"
        case .audiophile500: return "headphones"
        case .legend1000: return "crown"
        case .titan2500: return "bolt.shield"
        case .immortal5000: return "shield.checkered"
        case .god10000: return "crown.fill"
        // Listening Time
        case .minute30: return "clock.badge.checkmark"
        case .hour1: return "clock"
        case .marathon5: return "figure.run"
        case .dedicated24: return "moon.stars"
        case .obsessed100: return "flame"
        case .noLife250: return "flame.circle"
        case .transcended500: return "brain.head.profile"
        case .eternal1000: return "infinity"
        // Favorites
        case .firstHeart: return "heart"
        case .fan10: return "heart.circle"
        case .devotee25: return "heart.rectangle"
        case .loveCollector50: return "heart.square"
        case .heartOverflow100: return "heart.text.clipboard"
        // Playlists
        case .playlistCreator: return "music.note.list"
        case .curator5: return "rectangle.stack"
        case .organizer10: return "rectangle.stack.fill"
        case .architect20: return "building.2"
        // Streaks
        case .streak3: return "flame"
        case .streak7: return "bolt.fill"
        case .streak14: return "bolt.circle"
        case .streak30: return "star.fill"
        case .streak60: return "star.circle.fill"
        case .streak100: return "medal.fill"
        case .streak365: return "trophy.fill"
        // Time of Day
        case .nightOwl: return "moon.fill"
        case .earlyBird: return "sunrise.fill"
        case .lunchBreak: return "cup.and.saucer.fill"
        case .weekendWarrior: return "party.popper.fill"
        // Artists
        case .explorer5: return "globe"
        case .globetrotter15: return "globe.americas.fill"
        case .cosmopolitan25: return "globe.europe.africa.fill"
        case .worldTraveler50: return "globe.central.south.asia.fill"
        // Track Mastery
        case .repeatKing: return "repeat.1"
        case .trackObsession: return "arrow.triangle.2.circlepath"
        case .hitFactory: return "star.square.on.square"
        // Daily
        case .productiveDay10: return "chart.line.uptrend.xyaxis"
        case .bingeDay25: return "chart.bar.fill"
        case .insaneDay50: return "exclamationmark.triangle"
        // Queue
        case .queueStarter: return "list.bullet"
        case .queueMaster50: return "list.star"
        // Milestones
        case .week1: return "calendar"
        case .month1: return "calendar.badge.clock"
        case .halfYear: return "calendar.circle"
        case .year1: return "calendar.badge.checkmark"
        // Playlist Size
        case .bigPlaylist10: return "text.line.first.and.arrowtriangle.forward"
        case .megaPlaylist25: return "text.badge.star"
        // Secret
        case .theBeginning: return "sparkle"
        case .fullCircle: return "circle.dashed"
        }
    }

    var titleRu: String {
        switch self {
        case .firstTrack: return "Первый трек"
        case .collector10: return "Коллекционер"
        case .hoarder50: return "Хранитель"
        case .vault100: return "Хранилище"
        case .archive200: return "Архивариус"
        case .librarian500: return "Библиотекарь"
        case .firstPlay: return "Первый запуск"
        case .warming50: return "Разогрев"
        case .musicLover100: return "Меломан"
        case .regular250: return "Завсегдатай"
        case .audiophile500: return "Аудиофил"
        case .legend1000: return "Легенда"
        case .titan2500: return "Титан"
        case .immortal5000: return "Бессмертный"
        case .god10000: return "Бог музыки"
        case .minute30: return "Полчаса"
        case .hour1: return "Час музыки"
        case .marathon5: return "Марафон"
        case .dedicated24: return "Сутки напролёт"
        case .obsessed100: return "Одержимый"
        case .noLife250: return "Без остановки"
        case .transcended500: return "Трансцендент"
        case .eternal1000: return "Вечность"
        case .firstHeart: return "Первое сердце"
        case .fan10: return "Фанат"
        case .devotee25: return "Верный слушатель"
        case .loveCollector50: return "Коллекционер любви"
        case .heartOverflow100: return "Переполнение сердец"
        case .playlistCreator: return "Создатель"
        case .curator5: return "Куратор"
        case .organizer10: return "Организатор"
        case .architect20: return "Архитектор"
        case .streak3: return "3 дня подряд"
        case .streak7: return "Неделя огня"
        case .streak14: return "Две недели"
        case .streak30: return "Месяц без остановок"
        case .streak60: return "Два месяца"
        case .streak100: return "Сотня дней"
        case .streak365: return "Целый год"
        case .nightOwl: return "Ночная сова"
        case .earlyBird: return "Ранняя пташка"
        case .lunchBreak: return "Обеденный перерыв"
        case .weekendWarrior: return "Воин выходных"
        case .explorer5: return "Исследователь"
        case .globetrotter15: return "Глобтроттер"
        case .cosmopolitan25: return "Космополит"
        case .worldTraveler50: return "Путешественник мира"
        case .repeatKing: return "Король повтора"
        case .trackObsession: return "Одержимость треком"
        case .hitFactory: return "Фабрика хитов"
        case .productiveDay10: return "Продуктивный день"
        case .bingeDay25: return "Музыкальный запой"
        case .insaneDay50: return "Безумный день"
        case .queueStarter: return "Очередь запущена"
        case .queueMaster50: return "Мастер очереди"
        case .week1: return "Первая неделя"
        case .month1: return "Первый месяц"
        case .halfYear: return "Полгода вместе"
        case .year1: return "Год с Pulsoria"
        case .bigPlaylist10: return "Большой плейлист"
        case .megaPlaylist25: return "Мега-плейлист"
        case .theBeginning: return "Начало пути"
        case .fullCircle: return "Полный круг"
        }
    }

    var titleEn: String {
        switch self {
        case .firstTrack: return "First Track"
        case .collector10: return "Collector"
        case .hoarder50: return "Hoarder"
        case .vault100: return "Vault"
        case .archive200: return "Archivist"
        case .librarian500: return "Librarian"
        case .firstPlay: return "First Play"
        case .warming50: return "Warming Up"
        case .musicLover100: return "Music Lover"
        case .regular250: return "Regular"
        case .audiophile500: return "Audiophile"
        case .legend1000: return "Legend"
        case .titan2500: return "Titan"
        case .immortal5000: return "Immortal"
        case .god10000: return "God of Music"
        case .minute30: return "Half Hour"
        case .hour1: return "One Hour"
        case .marathon5: return "Marathon"
        case .dedicated24: return "24 Hours Straight"
        case .obsessed100: return "Obsessed"
        case .noLife250: return "No Stopping"
        case .transcended500: return "Transcended"
        case .eternal1000: return "Eternity"
        case .firstHeart: return "First Heart"
        case .fan10: return "Fan"
        case .devotee25: return "Devotee"
        case .loveCollector50: return "Love Collector"
        case .heartOverflow100: return "Heart Overflow"
        case .playlistCreator: return "Creator"
        case .curator5: return "Curator"
        case .organizer10: return "Organizer"
        case .architect20: return "Architect"
        case .streak3: return "3 Day Streak"
        case .streak7: return "Week of Fire"
        case .streak14: return "Two Weeks Strong"
        case .streak30: return "Unstoppable Month"
        case .streak60: return "Two Months"
        case .streak100: return "Hundred Days"
        case .streak365: return "Full Year"
        case .nightOwl: return "Night Owl"
        case .earlyBird: return "Early Bird"
        case .lunchBreak: return "Lunch Break"
        case .weekendWarrior: return "Weekend Warrior"
        case .explorer5: return "Explorer"
        case .globetrotter15: return "Globetrotter"
        case .cosmopolitan25: return "Cosmopolitan"
        case .worldTraveler50: return "World Traveler"
        case .repeatKing: return "Repeat King"
        case .trackObsession: return "Track Obsession"
        case .hitFactory: return "Hit Factory"
        case .productiveDay10: return "Productive Day"
        case .bingeDay25: return "Music Binge"
        case .insaneDay50: return "Insane Day"
        case .queueStarter: return "Queue Started"
        case .queueMaster50: return "Queue Master"
        case .week1: return "First Week"
        case .month1: return "First Month"
        case .halfYear: return "Half Year Together"
        case .year1: return "One Year with Pulsoria"
        case .bigPlaylist10: return "Big Playlist"
        case .megaPlaylist25: return "Mega Playlist"
        case .theBeginning: return "The Beginning"
        case .fullCircle: return "Full Circle"
        }
    }

    var descRu: String {
        switch self {
        case .firstTrack: return "Импортируй первый трек"
        case .collector10: return "Собери 10 треков"
        case .hoarder50: return "Собери 50 треков"
        case .vault100: return "Собери 100 треков"
        case .archive200: return "Собери 200 треков"
        case .librarian500: return "Собери 500 треков"
        case .firstPlay: return "Воспроизведи первый трек"
        case .warming50: return "50 воспроизведений"
        case .musicLover100: return "100 воспроизведений"
        case .regular250: return "250 воспроизведений"
        case .audiophile500: return "500 воспроизведений"
        case .legend1000: return "1 000 воспроизведений"
        case .titan2500: return "2 500 воспроизведений"
        case .immortal5000: return "5 000 воспроизведений"
        case .god10000: return "10 000 воспроизведений"
        case .minute30: return "Слушай 30 минут"
        case .hour1: return "Слушай 1 час"
        case .marathon5: return "Слушай 5 часов"
        case .dedicated24: return "Слушай 24 часа"
        case .obsessed100: return "Слушай 100 часов"
        case .noLife250: return "Слушай 250 часов"
        case .transcended500: return "Слушай 500 часов"
        case .eternal1000: return "Слушай 1000 часов"
        case .firstHeart: return "Добавь первый трек в избранное"
        case .fan10: return "10 треков в избранном"
        case .devotee25: return "25 треков в избранном"
        case .loveCollector50: return "50 треков в избранном"
        case .heartOverflow100: return "100 треков в избранном"
        case .playlistCreator: return "Создай первый плейлист"
        case .curator5: return "Создай 5 плейлистов"
        case .organizer10: return "Создай 10 плейлистов"
        case .architect20: return "Создай 20 плейлистов"
        case .streak3: return "Слушай 3 дня подряд"
        case .streak7: return "Слушай 7 дней подряд"
        case .streak14: return "Слушай 14 дней подряд"
        case .streak30: return "Слушай 30 дней подряд"
        case .streak60: return "Слушай 60 дней подряд"
        case .streak100: return "Слушай 100 дней подряд"
        case .streak365: return "Слушай 365 дней подряд"
        case .nightOwl: return "Слушай с 00:00 до 05:00"
        case .earlyBird: return "Слушай с 05:00 до 07:00"
        case .lunchBreak: return "Слушай с 12:00 до 14:00"
        case .weekendWarrior: return "Более 20 воспроизведений в выходные"
        case .explorer5: return "Слушай 5 разных артистов"
        case .globetrotter15: return "Слушай 15 разных артистов"
        case .cosmopolitan25: return "Слушай 25 разных артистов"
        case .worldTraveler50: return "Слушай 50 разных артистов"
        case .repeatKing: return "Один трек прослушан 50 раз"
        case .trackObsession: return "Один трек прослушан 100 раз"
        case .hitFactory: return "5 треков с 50+ прослушиваниями"
        case .productiveDay10: return "10 воспроизведений за один день"
        case .bingeDay25: return "25 воспроизведений за один день"
        case .insaneDay50: return "50 воспроизведений за один день"
        case .queueStarter: return "Добавь первый трек в очередь"
        case .queueMaster50: return "Добавь 50 треков в очередь за всё время"
        case .week1: return "Слушай музыку 7 разных дней"
        case .month1: return "Слушай музыку 30 разных дней"
        case .halfYear: return "Слушай музыку 180 разных дней"
        case .year1: return "Слушай музыку 365 разных дней"
        case .bigPlaylist10: return "Плейлист с 10+ треками"
        case .megaPlaylist25: return "Плейлист с 25+ треками"
        case .theBeginning: return "Открой раздел статистики"
        case .fullCircle: return "Получи все обычные ачивки"
        }
    }

    var descEn: String {
        switch self {
        case .firstTrack: return "Import your first track"
        case .collector10: return "Collect 10 tracks"
        case .hoarder50: return "Collect 50 tracks"
        case .vault100: return "Collect 100 tracks"
        case .archive200: return "Collect 200 tracks"
        case .librarian500: return "Collect 500 tracks"
        case .firstPlay: return "Play your first track"
        case .warming50: return "50 total plays"
        case .musicLover100: return "100 total plays"
        case .regular250: return "250 total plays"
        case .audiophile500: return "500 total plays"
        case .legend1000: return "1,000 total plays"
        case .titan2500: return "2,500 total plays"
        case .immortal5000: return "5,000 total plays"
        case .god10000: return "10,000 total plays"
        case .minute30: return "Listen for 30 minutes"
        case .hour1: return "Listen for 1 hour"
        case .marathon5: return "Listen for 5 hours"
        case .dedicated24: return "Listen for 24 hours"
        case .obsessed100: return "Listen for 100 hours"
        case .noLife250: return "Listen for 250 hours"
        case .transcended500: return "Listen for 500 hours"
        case .eternal1000: return "Listen for 1,000 hours"
        case .firstHeart: return "Add first favorite"
        case .fan10: return "10 favorite tracks"
        case .devotee25: return "25 favorite tracks"
        case .loveCollector50: return "50 favorite tracks"
        case .heartOverflow100: return "100 favorite tracks"
        case .playlistCreator: return "Create first playlist"
        case .curator5: return "Create 5 playlists"
        case .organizer10: return "Create 10 playlists"
        case .architect20: return "Create 20 playlists"
        case .streak3: return "Listen 3 days in a row"
        case .streak7: return "Listen 7 days in a row"
        case .streak14: return "Listen 14 days in a row"
        case .streak30: return "Listen 30 days in a row"
        case .streak60: return "Listen 60 days in a row"
        case .streak100: return "Listen 100 days in a row"
        case .streak365: return "Listen 365 days in a row"
        case .nightOwl: return "Listen between 00:00-05:00"
        case .earlyBird: return "Listen between 05:00-07:00"
        case .lunchBreak: return "Listen between 12:00-14:00"
        case .weekendWarrior: return "20+ plays on a weekend"
        case .explorer5: return "Listen to 5 different artists"
        case .globetrotter15: return "Listen to 15 different artists"
        case .cosmopolitan25: return "Listen to 25 different artists"
        case .worldTraveler50: return "Listen to 50 different artists"
        case .repeatKing: return "Play one track 50 times"
        case .trackObsession: return "Play one track 100 times"
        case .hitFactory: return "5 tracks with 50+ plays each"
        case .productiveDay10: return "10 plays in a single day"
        case .bingeDay25: return "25 plays in a single day"
        case .insaneDay50: return "50 plays in a single day"
        case .queueStarter: return "Add first track to queue"
        case .queueMaster50: return "Add 50 tracks to queue total"
        case .week1: return "Listen on 7 different days"
        case .month1: return "Listen on 30 different days"
        case .halfYear: return "Listen on 180 different days"
        case .year1: return "Listen on 365 different days"
        case .bigPlaylist10: return "Playlist with 10+ tracks"
        case .megaPlaylist25: return "Playlist with 25+ tracks"
        case .theBeginning: return "Open the stats section"
        case .fullCircle: return "Unlock all common achievements"
        }
    }

    var category: AchievementCategory {
        switch self {
        case .firstTrack, .collector10, .hoarder50, .vault100, .archive200, .librarian500:
            return .collection
        case .firstPlay, .warming50, .musicLover100, .regular250, .audiophile500, .legend1000,
             .titan2500, .immortal5000, .god10000:
            return .playback
        case .minute30, .hour1, .marathon5, .dedicated24, .obsessed100, .noLife250, .transcended500, .eternal1000:
            return .time
        case .firstHeart, .fan10, .devotee25, .loveCollector50, .heartOverflow100:
            return .favorites
        case .playlistCreator, .curator5, .organizer10, .architect20, .bigPlaylist10, .megaPlaylist25:
            return .playlists
        case .streak3, .streak7, .streak14, .streak30, .streak60, .streak100, .streak365:
            return .streaks
        case .nightOwl, .earlyBird, .lunchBreak, .weekendWarrior:
            return .timeOfDay
        case .explorer5, .globetrotter15, .cosmopolitan25, .worldTraveler50:
            return .artists
        case .repeatKing, .trackObsession, .hitFactory:
            return .mastery
        case .productiveDay10, .bingeDay25, .insaneDay50:
            return .daily
        case .queueStarter, .queueMaster50:
            return .queue
        case .week1, .month1, .halfYear, .year1:
            return .milestones
        case .theBeginning, .fullCircle:
            return .secret
        }
    }

    func progress(_ ctx: AchievementContext) -> (current: Double, target: Double) {
        switch self {
        // Collection
        case .firstTrack: return (Double(min(ctx.tracks, 1)), 1)
        case .collector10: return (Double(min(ctx.tracks, 10)), 10)
        case .hoarder50: return (Double(min(ctx.tracks, 50)), 50)
        case .vault100: return (Double(min(ctx.tracks, 100)), 100)
        case .archive200: return (Double(min(ctx.tracks, 200)), 200)
        case .librarian500: return (Double(min(ctx.tracks, 500)), 500)
        // Playback
        case .firstPlay: return (Double(min(ctx.plays, 1)), 1)
        case .warming50: return (Double(min(ctx.plays, 50)), 50)
        case .musicLover100: return (Double(min(ctx.plays, 100)), 100)
        case .regular250: return (Double(min(ctx.plays, 250)), 250)
        case .audiophile500: return (Double(min(ctx.plays, 500)), 500)
        case .legend1000: return (Double(min(ctx.plays, 1000)), 1000)
        case .titan2500: return (Double(min(ctx.plays, 2500)), 2500)
        case .immortal5000: return (Double(min(ctx.plays, 5000)), 5000)
        case .god10000: return (Double(min(ctx.plays, 10000)), 10000)
        // Time
        case .minute30: return (min(ctx.hours * 60, 30), 30)
        case .hour1: return (min(ctx.hours, 1), 1)
        case .marathon5: return (min(ctx.hours, 5), 5)
        case .dedicated24: return (min(ctx.hours, 24), 24)
        case .obsessed100: return (min(ctx.hours, 100), 100)
        case .noLife250: return (min(ctx.hours, 250), 250)
        case .transcended500: return (min(ctx.hours, 500), 500)
        case .eternal1000: return (min(ctx.hours, 1000), 1000)
        // Favorites
        case .firstHeart: return (Double(min(ctx.favorites, 1)), 1)
        case .fan10: return (Double(min(ctx.favorites, 10)), 10)
        case .devotee25: return (Double(min(ctx.favorites, 25)), 25)
        case .loveCollector50: return (Double(min(ctx.favorites, 50)), 50)
        case .heartOverflow100: return (Double(min(ctx.favorites, 100)), 100)
        // Playlists
        case .playlistCreator: return (Double(min(ctx.playlists, 1)), 1)
        case .curator5: return (Double(min(ctx.playlists, 5)), 5)
        case .organizer10: return (Double(min(ctx.playlists, 10)), 10)
        case .architect20: return (Double(min(ctx.playlists, 20)), 20)
        // Streaks
        case .streak3: return (Double(min(ctx.bestStreak, 3)), 3)
        case .streak7: return (Double(min(ctx.bestStreak, 7)), 7)
        case .streak14: return (Double(min(ctx.bestStreak, 14)), 14)
        case .streak30: return (Double(min(ctx.bestStreak, 30)), 30)
        case .streak60: return (Double(min(ctx.bestStreak, 60)), 60)
        case .streak100: return (Double(min(ctx.bestStreak, 100)), 100)
        case .streak365: return (Double(min(ctx.bestStreak, 365)), 365)
        // Time of Day
        case .nightOwl: return (ctx.nightOwlDone ? 1 : 0, 1)
        case .earlyBird: return (ctx.earlyBirdDone ? 1 : 0, 1)
        case .lunchBreak: return (ctx.lunchDone ? 1 : 0, 1)
        case .weekendWarrior: return (Double(min(ctx.weekendPlays, 20)), 20)
        // Artists
        case .explorer5: return (Double(min(ctx.listenedArtists, 5)), 5)
        case .globetrotter15: return (Double(min(ctx.listenedArtists, 15)), 15)
        case .cosmopolitan25: return (Double(min(ctx.listenedArtists, 25)), 25)
        case .worldTraveler50: return (Double(min(ctx.listenedArtists, 50)), 50)
        // Track Mastery
        case .repeatKing: return (Double(min(ctx.maxTrackPlays, 50)), 50)
        case .trackObsession: return (Double(min(ctx.maxTrackPlays, 100)), 100)
        case .hitFactory: return (Double(min(ctx.tracksOver50, 5)), 5)
        // Daily
        case .productiveDay10: return (Double(min(ctx.todayPlays, 10)), 10)
        case .bingeDay25: return (Double(min(ctx.todayPlays, 25)), 25)
        case .insaneDay50: return (Double(min(ctx.todayPlays, 50)), 50)
        // Queue
        case .queueStarter: return (Double(min(ctx.queueAdds, 1)), 1)
        case .queueMaster50: return (Double(min(ctx.queueAdds, 50)), 50)
        // Milestones
        case .week1: return (Double(min(ctx.totalDaysListened, 7)), 7)
        case .month1: return (Double(min(ctx.totalDaysListened, 30)), 30)
        case .halfYear: return (Double(min(ctx.totalDaysListened, 180)), 180)
        case .year1: return (Double(min(ctx.totalDaysListened, 365)), 365)
        // Playlist Size
        case .bigPlaylist10: return (Double(min(ctx.playlistsWith10, 1)), 1)
        case .megaPlaylist25: return (Double(ctx.playlistsWith10 >= 1 && ctx.playlistsWith10 > 0 ? 1 : 0), 1)
        // Secret
        case .theBeginning: return (1, 1) // Always unlocked on open
        case .fullCircle:
            let commonCount = AchievementID.allCases.filter { $0.rarity == .common && $0 != .fullCircle }.count
            let unlockedCommon = AchievementID.allCases.filter { $0.rarity == .common && $0 != .fullCircle }
            let done = unlockedCommon.filter { StatsManager.shared.unlockedAchievements.contains($0.rawValue) }.count
            return (Double(done), Double(commonCount))
        }
    }
}

enum AchievementCategory: String, CaseIterable, Identifiable {
    case collection, playback, time, favorites, playlists, streaks, timeOfDay, artists
    case mastery, daily, queue, milestones, secret

    var id: String { rawValue }

    var titleRu: String {
        switch self {
        case .collection: return "Коллекция"
        case .playback: return "Воспроизведение"
        case .time: return "Время прослушивания"
        case .favorites: return "Избранное"
        case .playlists: return "Плейлисты"
        case .streaks: return "Серии"
        case .timeOfDay: return "Время суток"
        case .artists: return "Артисты"
        case .mastery: return "Мастерство"
        case .daily: return "Интенсивность"
        case .queue: return "Очередь"
        case .milestones: return "Вехи"
        case .secret: return "Секретные"
        }
    }

    var titleEn: String {
        switch self {
        case .collection: return "Collection"
        case .playback: return "Playback"
        case .time: return "Listening Time"
        case .favorites: return "Favorites"
        case .playlists: return "Playlists"
        case .streaks: return "Streaks"
        case .timeOfDay: return "Time of Day"
        case .artists: return "Artists"
        case .mastery: return "Mastery"
        case .daily: return "Intensity"
        case .queue: return "Queue"
        case .milestones: return "Milestones"
        case .secret: return "Secret"
        }
    }

    var icon: String {
        switch self {
        case .collection: return "tray.full"
        case .playback: return "play.circle"
        case .time: return "clock"
        case .favorites: return "heart"
        case .playlists: return "music.note.list"
        case .streaks: return "flame"
        case .timeOfDay: return "clock.arrow.circlepath"
        case .artists: return "person.2"
        case .mastery: return "star.circle"
        case .daily: return "chart.bar.fill"
        case .queue: return "list.bullet"
        case .milestones: return "flag.fill"
        case .secret: return "questionmark.circle"
        }
    }
}

// MARK: - Listening Personality

enum ListeningPersonality {
    case casual, dedicated, explorer, nightCrawler, marathoner, eclectic

    var titleRu: String {
        switch self {
        case .casual: return "Каждый день понемногу"
        case .dedicated: return "Преданный слушатель"
        case .explorer: return "Музыкальный исследователь"
        case .nightCrawler: return "Ночной меломан"
        case .marathoner: return "Марафонец"
        case .eclectic: return "Эклектик"
        }
    }

    var titleEn: String {
        switch self {
        case .casual: return "Casual Listener"
        case .dedicated: return "Dedicated Listener"
        case .explorer: return "Music Explorer"
        case .nightCrawler: return "Night Crawler"
        case .marathoner: return "Marathoner"
        case .eclectic: return "Eclectic"
        }
    }

    var descRu: String {
        switch self {
        case .casual: return "Ты слушаешь музыку в удовольствие, не гонясь за количеством."
        case .dedicated: return "Музыка - важная часть твоей жизни. Ты слушаешь каждый день."
        case .explorer: return "Ты любишь открывать новых артистов и разнообразие."
        case .nightCrawler: return "Ночь - твоё время. Музыка звучит лучше в тишине."
        case .marathoner: return "Когда ты слушаешь, ты слушаешь долго и глубоко."
        case .eclectic: return "Ты не ограничиваешь себя - слушаешь всё и всех."
        }
    }

    var descEn: String {
        switch self {
        case .casual: return "You enjoy music at your own pace, no pressure."
        case .dedicated: return "Music is a key part of your life. You listen every day."
        case .explorer: return "You love discovering new artists and variety."
        case .nightCrawler: return "Night is your time. Music sounds better in silence."
        case .marathoner: return "When you listen, you go deep and long."
        case .eclectic: return "You don't limit yourself - you listen to everything."
        }
    }

    var icon: String {
        switch self {
        case .casual: return "leaf.fill"
        case .dedicated: return "flame.fill"
        case .explorer: return "safari.fill"
        case .nightCrawler: return "moon.stars.fill"
        case .marathoner: return "figure.run"
        case .eclectic: return "sparkles"
        }
    }
}

// MARK: - Stats Manager

@MainActor
class StatsManager: ObservableObject {
    static let shared = StatsManager()

    @Published var hourlyPlays: [Int] = Array(repeating: 0, count: 24)
    @Published var currentStreak: Int = 0
    @Published var bestStreak: Int = 0
    @Published var unlockedAchievements: Set<String> = []
    @Published var newlyUnlocked: AchievementID? = nil
    @Published var level: Int = 1
    @Published var xp: Int = 0
    @Published var queueAdds: Int = 0
    @Published var weekendPlays: Int = 0
    @Published var totalDaysListened: Int = 0

    private let xpPerLevel = 300
    private var achievementCheckTask: Task<Void, Never>?

    private init() {
        loadData()
    }

    // MARK: - Persistence

    private func loadData() {
        hourlyPlays = (UserDefaults.standard.array(forKey: UserDefaultsKey.statsHourlyPlays) as? [Int]) ?? Array(repeating: 0, count: 24)
        if hourlyPlays.count != 24 { hourlyPlays = Array(repeating: 0, count: 24) }
        currentStreak = UserDefaults.standard.integer(forKey: UserDefaultsKey.statsCurrentStreak)
        bestStreak = UserDefaults.standard.integer(forKey: UserDefaultsKey.statsBestStreak)
        unlockedAchievements = Set(UserDefaults.standard.stringArray(forKey: UserDefaultsKey.statsUnlocked) ?? [])
        xp = UserDefaults.standard.integer(forKey: UserDefaultsKey.statsXP)
        level = UserDefaults.standard.integer(forKey: UserDefaultsKey.statsLevel)
        if level == 0 { level = 1 }
        queueAdds = UserDefaults.standard.integer(forKey: UserDefaultsKey.statsQueueAdds)
        weekendPlays = UserDefaults.standard.integer(forKey: UserDefaultsKey.statsWeekendPlays)
        totalDaysListened = UserDefaults.standard.integer(forKey: UserDefaultsKey.statsTotalDaysListened)
    }

    private func save() {
        UserDefaults.standard.set(hourlyPlays, forKey: UserDefaultsKey.statsHourlyPlays)
        UserDefaults.standard.set(currentStreak, forKey: UserDefaultsKey.statsCurrentStreak)
        UserDefaults.standard.set(bestStreak, forKey: UserDefaultsKey.statsBestStreak)
        UserDefaults.standard.set(Array(unlockedAchievements), forKey: UserDefaultsKey.statsUnlocked)
        UserDefaults.standard.set(xp, forKey: UserDefaultsKey.statsXP)
        UserDefaults.standard.set(level, forKey: UserDefaultsKey.statsLevel)
        UserDefaults.standard.set(queueAdds, forKey: UserDefaultsKey.statsQueueAdds)
        UserDefaults.standard.set(weekendPlays, forKey: UserDefaultsKey.statsWeekendPlays)
        UserDefaults.standard.set(totalDaysListened, forKey: UserDefaultsKey.statsTotalDaysListened)
    }

    // MARK: - Record Play

    func recordPlay() {
        let hour = Calendar.current.component(.hour, from: Date())
        hourlyPlays[hour] += 1

        let weekday = Calendar.current.component(.weekday, from: Date())
        if weekday == 1 || weekday == 7 {
            weekendPlays += 1
        }

        updateStreak()
        updateTotalDays()
        save()
    }

    func recordQueueAdd() {
        queueAdds += 1
        save()
        checkAchievements()
    }

    // MARK: - Streak

    private func updateStreak() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let lastDate = UserDefaults.standard.object(forKey: UserDefaultsKey.statsLastPlayDate) as? Date
        let lastDay = lastDate.map { cal.startOfDay(for: $0) }

        if lastDay == today {
            return
        }

        if let last = lastDay, cal.dateComponents([.day], from: last, to: today).day == 1 {
            currentStreak += 1
        } else if lastDay != today {
            currentStreak = 1
        }

        if currentStreak > bestStreak {
            bestStreak = currentStreak
        }

        UserDefaults.standard.set(Date(), forKey: UserDefaultsKey.statsLastPlayDate)
        save()
    }

    private func updateTotalDays() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let lastCountedDay = UserDefaults.standard.object(forKey: UserDefaultsKey.statsLastCountedDay) as? Date
        let lastDay = lastCountedDay.map { cal.startOfDay(for: $0) }

        if lastDay != today {
            totalDaysListened += 1
            UserDefaults.standard.set(Date(), forKey: UserDefaultsKey.statsLastCountedDay)
        }
    }

    // MARK: - Build Context

    func buildContext() -> AchievementContext {
        let player = AudioPlayerManager.shared
        let pm = PlaylistManager.shared

        let trackCount = player.tracks.count
        let totalPlays = player.totalPlays
        let totalHours = player.totalListeningTime / 3600.0
        let favoriteCount = player.tracks.filter(\.isFavorite).count
        let playlistCount = pm.playlists.count
        let listenedArtists = Set(player.tracks.filter { $0.playCount > 0 }.flatMap { splitArtists($0.artist) }).count
        let allArtists = Set(player.tracks.flatMap { splitArtists($0.artist) }).count
        let nightOwlDone = hourlyPlays[0...4].reduce(0, +) > 0
        let earlyBirdDone = hourlyPlays[5...6].reduce(0, +) > 0
        let lunchDone = hourlyPlays[12...13].reduce(0, +) > 0
        let maxTrackPlays = player.tracks.map(\.playCount).max() ?? 0
        let todayPlays = player.todayPlays
        let tracksOver50 = player.tracks.filter { $0.playCount >= 50 }.count
        let tracksOver100 = player.tracks.filter { $0.playCount >= 100 }.count
        let playlistsWith10 = pm.playlists.filter { $0.trackFileNames.count >= 10 }.count

        return AchievementContext(
            tracks: trackCount,
            plays: totalPlays,
            hours: totalHours,
            favorites: favoriteCount,
            playlists: playlistCount,
            streak: currentStreak,
            bestStreak: bestStreak,
            artists: allArtists,
            listenedArtists: listenedArtists,
            nightOwlDone: nightOwlDone,
            earlyBirdDone: earlyBirdDone,
            lunchDone: lunchDone,
            weekendPlays: weekendPlays,
            maxTrackPlays: maxTrackPlays,
            todayPlays: todayPlays,
            queueAdds: queueAdds,
            tracksOver50: tracksOver50,
            tracksOver100: tracksOver100,
            playlistsWith10: playlistsWith10,
            totalDaysListened: totalDaysListened
        )
    }

    // MARK: - Check Achievements

    func checkAchievements() {
        achievementCheckTask?.cancel()
        achievementCheckTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self.performAchievementCheck()
        }
    }

    private func performAchievementCheck() {
        let ctx = buildContext()
        var newUnlock: AchievementID? = nil

        for achievement in AchievementID.allCases {
            if unlockedAchievements.contains(achievement.rawValue) { continue }

            let (current, target) = achievement.progress(ctx)

            if current >= target {
                unlockedAchievements.insert(achievement.rawValue)
                xp += achievement.rarity.xp
                level = (xp / xpPerLevel) + 1
                newUnlock = achievement
            }
        }

        if newUnlock != nil {
            newlyUnlocked = newUnlock
            save()
        }
    }

    // MARK: - Weekly Data

    func weeklyListeningData() -> [(day: String, minutes: Double)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: ThemeManager.shared.language == .russian ? "ru_RU" : "en_US")

        var result: [(day: String, minutes: Double)] = []
        for i in (0..<7).reversed() {
            guard let date = cal.date(byAdding: .day, value: -i, to: today) else { continue }
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "yyyy-MM-dd"
            let key = UserDefaultsKey.listeningToday(dayFormatter.string(from: date))
            let seconds = UserDefaults.standard.double(forKey: key)
            formatter.dateFormat = "EEE"
            let dayName = formatter.string(from: date)
            result.append((day: dayName, minutes: seconds / 60.0))
        }
        return result
    }

    private func splitArtists(_ artist: String) -> [String] {
        artist
            .replacingOccurrences(of: " & ", with: ",")
            .replacingOccurrences(of: " feat. ", with: ",")
            .replacingOccurrences(of: " feat ", with: ",")
            .replacingOccurrences(of: " ft. ", with: ",")
            .replacingOccurrences(of: " ft ", with: ",")
            .replacingOccurrences(of: " x ", with: ",")
            .replacingOccurrences(of: " X ", with: ",")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Artist Distribution

    func artistDistribution() -> [(name: String, percentage: Double)] {
        let player = AudioPlayerManager.shared
        let total = max(1, player.totalPlays)
        let artists = player.topArtists.prefix(6)
        return artists.map { (name: $0.name, percentage: Double($0.playCount) / Double(total) * 100) }
    }

    // MARK: - Personality

    func personality() -> ListeningPersonality {
        let player = AudioPlayerManager.shared
        let totalHours = player.totalListeningTime / 3600.0
        let artistCount = Set(player.tracks.filter { $0.playCount > 0 }.flatMap { splitArtists($0.artist) }).count
        let nightPlays = hourlyPlays[0...4].reduce(0, +)
        let totalHourlyPlays = max(1, hourlyPlays.reduce(0, +))

        if Double(nightPlays) / Double(totalHourlyPlays) > 0.3 {
            return .nightCrawler
        }
        if artistCount > 10 {
            return .eclectic
        }
        if totalHours > 50 {
            return .marathoner
        }
        if currentStreak >= 7 {
            return .dedicated
        }
        if artistCount > 5 {
            return .explorer
        }
        return .casual
    }

    // MARK: - XP Progress

    var xpProgress: Double {
        let xpInLevel = xp % xpPerLevel
        return Double(xpInLevel) / Double(xpPerLevel)
    }

    var xpToNextLevel: Int {
        xpPerLevel - (xp % xpPerLevel)
    }

    var completedCount: Int {
        unlockedAchievements.count
    }

    var totalAchievements: Int {
        AchievementID.allCases.count
    }
}
