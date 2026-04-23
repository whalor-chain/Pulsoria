import SwiftUI
import Combine

enum AppTheme: String, CaseIterable, Identifiable {
    case purple = "Purple"
    case blue = "Blue"
    case pink = "Pink"
    case orange = "Orange"
    case green = "Green"
    case red = "Red"
    case cyan = "Cyan"
    case indigo = "Indigo"

    var id: String { rawValue }

    var accent: Color {
        switch self {
        case .purple: return .purple
        case .blue: return .blue
        case .pink: return .pink
        case .orange: return .orange
        case .green: return .green
        case .red: return .red
        case .cyan: return .cyan
        case .indigo: return .indigo
        }
    }

    var secondary: Color {
        switch self {
        case .purple: return .blue
        case .blue: return .cyan
        case .pink: return .purple
        case .orange: return .yellow
        case .green: return .mint
        case .red: return .orange
        case .cyan: return .blue
        case .indigo: return .purple
        }
    }

    var icon: String {
        switch self {
        case .purple: return "circle.fill"
        case .blue: return "circle.fill"
        case .pink: return "circle.fill"
        case .orange: return "circle.fill"
        case .green: return "circle.fill"
        case .red: return "circle.fill"
        case .cyan: return "circle.fill"
        case .indigo: return "circle.fill"
        }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? { .dark }

    var icon: String { "moon.fill" }

    var localizedName: String { Loc.darkMode }
}

enum SliderIcon: String, CaseIterable, Identifiable {
    case defaultCircle = "Default"
    case optimusTruck = "Optimus Prime"
    case bumblebeeCamaro = "Bumblebee"
    case delorean = "DeLorean"
    case batmobile = "Batmobile"
    case xWing = "X-Wing"
    case hogwartsTrain = "Hogwarts Express"
    case marioKart = "Mario Kart"
    case masterSword = "Master Sword"
    case nyanCat = "Nyan Cat"
    case tardis = "TARDIS"
    case enterprise = "Enterprise"
    case milleniumFalcon = "Falcon"
    case custom = "Custom"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .defaultCircle: return "●"
        case .optimusTruck: return "🚛"
        case .bumblebeeCamaro: return "🚗"
        case .delorean: return "🏎️"
        case .batmobile: return "🦇"
        case .xWing: return "🚀"
        case .hogwartsTrain: return "🚂"
        case .marioKart: return "🏁"
        case .masterSword: return "⚔️"
        case .nyanCat: return "🌈"
        case .tardis: return "📦"
        case .enterprise: return "🛸"
        case .milleniumFalcon: return "🛩️"
        case .custom: return "✏️"
        }
    }

    var sfSymbol: String {
        switch self {
        case .defaultCircle: return "circle.fill"
        case .optimusTruck: return "truck.box.fill"
        case .bumblebeeCamaro: return "car.fill"
        case .delorean: return "car.side.fill"
        case .batmobile: return "bolt.car.fill"
        case .xWing: return "airplane"
        case .hogwartsTrain: return "train.side.front.car"
        case .marioKart: return "flag.checkered"
        case .masterSword: return "shield.fill"
        case .nyanCat: return "cat.fill"
        case .tardis: return "door.left.hand.closed"
        case .enterprise: return "airplane.departure"
        case .milleniumFalcon: return "paperplane.fill"
        // Intentionally static here so sfSymbol stays nonisolated. Callers
        // that need the user's custom symbol should use
        // ThemeManager.shared.activeSliderSymbol instead.
        case .custom: return "star.fill"
        }
    }

    var displayName: String { rawValue }

    var universe: String {
        switch self {
        case .defaultCircle: return "Standard"
        case .optimusTruck: return "Transformers"
        case .bumblebeeCamaro: return "Transformers"
        case .delorean: return "Back to the Future"
        case .batmobile: return "DC Comics"
        case .xWing: return "Star Wars"
        case .hogwartsTrain: return "Harry Potter"
        case .marioKart: return "Nintendo"
        case .masterSword: return "Zelda"
        case .nyanCat: return "Internet"
        case .tardis: return "Doctor Who"
        case .enterprise: return "Star Trek"
        case .milleniumFalcon: return "Star Wars"
        case .custom: return "SF Symbols"
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case russian = "ru"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .russian: return "Русский"
        case .english: return "English"
        }
    }

    var flag: String {
        switch self {
        case .russian: return "🇷🇺"
        case .english: return "🇬🇧"
        }
    }
}

// MARK: - Localization

@MainActor
enum Loc {
    private static var lang: AppLanguage { ThemeManager.shared.language }
    private static var ru: Bool { lang == .russian }

    // Fonts (Futura doesn't support Cyrillic)
    static var fontBold: String { ru ? "AvenirNext-Bold" : "Futura-Bold" }
    static var fontMedium: String { ru ? "AvenirNext-Medium" : "Futura-Medium" }

    // Tabs
    static var library: String { ru ? "Библиотека" : "Library" }
    static var wave: String { ru ? "Волна" : "Wave" }
    static var settings: String { ru ? "Настройки" : "Settings" }

    // Settings
    static var appearance: String { ru ? "Оформление" : "Appearance" }
    static var totalTracks: String { ru ? "Всего треков" : "Total Tracks" }
    static var favorites: String { ru ? "Избранное" : "Favorites" }
    static var addToFavorites: String { ru ? "Добавить в любимое" : "Add to Favorites" }
    static var inFavorites: String { ru ? "В любимых" : "In Favorites" }
    static var playback: String { ru ? "Воспроизведение" : "Playback" }
    static var repeatLabel: String { ru ? "Повтор" : "Repeat" }
    static var shuffle: String { ru ? "Перемешать" : "Shuffle" }
    static var showOnboarding: String { ru ? "Показать приветствие" : "Show Onboarding" }
    static var resetFavorites: String { ru ? "Сбросить избранное" : "Reset Favorites" }
    static var resetFavoritesQ: String { ru ? "Сбросить избранное?" : "Reset Favorites?" }
    static var resetFavoritesMsg: String { ru ? "Все треки будут удалены из избранного." : "This will remove all tracks from your favorites list." }
    static var cancel: String { ru ? "Отмена" : "Cancel" }
    static var reset: String { ru ? "Сбросить" : "Reset" }
    static var about: String { ru ? "О приложении" : "About" }
    static var version: String { ru ? "Версия" : "Version" }
    static var signInWithApple: String { ru ? "Войти через Apple" : "Sign in with Apple" }
    static var signOut: String { ru ? "Выйти" : "Sign Out" }
    static var signedInAs: String { ru ? "Вы вошли как" : "Signed in as" }
    static var account: String { ru ? "Аккаунт" : "Account" }
    static var signOutConfirm: String { ru ? "Вы уверены, что хотите выйти?" : "Are you sure you want to sign out?" }
    static var signInSubtitle: String { ru ? "Войдите, чтобы сохранить ваши данные" : "Sign in to sync your data" }
    static var signInSlogan: String { ru ? "Твой пульс. Твоя музыка." : "Your pulse. Your sound." }
    static var continueWithout: String { ru ? "Продолжить без входа" : "Continue without signing in" }
    static var appleIdConnected: String { ru ? "Аккаунт подключён" : "Account connected" }
    static var music: String { ru ? "Музыка" : "Music" }
    static var musicPlayer: String { ru ? "Музыкальный плеер" : "Music Player" }
    static var language: String { ru ? "Язык" : "Language" }
    static var editProfile: String { ru ? "Редактировать профиль" : "Edit Profile" }
    static var nickname: String { ru ? "Никнейм" : "Nickname" }
    static var choosePhoto: String { ru ? "Выбрать фото" : "Choose Photo" }
    static var removePhoto: String { ru ? "Удалить фото" : "Remove Photo" }
    static var save: String { ru ? "Сохранить" : "Save" }

    // Genius
    static var geniusAPI: String { "Genius API" }
    static var geniusToken: String { ru ? "API токен" : "API Token" }
    static var geniusTokenHint: String { ru ? "Получите на genius.com/api-clients" : "Get it at genius.com/api-clients" }
    static var geniusConnected: String { ru ? "Подключён" : "Connected" }
    static var geniusNotConnected: String { ru ? "Не подключён" : "Not connected" }
    static var biography: String { ru ? "Биография" : "Biography" }
    static var socialMedia: String { ru ? "Соцсети" : "Social Media" }
    static var songInfo: String { ru ? "О треке" : "About Track" }
    static var lyrics: String { ru ? "Текст" : "Lyrics" }
    static var noLyrics: String { ru ? "Текст не найден" : "Lyrics not found" }
    static var showMore: String { ru ? "Показать больше" : "Show more" }
    static var loadingLyrics: String { ru ? "Загрузка текста..." : "Loading lyrics..." }
    static var album: String { ru ? "Альбом" : "Album" }
    static var albums: String { ru ? "Альбомы" : "Albums" }
    static var openAlbum: String { ru ? "Открыть альбом" : "Open Album" }
    static var openArtist: String { ru ? "Открыть артиста" : "Open Artist" }
    static var releaseDate: String { ru ? "Дата выхода" : "Release Date" }
    static var openInGenius: String { ru ? "Открыть в Genius" : "Open in Genius" }
    static var noInfo: String { ru ? "Нет информации" : "No info available" }

    // Library
    static var search: String { ru ? "Поиск" : "Search" }
    static var searchTracks: String { ru ? "Поиск треков" : "Search tracks" }
    static var searchArtists: String { ru ? "Поиск артистов" : "Search artists" }
    static var searchAlbums: String { ru ? "Поиск альбомов" : "Search albums" }
    static var searchPlaylists: String { ru ? "Поиск плейлистов" : "Search playlists" }
    static var noTracksYet: String { ru ? "Нет треков" : "No Tracks Yet" }
    static var importHint: String { ru ? "Импортируйте аудиофайлы с устройства, чтобы начать." : "Import audio files from your device to get started." }
    static var importMusic: String { ru ? "Импорт музыки" : "Import Music" }
    static var delete: String { ru ? "Удалить" : "Delete" }
    static var importError: String { ru ? "Ошибка импорта" : "Import Error" }
    static var errorTitle: String { ru ? "Ошибка" : "Error" }
    static var purchaseFailed: String { ru ? "Не удалось купить бит. Попробуй ещё раз." : "Couldn't complete purchase. Please try again." }

    // Accessibility — playback controls
    static var a11yPlay: String { ru ? "Воспроизвести" : "Play" }
    static var a11yPause: String { ru ? "Пауза" : "Pause" }
    static var a11yNextTrack: String { ru ? "Следующий трек" : "Next track" }
    static var a11yPreviousTrack: String { ru ? "Предыдущий трек" : "Previous track" }
    static var a11yAddFavorite: String { ru ? "Добавить в избранное" : "Add to favorites" }
    static var a11yRemoveFavorite: String { ru ? "Убрать из избранного" : "Remove from favorites" }
    static var a11yOpenPlayer: String { ru ? "Открыть плеер" : "Open player" }
    static var a11yCloseSheet: String { ru ? "Закрыть" : "Close" }
    static var a11yQueue: String { ru ? "Очередь" : "Queue" }
    static var a11yLyrics: String { ru ? "Текст песни" : "Lyrics" }
    static var a11yShare: String { ru ? "Поделиться" : "Share" }
    static var a11ySleepTimer: String { ru ? "Таймер сна" : "Sleep timer" }
    static var a11yShuffle: String { ru ? "Перемешать" : "Shuffle" }
    static var a11yRepeat: String { ru ? "Повтор" : "Repeat" }
    static var a11yMoreOptions: String { ru ? "Ещё" : "More options" }
    static var a11yProfile: String { ru ? "Профиль" : "Profile" }
    static var a11yStats: String { ru ? "Статистика" : "Stats" }
    static var a11ySettings: String { ru ? "Настройки" : "Settings" }
    static var a11yFilters: String { ru ? "Фильтры" : "Filters" }
    static var a11yImportMusic: String { ru ? "Импортировать музыку" : "Import music" }
    static var a11yPreview: String { ru ? "Прослушать превью" : "Preview" }
    static var a11yStopPreview: String { ru ? "Остановить превью" : "Stop preview" }

    // MARK: - Listening Rooms
    static var rooms: String { ru ? "Комнаты" : "Rooms" }
    static var listeningRooms: String { ru ? "Комнаты прослушивания" : "Listening Rooms" }
    static var roomsHint: String { ru ? "Слушайте вместе в реальном времени — один хост, общий плейлист, чат сбоку." : "Listen together live — one host, shared playback, chat on the side." }
    static var startRoom: String { ru ? "Создать комнату" : "Start a room" }
    static var joinRoom: String { ru ? "Зайти по коду" : "Join by code" }
    static var leaveRoom: String { ru ? "Выйти из комнаты" : "Leave room" }
    static var endRoom: String { ru ? "Закрыть комнату" : "End room" }
    static var roomCode: String { ru ? "Код комнаты" : "Room code" }
    static var enterRoomCode: String { ru ? "Введите код" : "Enter code" }
    static var hostLabel: String { ru ? "Хост" : "Host" }
    static var pickTrackForRoom: String { ru ? "Выберите трек" : "Pick a track" }
    static var noLocalTrack: String { ru ? "Этого трека нет у тебя в библиотеке — слышат только хост и те, у кого он есть." : "You don't have this track locally — audio will only play for people who do." }
    static var roomEndedByHost: String { ru ? "Хост закрыл комнату" : "The host ended this room" }
    static var shareCode: String { ru ? "Поделиться кодом" : "Share code" }
    static var participants: String { ru ? "Участники" : "Participants" }
    static var chat: String { ru ? "Чат" : "Chat" }
    static var writeMessage: String { ru ? "Написать сообщение…" : "Write a message…" }
    static var send: String { ru ? "Отправить" : "Send" }
    static var noMessagesYet: String { ru ? "Сообщений пока нет" : "No messages yet" }

    // MARK: - Social / Friends
    static var social: String { ru ? "Социальное" : "Social" }
    static var friends: String { ru ? "Друзья" : "Friends" }
    static var addFriend: String { ru ? "Добавить друга" : "Add friend" }
    static var myFriendCode: String { ru ? "Мой код" : "My code" }
    static var copyCode: String { ru ? "Скопировать" : "Copy" }
    static var codeCopied: String { ru ? "Скопировано" : "Copied" }
    static var friendCodePrompt: String { ru ? "Введите код друга" : "Enter friend's code" }
    static var friendCodeHint: String { ru ? "6 символов — друг делится им из своего профиля." : "6 characters — your friend shares theirs from their profile." }
    static var noFriendsYet: String { ru ? "Пока никого нет" : "No friends yet" }
    static var noFriendsHint: String { ru ? "Добавьте друга по коду, чтобы видеть что он сейчас слушает." : "Add a friend by code to see what they're listening to." }
    static var liveNow: String { ru ? "В эфире" : "Live" }
    static var lastListened: String { ru ? "Последнее" : "Last played" }
    static var offlineStatus: String { ru ? "Не в сети" : "Offline" }
    static var removeFriend: String { ru ? "Удалить из друзей" : "Remove friend" }
    static var friendAdded: String { ru ? "Друг добавлен" : "Friend added" }
    static var requestSent: String { ru ? "Запрос отправлен" : "Request sent" }
    static var incomingRequests: String { ru ? "Входящие запросы" : "Friend requests" }
    static var pendingOutgoing: String { ru ? "Ожидают ответа" : "Pending" }
    static var accept: String { ru ? "Принять" : "Accept" }
    static var decline: String { ru ? "Отклонить" : "Decline" }
    static var cancelRequest: String { ru ? "Отменить запрос" : "Cancel request" }
    static var wantsToBeFriend: String { ru ? "хочет добавить в друзья" : "wants to add you" }
    static var requestAlreadySent: String { ru ? "Запрос уже отправлен" : "Request already sent" }
    static var inRoomNow: String { ru ? "Сейчас в комнате" : "In a room now" }
    static var joinTheirRoom: String { ru ? "Зайти в комнату" : "Join their room" }
    static var searchFriends: String { ru ? "Поиск друзей" : "Search friends" }
    static var currentTrack: String { ru ? "Сейчас играет" : "Now playing" }
    static var notListening: String { ru ? "Ничего не слушает" : "Not listening" }
    static var scanQR: String { ru ? "Сканировать QR" : "Scan QR" }
    static var notFoundQR: String { ru ? "Это не код Pulsoria" : "That QR isn't a Pulsoria friend code." }
    static var cameraPermissionTitle: String { ru ? "Нет доступа к камере" : "Camera access needed" }
    static var cameraPermissionMessage: String { ru ? "Разрешите камеру в Настройках, чтобы сканировать QR-коды друзей." : "Allow camera access in Settings to scan friends' QR codes." }
    static var openSettings: String { ru ? "Настройки" : "Open Settings" }
    static var justNow: String { ru ? "только что" : "just now" }
    static var minutesAgoSuffix: String { ru ? "мин назад" : "min ago" }
    static var hoursAgoSuffix: String { ru ? "ч назад" : "h ago" }
    static var daysAgoSuffix: String { ru ? "дн назад" : "d ago" }

    // Playlists
    static var tracksTab: String { ru ? "Треки" : "Tracks" }
    static var playlists: String { ru ? "Плейлисты" : "Playlists" }
    static var newPlaylist: String { ru ? "Новый плейлист" : "New Playlist" }
    static var playlistName: String { ru ? "Название плейлиста" : "Playlist Name" }
    static var enterPlaylistName: String { ru ? "Введите название плейлиста" : "Enter a name for your playlist" }
    static var create: String { ru ? "Создать" : "Create" }
    static var rename: String { ru ? "Переименовать" : "Rename" }
    static var addToPlaylist: String { ru ? "В плейлист" : "Add to Playlist" }
    static var removeFromPlaylist: String { ru ? "Убрать" : "Remove" }
    static var selectPlaylist: String { ru ? "Выберите плейлист" : "Select Playlist" }
    static var emptyPlaylist: String { ru ? "Плейлист пуст" : "Playlist is Empty" }
    static var emptyPlaylistHint: String { ru ? "Добавьте треки из библиотеки свайпом вправо" : "Add tracks from your library by swiping right" }
    static var noPlaylists: String { ru ? "Нет плейлистов" : "No Playlists Yet" }
    static var noPlaylistsHint: String { ru ? "Создайте первый плейлист, нажав +" : "Create your first playlist by tapping +" }
    static var trackCount: String { ru ? "треков" : "tracks" }
    static var trackSingular: String { ru ? "трек" : "track" }
    static var trackPlural: String { ru ? "треков" : "tracks" }
    static var done: String { ru ? "Готово" : "Done" }
    static var favoriteTracks: String { ru ? "Любимые треки" : "Favorite Tracks" }

    // Player
    static var noTrackSelected: String { ru ? "Трек не выбран" : "No Track Selected" }
    static var unknownArtist: String { ru ? "Неизвестный артист" : "Unknown Artist" }
    static var artist: String { ru ? "Исполнитель" : "Artist" }
    static var artists: String { ru ? "Артисты" : "Artists" }
    static var noArtists: String { ru ? "Нет артистов" : "No artists" }
    static var noArtistsHint: String { ru ? "Добавьте треки, и артисты появятся здесь" : "Add tracks and artists will appear here" }
    static var noAlbums: String { ru ? "Нет альбомов" : "No albums" }
    static var noAlbumsHint: String { ru ? "Добавьте треки, и альбомы появятся здесь" : "Add tracks and albums will appear here" }
    static var noAlbumsFound: String { ru ? "Альбомы не найдены" : "No albums found" }
    static var noAlbumsFoundHint: String { ru ? "Информация об альбомах загружается автоматически" : "Album info is loaded automatically" }
    static var noFavorites: String { ru ? "Нет избранного" : "No Favorites" }
    static var noFavoriteTracksHint: String { ru ? "Нажмите ♥ на треке, чтобы добавить в избранное" : "Tap ♥ on a track to add it to favorites" }
    static var noFavoriteArtistsHint: String { ru ? "Нажмите ♥ на артисте, чтобы добавить в избранное" : "Tap ♥ on an artist to add to favorites" }
    static var inLibrary: String { ru ? "в библиотеке" : "in library" }
    static var addToFavourites: String { ru ? "В избранное" : "Add to Favourites" }
    static var inFavourites: String { ru ? "В избранном" : "In Favourites" }
    static var allTracks: String { ru ? "Все треки" : "All Tracks" }
    static var playAll: String { ru ? "Воспроизвести все" : "Play All" }
    static var shuffleAll: String { ru ? "Перемешать все" : "Shuffle All" }

    // Wave
    static var intensity: String { ru ? "Интенсив." : "Intensity" }
    static var energy: String { ru ? "Энергия" : "Energy" }
    static var mode: String { ru ? "Режим" : "Mode" }

    // Wave modes
    static var modeWave: String { ru ? "Волна" : "Wave" }
    static var modePulse: String { ru ? "Пульс" : "Pulse" }
    static var modeBars: String { ru ? "Бары" : "Bars" }
    static var modeGalaxy: String { ru ? "Галактика" : "Galaxy" }
    static var modeDNA: String { "DNA" }

    // Onboarding
    static var welcomeToPulsoria: String { ru ? "Добро пожаловать в Pulsoria" : "Welcome to Pulsoria" }
    static var welcomeDesc: String { ru ? "Ваш персональный музыкальный плеер нового поколения" : "Your next-generation personal music player" }
    static var yourMusic: String { ru ? "Ваша музыка" : "Your Music" }
    static var yourMusicDesc: String { ru ? "Импортируйте треки, создавайте плейлисты и слушайте любимую музыку в любое время." : "Import tracks, create playlists, and enjoy your favorite music anytime." }
    static var yourMusicFeature1: String { ru ? "Импорт из Файлов" : "Import from Files" }
    static var yourMusicFeature2: String { ru ? "Плейлисты и избранное" : "Playlists & Favorites" }
    static var yourMusicFeature3: String { ru ? "Очередь воспроизведения" : "Playback Queue" }
    static var pulseWave: String { ru ? "Пульс-волна" : "Pulse Wave" }
    static var pulseWaveDesc: String { ru ? "Наблюдайте, как музыка оживает с завораживающими визуализациями в реальном времени." : "Watch your music come alive with real-time wave visualizations." }
    static var pulseWaveFeature1: String { ru ? "Визуализация в реальном времени" : "Real-time Visualization" }
    static var pulseWaveFeature2: String { ru ? "Несколько режимов волны" : "Multiple Wave Modes" }
    static var pulseWaveFeature3: String { ru ? "Реагирует на музыку" : "Reacts to Music" }
    static var beatShop: String { ru ? "Магазин битов" : "Beat Shop" }
    static var beatShopDesc: String { ru ? "Откройте для себя маркетплейс битов — покупайте, продавайте и загружайте свои биты." : "Discover the beat marketplace — buy, sell, and upload your own beats." }
    static var beatShopFeature1: String { ru ? "Каталог с фильтрами" : "Catalog with Filters" }
    static var beatShopFeature2: String { ru ? "Предпрослушивание битов" : "Beat Previews" }
    static var beatShopFeature3: String { ru ? "Загрузка своих битов" : "Upload Your Beats" }
    static var makeItYours: String { ru ? "Сделай по-своему" : "Make It Yours" }
    static var makeItYoursDesc: String { ru ? "Настройте тему, цвета и язык под свой стиль." : "Customize themes, colors, and language to match your style." }
    static var makeItYoursFeature1: String { ru ? "Темы и цвета" : "Themes & Colors" }
    static var makeItYoursFeature2: String { ru ? "Светлый и тёмный режим" : "Light & Dark Mode" }
    static var makeItYoursFeature3: String { ru ? "Русский и английский" : "Russian & English" }
    static var getStarted: String { ru ? "Начать" : "Get Started" }
    static var skip: String { ru ? "Пропустить" : "Skip" }

    // Appearance
    static var accentColor: String { ru ? "Цвет акцента" : "Accent Color" }
    static var previewTrack: String { ru ? "Пример трека" : "Preview Track" }
    static var artistName: String { ru ? "Имя артиста" : "Artist Name" }
    static var sliderIcon: String { ru ? "Иконка ползунка" : "Slider Icon" }
    static var current: String { ru ? "Текущая" : "Current" }
    static var sliderIconHint: String { ru ? "Выберите иконку, которая будет ехать по полосе прогресса" : "Choose an icon that rides along the progress bar while music plays" }
    static var coverGradient: String { ru ? "Градиент из обложки" : "Cover Gradient" }
    static var coverGradientHint: String {
        ru
            ? "Фон плеера подстраивается под цвета обложки текущего трека"
            : "Player background adapts to the colours of the current cover art"
    }

    // Reactions + activity feed
    static var reactToTrack: String {
        ru ? "Реакция на трек" : "React to track"
    }
    static var reactionsInbox: String {
        ru ? "Реакции" : "Reactions"
    }
    static var noReactionsYet: String {
        ru ? "Пока нет реакций" : "No reactions yet"
    }
    static var noReactionsHint: String {
        ru
            ? "Когда друзья реагируют на твою музыку, они появятся здесь"
            : "When friends react to your music, they'll show up here"
    }
    static var reactedTo: String {
        ru ? "отреагировал на" : "reacted to"
    }

    // Appearance modes
    static var systemMode: String { ru ? "Система" : "System" }
    static var lightMode: String { ru ? "Светлая" : "Light" }
    static var darkMode: String { ru ? "Тёмная" : "Dark" }

    // MARK: - Shop Tab
    static var shop: String { ru ? "Магазин" : "Shop" }
    static var searchBeats: String { ru ? "Поиск битов" : "Search beats" }
    static var noBeatsFound: String { ru ? "Биты не найдены" : "No Beats Found" }
    static var noBeatsFoundHint: String { ru ? "Попробуйте изменить фильтры или поиск" : "Try adjusting your filters or search" }

    // Filters
    static var filters: String { ru ? "Фильтры" : "Filters" }
    static var genre: String { ru ? "Жанр" : "Genre" }
    static var allGenres: String { ru ? "Все жанры" : "All Genres" }
    static var bpm: String { "BPM" }
    static var key: String { ru ? "Тональность" : "Key" }
    static var allKeys: String { ru ? "Все тональности" : "All Keys" }
    static var price: String { ru ? "Цена" : "Price" }
    static var priceRange: String { ru ? "Диапазон цен" : "Price Range" }
    static var bpmRange: String { ru ? "Диапазон BPM" : "BPM Range" }
    static var resetFilters: String { ru ? "Сбросить фильтры" : "Reset Filters" }
    static var applyFilters: String { ru ? "Применить" : "Apply" }

    // Beat Detail
    static var preview: String { ru ? "Превью" : "Preview" }
    static var stopPreview: String { ru ? "Остановить" : "Stop" }
    static var buyBeat: String { ru ? "Купить бит" : "Buy Beat" }
    static var purchased: String { ru ? "Куплено" : "Purchased" }
    static var confirmPurchase: String { ru ? "Подтвердить покупку?" : "Confirm Purchase?" }
    static var confirmPurchaseMsg: String { ru ? "Вы собираетесь купить этот бит за" : "You are about to purchase this beat for" }
    static var buy: String { ru ? "Купить" : "Buy" }
    static var beatInfo: String { ru ? "Информация" : "Beat Info" }
    static var duration: String { ru ? "Длительность" : "Duration" }
    static var addedOn: String { ru ? "Добавлен" : "Added" }
    static var waveform: String { ru ? "Волновая форма" : "Waveform" }
    static var equalizer: String { ru ? "Эквалайзер" : "Equalizer" }

    // Upload
    static var uploadBeat: String { ru ? "Загрузить бит" : "Upload Beat" }
    static var beatTitle: String { ru ? "Название бита" : "Beat Title" }
    static var beatmakerLabel: String { ru ? "Битмейкер" : "Beatmaker" }
    static var coverImage: String { ru ? "Обложка" : "Cover Image" }
    static var selectCover: String { ru ? "Выбрать обложку" : "Select Cover" }
    static var removeCover: String { ru ? "Убрать" : "Remove" }
    static var audioFile: String { ru ? "Аудиофайл" : "Audio File" }
    static var selectFile: String { ru ? "Выбрать файл" : "Select File" }
    static var upload: String { ru ? "Загрузить" : "Upload" }
    static var uploadSuccess: String { ru ? "Бит загружен!" : "Beat Uploaded!" }

    // Roles
    static var role: String { ru ? "Роль" : "Role" }
    static var roleListener: String { ru ? "Слушатель" : "Listener" }
    static var roleArtist: String { ru ? "Артист" : "Artist" }
    static var roleBeatmaker: String { ru ? "Битмейкер" : "Beatmaker" }
    static var selectRole: String { ru ? "Выберите роль" : "Select Role" }

    // Purchase History & Stats
    static var purchaseHistory: String { ru ? "История покупок" : "Purchase History" }
    static var noPurchases: String { ru ? "Нет покупок" : "No Purchases Yet" }
    static var noPurchasesHint: String { ru ? "Купленные биты появятся здесь" : "Purchased beats will appear here" }
    static var totalSpent: String { ru ? "Потрачено" : "Total Spent" }
    static var statistics: String { ru ? "Статистика" : "Statistics" }
    static var totalPurchases: String { ru ? "Всего покупок" : "Total Purchases" }
    static var totalSales: String { ru ? "Всего продаж" : "Total Sales" }
    static var totalEarned: String { ru ? "Заработано" : "Total Earned" }
    static var beatsUploaded: String { ru ? "Загружено битов" : "Beats Uploaded" }
    static var yourBeat: String { ru ? "Ваш бит" : "Your Beat" }
    static var earned: String { ru ? "Заработано" : "Earned" }
    static var optional: String { ru ? "необязательно" : "optional" }

    // TON Wallet
    static var connect: String { ru ? "Подключить" : "Connect" }
    static var disconnect: String { ru ? "Отключить" : "Disconnect" }
    static var connected: String { ru ? "Подключён" : "Connected" }
    static var balance: String { ru ? "Баланс" : "Balance" }
    static var refreshBalance: String { ru ? "Обновить баланс" : "Refresh Balance" }
    static var connectTonWallet: String { ru ? "Подключить TON кошелёк" : "Connect TON Wallet" }
    static var connectTonHint: String { ru ? "Подключите кошелёк одним нажатием через Tonkeeper или Telegram" : "Connect your wallet with one tap via Tonkeeper or Telegram" }
    static var walletAddress: String { ru ? "Адрес кошелька" : "Wallet address" }
    static var pasteFromClipboard: String { ru ? "Вставить из буфера" : "Paste from clipboard" }
    static var disconnectWalletMsg: String { ru ? "Вы уверены что хотите отключить кошелёк?" : "Are you sure you want to disconnect your wallet?" }
    static var tonWalletInfo: String { ru ? "TON кошелёк используется для покупки и продажи битов. Оплата происходит через Tonkeeper." : "TON wallet is used to buy and sell beats. Payments are processed via Tonkeeper." }
    static var payWithTon: String { ru ? "Оплатить TON" : "Pay with TON" }
    static var openTonkeeper: String { ru ? "Открыть Tonkeeper" : "Open Tonkeeper" }
    static var copyAddressThere: String { ru ? "Скопируйте адрес и вернитесь" : "Copy your address and come back" }
    static var walletNotConnected: String { ru ? "Кошелёк не подключён" : "Wallet not connected" }
    static var connectWalletFirst: String { ru ? "Подключите TON кошелёк в настройках" : "Connect your TON wallet in Settings" }
    static var connectViaTonkeeper: String { ru ? "Подключить через Tonkeeper" : "Connect via Tonkeeper" }
    static var connectViaTelegram: String { ru ? "Подключить через Telegram" : "Connect via Telegram" }
    static var oneTapConnect: String { ru ? "Авторизация в один клик" : "One-tap authorization" }
    static var connecting: String { ru ? "Подключение..." : "Connecting..." }
    static var manualConnect: String { ru ? "Подключить вручную" : "Connect manually" }
    static var waitingForWallet: String { ru ? "Ожидание подтверждения в кошельке..." : "Waiting for wallet confirmation..." }
    static var connectionFailed: String { ru ? "Ошибка подключения" : "Connection failed" }
    static var decryptionFailed: String { ru ? "Не удалось расшифровать ответ" : "Failed to decrypt wallet response" }
    static var tryAgain: String { ru ? "Попробовать снова" : "Try again" }
    static var pasteAddressHint: String { ru ? "Скопируйте адрес в кошельке и вернитесь — он вставится автоматически" : "Copy your address in the wallet and come back — it will paste automatically" }

    // Import Review
    static var reviewImport: String { ru ? "Проверка импорта" : "Review Import" }
    static var trackTitle: String { ru ? "Название" : "Title" }
    static var fileInfo: String { ru ? "Файл" : "File" }
    static var addCover: String { ru ? "Добавить обложку" : "Add Cover" }
    static var changeCover: String { ru ? "Изменить обложку" : "Change Cover" }
    static var importTrack: String { ru ? "Импортировать" : "Import" }

    // Queue
    static var queue: String { ru ? "Очередь" : "Queue" }
    static var addToQueue: String { ru ? "В очередь" : "Add to Queue" }
    static var emptyQueue: String { ru ? "Очередь пуста" : "Queue is Empty" }
    static var emptyQueueHint: String { ru ? "Добавьте треки из библиотеки" : "Add tracks from your library" }
    static var next: String { ru ? "Далее" : "Next" }

    // Share
    static var share: String { ru ? "Поделиться" : "Share" }
    static var nowListening: String { ru ? "Сейчас слушаю" : "Now Listening" }
    static var copy: String { ru ? "Копировать" : "Copy" }

    // Sleep Timer
    static var sleepTimer: String { ru ? "Таймер сна" : "Sleep Timer" }
    static var sleepTimerOff: String { ru ? "Выключен" : "Off" }
    static var minutesSuffix: String { ru ? "мин" : "min" }
    static var endOfTrack: String { ru ? "Конец трека" : "End of Track" }
    static var timerActive: String { ru ? "Таймер активен" : "Timer Active" }
    static var cancelTimer: String { ru ? "Отменить таймер" : "Cancel Timer" }

    // Crossfade
    static var crossfade: String { ru ? "Кроссфейд" : "Crossfade" }
    static var crossfadeHint: String { ru ? "Плавный переход между треками" : "Smooth transition between tracks" }
    static var seconds: String { ru ? "сек" : "sec" }
    static var off: String { ru ? "Выкл" : "Off" }
    static var appIcon: String { ru ? "Иконка приложения" : "App Icon" }
    static var defaultIcon: String { ru ? "Стандартная" : "Default" }
    static var customIcon: String { ru ? "Свой символ" : "Custom Symbol" }
    static var enterSymbolName: String { ru ? "Имя SF Symbol" : "SF Symbol name" }

    // Stats Tab
    static var stats: String { ru ? "Статистика" : "Stats" }

    // Home Tab
    static var home: String { ru ? "Главная" : "Home" }
    static var recentlyPlayed: String { ru ? "Недавно играли" : "Recently Played" }
    static var recentlyAdded: String { ru ? "Недавно добавлено" : "Recently Added" }
    static var recentlyLiked: String { ru ? "Недавно в избранном" : "Recently Liked" }
    static var topTracks: String { ru ? "Топ треки" : "Top Tracks" }
    static var topArtists: String { ru ? "Топ артисты" : "Top Artists" }
    static var yourPlaylists: String { ru ? "Ваши плейлисты" : "Your Playlists" }
    static var totalPlays: String { ru ? "Воспроизведений" : "Total Plays" }
    static var timeListened: String { ru ? "Время прослушивания" : "Time Listened" }
    static var yourStats: String { ru ? "Ваша статистика" : "Your Stats" }
    static var noActivity: String { ru ? "Нет активности" : "No Activity Yet" }
    static var noActivityHint: String { ru ? "Начните слушать музыку, чтобы увидеть статистику" : "Start listening to see your stats" }
    static var plays: String { ru ? "прослуш." : "plays" }
    static var today: String { ru ? "Статистика за сегодня" : "Your stats today" }
    static var listened: String { ru ? "Прослушано" : "Listened" }
    static var seeAll: String { ru ? "Все" : "See All" }
    static var hoursShort: String { ru ? "ч" : "h" }
    static var minutesShort: String { ru ? "мин" : "min" }

}

@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: AppTheme {
        didSet { UserDefaults.standard.set(currentTheme.rawValue, forKey: UserDefaultsKey.appTheme) }
    }

    @Published var appearance: AppAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: UserDefaultsKey.appAppearance) }
    }

    @Published var sliderIcon: SliderIcon {
        didSet { UserDefaults.standard.set(sliderIcon.rawValue, forKey: UserDefaultsKey.sliderIcon) }
    }

    @Published var customSliderSymbol: String {
        didSet { UserDefaults.standard.set(customSliderSymbol, forKey: UserDefaultsKey.customSliderSymbol) }
    }

    var activeSliderSymbol: String {
        if sliderIcon == .custom {
            return customSliderSymbol.isEmpty ? "circle.fill" : customSliderSymbol
        }
        return sliderIcon.sfSymbol
    }

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: UserDefaultsKey.appLanguage) }
    }

    /// When true, PlayerView's background is driven by a palette
    /// extracted from the current cover art (animated MeshGradient).
    /// Off by default — keeps the static theme gradient.
    @Published var useCoverGradient: Bool {
        didSet { UserDefaults.standard.set(useCoverGradient, forKey: UserDefaultsKey.useCoverGradient) }
    }

    private init() {
        let themeRaw = UserDefaults.standard.string(forKey: UserDefaultsKey.appTheme) ?? "Purple"
        self.currentTheme = AppTheme(rawValue: themeRaw) ?? .purple

        let appearanceRaw = UserDefaults.standard.string(forKey: UserDefaultsKey.appAppearance) ?? "Dark"
        self.appearance = AppAppearance(rawValue: appearanceRaw) ?? .dark

        let sliderRaw = UserDefaults.standard.string(forKey: UserDefaultsKey.sliderIcon) ?? "Default"
        self.sliderIcon = SliderIcon(rawValue: sliderRaw) ?? .defaultCircle
        self.customSliderSymbol = UserDefaults.standard.string(forKey: UserDefaultsKey.customSliderSymbol) ?? ""

        let langRaw = UserDefaults.standard.string(forKey: UserDefaultsKey.appLanguage) ?? "en"
        self.language = AppLanguage(rawValue: langRaw) ?? .english

        self.useCoverGradient = UserDefaults.standard.bool(forKey: UserDefaultsKey.useCoverGradient)
    }
}
