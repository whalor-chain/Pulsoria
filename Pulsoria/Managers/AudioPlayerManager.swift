import Foundation
import AVFoundation
import Combine
import MediaPlayer
import OSLog
import UIKit

enum RepeatMode: Int {
    case off = 0
    case one = 1
    case all = 2

    var icon: String {
        switch self {
        case .off: return "repeat"
        case .one: return "repeat.1"
        case .all: return "repeat"
        }
    }

    var next: RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }
}

@MainActor
class AudioPlayerManager: NSObject, ObservableObject {
    static let shared = AudioPlayerManager()

    @Published var tracks: [Track] = []
    @Published var currentTrack: Track?
    @Published var currentTrackIndex: Int = 0
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    // Meter data — NOT @Published to avoid re-rendering non-visualizer views
    var audioLevel: Float = 0
    var bassLevel: Float = 0
    var isBeat: Bool = false
    var frequencyBands: [Float] = Array(repeating: 0, count: 8)
    var midLevel: Float = 0
    var trebleLevel: Float = 0
    var spectralFlux: Float = 0
    // Dedicated publisher for visualizer views only
    let meterUpdate = PassthroughSubject<Void, Never>()
    @Published var repeatMode: RepeatMode = .off
    @Published var isShuffleOn: Bool = false
    var artworkCache: [String: Data] = [:]
    @Published var queue: [Track] = []
    @Published var playingSource: String = ""

    // Sleep Timer
    @Published var sleepTimerRemaining: TimeInterval = 0
    @Published var sleepTimerEndOfTrack: Bool = false
    var isSleepTimerActive: Bool { sleepTimerRemaining > 0 || sleepTimerEndOfTrack }

    // Crossfade
    @Published var crossfadeDuration: TimeInterval {
        didSet { UserDefaults.standard.set(crossfadeDuration, forKey: UserDefaultsKey.crossfadeDuration) }
    }

    private(set) var audioPlayer: AVAudioPlayer?
    private var crossfadePlayer: AVAudioPlayer?
    private var crossfadeTimer: Timer?
    private var isCrossfading: Bool = false
    private var progressTimer: Timer?
    private var meterTimer: Timer?
    private var sleepTimer: Timer?
    private var shuffledIndices: [Int] = []
    private var shufflePosition: Int = 0
    private var previousLevel: Float = 0
    private var beatCooldown: Int = 0
    private var listeningAccumulator: TimeInterval = 0
    private var geniusTask: Task<Void, Never>?

    private func invalidateCaches() {
        _topTracksCache = nil
        _topArtistsCache = nil
    }

    // Meter history for frequency estimation (last 30 samples ≈ 900ms at 30ms interval)
    private var levelHistory: [Float] = []
    private var peakHistory: [Float] = []
    private let historySize = 30
    private var previousBands: [Float] = Array(repeating: 0, count: 8)

    private let appGroupID = "group.Wave.Pulsoria"

    private override init() {
        self.crossfadeDuration = UserDefaults.standard.double(forKey: UserDefaultsKey.crossfadeDuration)
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
        loadTracksFromDocuments()
    }

    // MARK: - Audio Session

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            Logger.audio.error("Failed to setup audio session: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Remote Command Center

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.nextTrack() }
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previousTrack() }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in self?.seek(to: event.positionTime) }
            return .success
        }
    }

    // MARK: - Track Loading

    func loadTracksFromDocuments() {
        guard let documentsURL = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else { return }

        let favoriteIDs = UserDefaults.standard.stringArray(forKey: UserDefaultsKey.favoriteTrackIDs) ?? []
        let playCounts = UserDefaults.standard.dictionary(forKey: UserDefaultsKey.trackPlayCounts) as? [String: Int] ?? [:]
        let lastPlayedDict = UserDefaults.standard.dictionary(forKey: UserDefaultsKey.trackLastPlayed) as? [String: Double] ?? [:]
        let dateAddedDict = UserDefaults.standard.dictionary(forKey: UserDefaultsKey.trackDateAdded) as? [String: Double] ?? [:]

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: nil
            )
            let audioExtensions = ["mp3", "m4a", "wav", "aac"]
            let audioFiles = files.filter { audioExtensions.contains($0.pathExtension.lowercased()) }

            let loadedTracks = audioFiles.map { url -> Track in
                let name = url.deletingPathExtension().lastPathComponent
                let parts = name.components(separatedBy: " - ")
                let artist = parts.count > 1
                    ? parts[0].trimmingCharacters(in: .whitespaces)
                    : "Unknown Artist"
                let title = parts.count > 1
                    ? parts[1].trimmingCharacters(in: .whitespaces)
                    : name

                let fn = url.deletingPathExtension().lastPathComponent
                return Track(
                    title: title,
                    artist: artist,
                    fileName: fn,
                    fileExtension: url.pathExtension,
                    isFavorite: favoriteIDs.contains(fn),
                    playCount: playCounts[fn] ?? 0,
                    lastPlayed: lastPlayedDict[fn].map { Date(timeIntervalSince1970: $0) },
                    dateAdded: dateAddedDict[fn].map { Date(timeIntervalSince1970: $0) } ?? Date()
                )
            }

            // Restore saved track order
            let savedOrder = UserDefaults.standard.stringArray(forKey: UserDefaultsKey.trackOrder) ?? []
            if savedOrder.isEmpty {
                tracks = loadedTracks
            } else {
                var ordered: [Track] = []
                for fileName in savedOrder {
                    if let track = loadedTracks.first(where: { $0.fileName == fileName }) {
                        ordered.append(track)
                    }
                }
                // Append any new tracks not in saved order
                for track in loadedTracks where !ordered.contains(where: { $0.fileName == track.fileName }) {
                    ordered.insert(track, at: 0)
                }
                tracks = ordered
            }

            if !tracks.isEmpty {
                generateShuffledIndices()
            }

        } catch {
            Logger.audio.error("Failed to load tracks: \(error.localizedDescription, privacy: .public)")
        }
    }


    func importTrack(from sourceURL: URL, title: String, artist: String, artworkData: Data?) {
        guard let documentsURL = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else { return }

        let ext = sourceURL.pathExtension
        let newFileName = "\(artist) - \(title)"
        let destination = documentsURL.appendingPathComponent("\(newFileName).\(ext)")

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destination)

            let track = Track(
                title: title,
                artist: artist,
                fileName: newFileName,
                fileExtension: ext
            )
            tracks.insert(track, at: 0)
            invalidateCaches()
            generateShuffledIndices()

            if let data = artworkData {
                artworkCache[newFileName] = data
                saveArtworkToDisk(data, for: newFileName)
                objectWillChange.send()
            }

            saveTrackOrder()
            saveDateAdded()
            StatsManager.shared.checkAchievements()
        } catch {
            Logger.audio.error("Failed to import track: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Shared Files Import

    /// Returns URLs of shared audio files (moved to temp), or empty array
    func getSharedFiles() -> [URL] {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else { return [] }

        let sharedDir = containerURL.appendingPathComponent("SharedAudio", isDirectory: true)
        guard FileManager.default.fileExists(atPath: sharedDir.path) else { return [] }

        let files = (try? FileManager.default.contentsOfDirectory(
            at: sharedDir, includingPropertiesForKeys: nil
        )) ?? []

        let audioExtensions = Set(["mp3", "m4a", "wav", "aiff", "flac", "aac", "ogg", "wma"])
        var result: [URL] = []

        for fileURL in files {
            let ext = fileURL.pathExtension.lowercased()
            guard audioExtensions.contains(ext) else {
                try? FileManager.default.removeItem(at: fileURL)
                continue
            }

            // Move to temp so LibraryView can handle like normal file import
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileURL.lastPathComponent)
            try? FileManager.default.removeItem(at: tempURL)
            do {
                try FileManager.default.moveItem(at: fileURL, to: tempURL)
                result.append(tempURL)
            } catch {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }

        // Clean up shared directory
        try? FileManager.default.removeItem(at: sharedDir)
        return result
    }
    // MARK: - Artwork

    private var artworksDirectory: URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let dir = docs.appendingPathComponent("Artworks", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func saveArtworkToDisk(_ data: Data, for fileName: String) {
        guard let dir = artworksDirectory else { return }
        let fileURL = dir.appendingPathComponent("\(fileName).jpg")
        try? data.write(to: fileURL)
    }

    private func loadArtworkFromDisk(for fileName: String) -> Data? {
        guard let dir = artworksDirectory else { return nil }
        let fileURL = dir.appendingPathComponent("\(fileName).jpg")
        return try? Data(contentsOf: fileURL)
    }

    func loadArtwork(for track: Track) async {
        let key = track.fileName
        guard artworkCache[key] == nil else { return }

        // 1. Check saved artwork on disk
        if let diskData = loadArtworkFromDisk(for: key) {
            artworkCache[key] = diskData
            objectWillChange.send()
            return
        }

        // 2. Try embedded metadata
        guard let url = track.fileURL else { return }
        let asset = AVURLAsset(url: url)
        do {
            let metadata = try await asset.load(.commonMetadata)
            let items = AVMetadataItem.metadataItems(
                from: metadata,
                filteredByIdentifier: .commonIdentifierArtwork
            )
            if let item = items.first, let data = try await item.load(.dataValue) {
                artworkCache[key] = data
                saveArtworkToDisk(data, for: key)
                objectWillChange.send()
                return
            }
        } catch { }

        // 3. Fallback: fetch from Genius
        if let data = await GeniusManager.shared.fetchSongArtworkData(title: track.title, artist: track.artist) {
            artworkCache[key] = data
            saveArtworkToDisk(data, for: key)
            objectWillChange.send()
        }
    }

    // MARK: - Playback

    func playTrack(at index: Int) {
        guard index >= 0, index < tracks.count else { return }
        isCrossfading = false
        flushListeningTime()

        currentTrackIndex = index
        tracks[index].playCount += 1
        tracks[index].lastPlayed = Date()
        currentTrack = tracks[index]
        invalidateCaches()
        saveTrackData()
        incrementTodayPlays()
        StatsManager.shared.recordPlay()
        StatsManager.shared.checkAchievements()

        guard let url = tracks[index].fileURL else { return }

        do {
            // Crossfade: keep old player fading out
            if crossfadeDuration > 0, let oldPlayer = audioPlayer, oldPlayer.isPlaying {
                crossfadePlayer?.stop()
                crossfadePlayer = oldPlayer
                startCrossfadeOut()
            } else {
                audioPlayer?.stop()
            }

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.isMeteringEnabled = true
            audioPlayer?.prepareToPlay()

            if crossfadeDuration > 0 && crossfadePlayer != nil {
                audioPlayer?.volume = 0
            }

            audioPlayer?.play()

            if crossfadeDuration > 0 && crossfadePlayer != nil {
                startCrossfadeIn()
            }

            isPlaying = true
            duration = audioPlayer?.duration ?? 0
            currentTime = 0

            startTimers()
            updateNowPlayingInfo()

            geniusTask?.cancel()
            geniusTask = Task {
                await loadArtwork(for: tracks[index])
                guard !Task.isCancelled else { return }
                let track = tracks[index]
                await GeniusManager.shared.prefetchArtists(from: track.artist)
                guard !Task.isCancelled else { return }
                await GeniusManager.shared.fetchSyncedLyrics(title: track.title, artist: track.artist)
                guard !Task.isCancelled else { return }
                // Fallback to Genius plain lyrics if no synced lyrics found
                let lyricsKey = "\(track.title) - \(track.artist)".lowercased()
                if GeniusManager.shared.cachedSyncedLyrics[lyricsKey] == nil {
                    await GeniusManager.shared.fetchLyrics(title: track.title, artist: track.artist)
                }
            }
        } catch {
            Logger.audio.error("Failed to play track: \(error.localizedDescription, privacy: .public)")
        }
    }

    func play() {
        if audioPlayer == nil, !tracks.isEmpty {
            playTrack(at: currentTrackIndex)
        } else {
            audioPlayer?.play()
            isPlaying = true
            startTimers()
            updateNowPlayingInfo()
        }
    }

    func pause() {
        flushListeningTime()
        audioPlayer?.pause()
        isPlaying = false
        stopTimers()
        updateNowPlayingInfo()
    }

    private func flushListeningTime() {
        if listeningAccumulator > 0 {
            addListeningTime(listeningAccumulator)
            listeningAccumulator = 0
        }
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func nextTrack() {
        guard !tracks.isEmpty else { return }

        // Play from queue first
        if !queue.isEmpty {
            let nextTrack = queue.removeFirst()
            if let index = tracks.firstIndex(where: { $0.id == nextTrack.id }) {
                playTrack(at: index)
            } else {
                // Fallback if track removed from library
                if isShuffleOn {
                    shufflePosition = (shufflePosition + 1) % shuffledIndices.count
                    playTrack(at: shuffledIndices[shufflePosition])
                } else {
                    let nextIndex = (currentTrackIndex + 1) % tracks.count
                    playTrack(at: nextIndex)
                }
            }
            return
        }

        if isShuffleOn {
            shufflePosition = (shufflePosition + 1) % shuffledIndices.count
            playTrack(at: shuffledIndices[shufflePosition])
        } else {
            let nextIndex = (currentTrackIndex + 1) % tracks.count
            playTrack(at: nextIndex)
        }
    }

    func previousTrack() {
        guard !tracks.isEmpty else { return }

        if currentTime > 3 {
            seek(to: 0)
            return
        }

        if isShuffleOn {
            shufflePosition = (shufflePosition - 1 + shuffledIndices.count) % shuffledIndices.count
            playTrack(at: shuffledIndices[shufflePosition])
        } else {
            let prevIndex = (currentTrackIndex - 1 + tracks.count) % tracks.count
            playTrack(at: prevIndex)
        }
    }

    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
        updateNowPlayingInfo()
    }

    func addToQueue(_ track: Track) {
        queue.append(track)
        StatsManager.shared.recordQueueAdd()
    }

    func addCurrentTrackToQueue() {
        if let track = currentTrack {
            queue.append(track)
        }
    }

    func toggleFavoriteForCurrentTrack() {
        if let track = currentTrack {
            toggleFavorite(for: track)
        }
    }

    func removeFromQueue(at index: Int) {
        guard index >= 0, index < queue.count else { return }
        queue.remove(at: index)
    }

    func toggleRepeatMode() {
        repeatMode = repeatMode.next
    }

    func toggleShuffle() {
        isShuffleOn.toggle()
        if isShuffleOn {
            generateShuffledIndices()
        }
    }

    // MARK: - Crossfade

    private func startCrossfadeOut() {
        crossfadeTimer?.invalidate()
        let fadeSteps = 20
        let stepInterval = crossfadeDuration / Double(fadeSteps)
        let volumeStep = (crossfadePlayer?.volume ?? 1.0) / Float(fadeSteps)
        var step = 0

        crossfadeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { timer.invalidate(); return }
                step += 1
                self.crossfadePlayer?.volume = max(0, (self.crossfadePlayer?.volume ?? 0) - volumeStep)
                if step >= fadeSteps {
                    timer.invalidate()
                    self.crossfadePlayer?.stop()
                    self.crossfadePlayer = nil
                    self.crossfadeTimer = nil
                }
            }
        }
    }

    private func startCrossfadeIn() {
        let fadeSteps = 20
        let stepInterval = crossfadeDuration / Double(fadeSteps)
        let volumeStep: Float = 1.0 / Float(fadeSteps)
        var step = 0

        Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { timer.invalidate(); return }
                step += 1
                self.audioPlayer?.volume = min(1.0, (self.audioPlayer?.volume ?? 0) + volumeStep)
                if step >= fadeSteps {
                    timer.invalidate()
                    self.audioPlayer?.volume = 1.0
                }
            }
        }
    }

    // MARK: - Sleep Timer

    func startSleepTimer(minutes: Int) {
        cancelSleepTimer()
        sleepTimerEndOfTrack = false
        sleepTimerRemaining = TimeInterval(minutes * 60)
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.sleepTimerRemaining -= 1
                if self.sleepTimerRemaining <= 0 {
                    self.sleepTimerRemaining = 0
                    self.cancelSleepTimer()
                    self.pause()
                }
            }
        }
    }

    func startSleepTimerEndOfTrack() {
        cancelSleepTimer()
        sleepTimerEndOfTrack = true
        sleepTimerRemaining = 0
    }

    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerRemaining = 0
        sleepTimerEndOfTrack = false
    }

    // MARK: - Delete

    func deleteTrack(_ track: Track) {
        if currentTrack?.id == track.id {
            pause()
            audioPlayer?.stop()
            audioPlayer = nil
            currentTrack = nil
            currentTime = 0
            duration = 0
        }

        if let url = track.fileURL {
            try? FileManager.default.removeItem(at: url)
        }

        tracks.removeAll { $0.id == track.id }
        invalidateCaches()
        artworkCache.removeValue(forKey: track.fileName)
        if let dir = artworksDirectory {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent("\(track.fileName).jpg"))
        }
        saveFavorites()
        saveTrackOrder()
        savePlayCounts()
        saveLastPlayed()
        saveDateAdded()

        if !tracks.isEmpty {
            generateShuffledIndices()
        }
    }

    // MARK: - Favorites

    func toggleFavorite(for track: Track) {
        guard let index = tracks.firstIndex(where: { $0.id == track.id }) else { return }
        tracks[index].isFavorite.toggle()
        invalidateCaches()

        if tracks[index].id == currentTrack?.id {
            currentTrack?.isFavorite = tracks[index].isFavorite
        }

        saveFavorites()
        StatsManager.shared.checkAchievements()
    }

    private func saveFavorites() {
        let favoriteIDs = tracks.filter(\.isFavorite).map(\.fileName)
        UserDefaults.standard.set(favoriteIDs, forKey: UserDefaultsKey.favoriteTrackIDs)
    }

    private func saveTrackOrder() {
        let order = tracks.map(\.fileName)
        UserDefaults.standard.set(order, forKey: UserDefaultsKey.trackOrder)
    }

    // MARK: - Play Tracking

    private func savePlayCounts() {
        let dict = Dictionary(uniqueKeysWithValues: tracks.map { ($0.fileName, $0.playCount) })
        UserDefaults.standard.set(dict, forKey: UserDefaultsKey.trackPlayCounts)
    }

    private func saveLastPlayed() {
        let dict = Dictionary(uniqueKeysWithValues: tracks.compactMap { track -> (String, Double)? in
            guard let date = track.lastPlayed else { return nil }
            return (track.fileName, date.timeIntervalSince1970)
        })
        UserDefaults.standard.set(dict, forKey: UserDefaultsKey.trackLastPlayed)
    }

    private func saveTrackData() {
        savePlayCounts()
        saveLastPlayed()
    }

    private func saveDateAdded() {
        let dict = Dictionary(uniqueKeysWithValues: tracks.map { ($0.fileName, $0.dateAdded.timeIntervalSince1970) })
        UserDefaults.standard.set(dict, forKey: UserDefaultsKey.trackDateAdded)
    }

    // MARK: - Dashboard Data

    var recentlyPlayed: [Track] {
        tracks.filter { $0.lastPlayed != nil }
            .sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
    }

    var recentlyAdded: [Track] {
        tracks.sorted { $0.dateAdded > $1.dateAdded }
    }

    var recentlyLiked: [Track] {
        tracks.filter(\.isFavorite)
    }

    private var _topTracksCache: [Track]?
    var topTracks: [Track] {
        if let cached = _topTracksCache { return cached }
        let result = tracks.filter { $0.playCount > 0 }
            .sorted { $0.playCount != $1.playCount ? $0.playCount > $1.playCount : $0.title < $1.title }
        _topTracksCache = result
        return result
    }

    private var _topArtistsCache: [(name: String, playCount: Int)]?
    var topArtists: [(name: String, playCount: Int)] {
        if let cached = _topArtistsCache { return cached }
        var artistCounts: [String: Int] = [:]
        for track in tracks {
            for artist in track.artistNames {
                artistCounts[artist, default: 0] += track.playCount
            }
        }
        let result = artistCounts
            .filter { $0.value > 0 }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .map { (name: $0.key, playCount: $0.value) }
        _topArtistsCache = result
        return result
    }

    var totalPlays: Int {
        tracks.reduce(0) { $0 + $1.playCount }
    }

    var totalListeningTime: TimeInterval {
        UserDefaults.standard.double(forKey: UserDefaultsKey.totalListeningSeconds)
    }

    private static let todayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var todayKey: String {
        Self.todayFormatter.string(from: Date())
    }

    var todayPlays: Int {
        UserDefaults.standard.integer(forKey: UserDefaultsKey.playsToday(todayKey))
    }

    var todayListeningTime: TimeInterval {
        UserDefaults.standard.double(forKey: UserDefaultsKey.listeningToday(todayKey))
    }

    private func incrementTodayPlays() {
        let key = UserDefaultsKey.playsToday(todayKey)
        let current = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(current + 1, forKey: key)
    }

    private func addListeningTime(_ seconds: TimeInterval) {
        let totalKey = UserDefaultsKey.totalListeningSeconds
        let todayLKey = UserDefaultsKey.listeningToday(todayKey)
        let total = UserDefaults.standard.double(forKey: totalKey) + seconds
        let today = UserDefaults.standard.double(forKey: todayLKey) + seconds
        UserDefaults.standard.set(total, forKey: totalKey)
        UserDefaults.standard.set(today, forKey: todayLKey)
    }

    // MARK: - Shuffle

    private func generateShuffledIndices() {
        shuffledIndices = Array(0..<tracks.count).shuffled()
        shufflePosition = 0
    }

    // MARK: - Timers

    private func startTimers() {
        stopTimers()

        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let player = self.audioPlayer else { return }
                self.currentTime = player.currentTime
                if player.isPlaying {
                    self.listeningAccumulator += 0.25
                    if self.listeningAccumulator >= 5.0 {
                        self.addListeningTime(self.listeningAccumulator)
                        self.listeningAccumulator = 0
                    }

                    // Auto-crossfade: trigger next track early
                    if self.crossfadeDuration > 0 && !self.isCrossfading && self.repeatMode != .one {
                        let remaining = self.duration - self.currentTime
                        if remaining > 0 && remaining <= self.crossfadeDuration {
                            self.isCrossfading = true
                            self.nextTrack()
                        }
                    }
                }
            }
        }

        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let player = self.audioPlayer else { return }
                player.updateMeters()

                let power = player.averagePower(forChannel: 0)
                let linear = max(0, (power + 50) / 50)
                let curved = sqrt(linear)
                self.audioLevel = curved

                let peakPower = player.peakPower(forChannel: 0)
                let peakLinear = max(0, (peakPower + 50) / 50)
                let peakCurved = sqrt(peakLinear)
                self.bassLevel = peakCurved

                // Build meter history
                self.levelHistory.append(curved)
                self.peakHistory.append(peakCurved)
                if self.levelHistory.count > self.historySize {
                    self.levelHistory.removeFirst()
                    self.peakHistory.removeFirst()
                }

                // Frequency band estimation from meter dynamics
                self.updateFrequencyBands(level: curved, peak: peakCurved)

                // Beat detection
                let delta = curved - self.previousLevel
                if self.beatCooldown > 0 { self.beatCooldown -= 1 }
                if delta > 0.10 && self.beatCooldown == 0 {
                    self.isBeat = true
                    self.beatCooldown = 6
                } else {
                    self.isBeat = false
                }
                self.previousLevel = curved
                self.meterUpdate.send()
            }
        }
        // meterTimer stays in .default mode — no need to update visuals during scroll
    }

    private func updateFrequencyBands(level: Float, peak: Float) {
        let h = levelHistory
        let ph = peakHistory
        guard h.count >= 4 else { return }

        // Averages at different time scales
        let longAvg = h.reduce(0, +) / Float(h.count)                           // ~900ms
        let medCount = min(12, h.count)
        let medAvg = h.suffix(medCount).reduce(0, +) / Float(medCount)          // ~360ms
        let shortCount = min(5, h.count)
        let shortAvg = h.suffix(shortCount).reduce(0, +) / Float(shortCount)    // ~150ms
        let veryShort = h.suffix(2).reduce(0, +) / 2.0                          // ~60ms

        // Peak averages
        let peakLong = ph.reduce(0, +) / Float(ph.count)

        // Deltas (transient detection)
        let delta = abs(level - (h.count >= 2 ? h[h.count - 2] : level))
        let peakDelta = abs(peak - (ph.count >= 2 ? ph[ph.count - 2] : peak))

        // Derive 8 frequency bands — scaled to use dynamic range properly
        var bands: [Float] = Array(repeating: 0, count: 8)
        bands[0] = min(1, peakLong * 0.6 + (peak - level) * 0.8)                        // Sub-bass
        bands[1] = min(1, longAvg * 0.7 + delta * 2.0)                                  // Bass
        bands[2] = min(1, medAvg * 0.6 + delta * 1.0)                                   // Low-mid
        bands[3] = min(1, shortAvg * 0.7 + (shortAvg - longAvg) * 1.5)                  // Mid
        bands[4] = min(1, (shortAvg - medAvg) * 3.0 + delta * 1.5)                      // Upper-mid
        bands[5] = min(1, (veryShort - shortAvg) * 4.0 + peakDelta * 2.0)               // Presence
        bands[6] = min(1, delta * 4.0 + peakDelta * 2.0)                                // Brilliance
        bands[7] = min(1, peakDelta * 5.0 + (veryShort - medAvg) * 3.0)                 // Air

        // Smooth bands — fast attack, slow release for fluid motion
        for i in 0..<8 {
            let target = max(0, bands[i])
            let speed: Float = target > previousBands[i] ? 0.35 : 0.05
            previousBands[i] += (target - previousBands[i]) * speed
        }
        frequencyBands = previousBands

        // Derived levels — mostly from sustained, with transient accent
        midLevel = (previousBands[2] + previousBands[3] + previousBands[4]) / 3.0
        trebleLevel = (previousBands[5] + previousBands[6] + previousBands[7]) / 3.0
        spectralFlux = min(1, (delta + peakDelta) * 2.5)
    }

    private func stopTimers() {
        progressTimer?.invalidate()
        progressTimer = nil
        meterTimer?.invalidate()
        meterTimer = nil
        if !isPlaying {
            audioLevel = 0
            bassLevel = 0
            midLevel = 0
            trebleLevel = 0
            spectralFlux = 0
            isBeat = false
            frequencyBands = Array(repeating: 0, count: 8)
            previousBands = Array(repeating: 0, count: 8)
            levelHistory.removeAll()
            peakHistory.removeAll()
            previousLevel = 0
        }
    }

    // MARK: - Now Playing Info

    private func updateNowPlayingInfo() {
        guard let track = currentTrack else { return }

        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = track.title
        info[MPMediaItemPropertyArtist] = track.artist
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        if let data = artworkCache[track.fileName], let image = UIImage(data: data) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - Formatting

    func formatTime(_ time: TimeInterval) -> String {
        guard !time.isNaN, !time.isInfinite else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayerManager: @preconcurrency AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // If crossfade player finished (old track fading out), just clean up
        if player === crossfadePlayer {
            crossfadePlayer = nil
            return
        }

        // Sleep timer: end of track
        if sleepTimerEndOfTrack {
            cancelSleepTimer()
            isPlaying = false
            stopTimers()
            return
        }

        switch repeatMode {
        case .one:
            playTrack(at: currentTrackIndex)
        case .all:
            nextTrack()
        case .off:
            if isShuffleOn {
                if shufflePosition < shuffledIndices.count - 1 {
                    nextTrack()
                } else {
                    isPlaying = false
                    stopTimers()
                }
            } else if currentTrackIndex < tracks.count - 1 {
                nextTrack()
            } else {
                isPlaying = false
                stopTimers()
            }
        }
    }
}
