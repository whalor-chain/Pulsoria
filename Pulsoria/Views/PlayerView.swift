import SwiftUI
import AVFoundation
import Combine

struct PlayerView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var genius = GeniusManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isDraggingSlider = false
    @State private var dragValue: TimeInterval = 0
    @State private var showQueue = false
    @State private var showAddToPlaylist = false
    @State private var selectedArtist: ArtistSelection?
    @State private var showLyrics = false
    @State private var showSleepTimer = false
    @State private var showShareSheet = false

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header: chevron.down + source
                    ZStack {
                        VStack(spacing: 4) {
                            if !player.playingSource.isEmpty {
                                Text(player.playingSource)
                                    .font(.custom(Loc.fontMedium, size: 15))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            listeningOnDevice
                        }

                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(width: 44, height: 44)
                                    .glassEffect(.regular.interactive(), in: .circle)
                            }

                            Spacer()

                            TrackActionsMenu(
                        showAddToPlaylist: $showAddToPlaylist,
                        onShare: {
                            showShareSheet = true
                        }
                    )
                        }
                    }
                    .padding(.top, 4)

                    albumArt
                    trackInfo
                    progressSection
                    controlButtons

                    // Lyrics
                    lyricsSection

                    // Artist card(s)
                    if let track = player.currentTrack {
                        ArtistCard(track: track) { name in
                            selectedArtist = ArtistSelection(name: name)
                        }
                    }

                    // Logo
                    Image("FullLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 32)
                        .opacity(0.3)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                }
                .padding()
            }
        }
        .task {
            if let track = player.currentTrack {
                await player.loadArtwork(for: track)
            }
        }
        .onChange(of: player.currentTrack?.id) { _, _ in
            showLyrics = false
            Task {
                if let track = player.currentTrack {
                    await player.loadArtwork(for: track)
                }
            }
        }
        .sheet(isPresented: $showQueue) {
            QueueSheet()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAddToPlaylist) {
            AddToPlaylistSheet(track: player.currentTrack)
        }
        .sheet(item: $selectedArtist) { selection in
            NavigationStack {
                if let track = player.currentTrack {
                    ArtistPageView(artistName: selection.name, initialTrack: track)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    selectedArtist = nil
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let track = player.currentTrack {
                let artwork = player.artworkCache[track.fileName].flatMap { UIImage(data: $0) }
                SharePreviewSheet(track: track, artwork: artwork)
            }
        }
        .sheet(isPresented: $showSleepTimer) {
            SleepTimerSheet()
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showLyrics) {
            if let key = lyricsKey {
                if let syncedLines = genius.cachedSyncedLyrics[key] {
                    SyncedLyricsSheet(
                        lines: syncedLines,
                        trackTitle: player.currentTrack?.title ?? "",
                        artistName: player.currentTrack?.artist ?? "",
                        player: player
                    )
                } else if let lyrics = genius.cachedLyrics[key] {
                    LyricsSheet(lyrics: lyrics, trackTitle: player.currentTrack?.title ?? "", artistName: player.currentTrack?.artist ?? "")
                }
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                theme.currentTheme.accent.opacity(0.35),
                theme.currentTheme.secondary.opacity(0.15),
                Color(.systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Album Art

    @ViewBuilder
    private var listeningOnDevice: some View {
        let output = currentAudioOutput()
        HStack(spacing: 6) {
            Image(systemName: output.icon)
                .font(.system(size: 12, weight: .medium))
            Text(output.name)
                .font(.custom(Loc.fontMedium, size: 13))
        }
        .foregroundStyle(.secondary)
    }

    private func currentAudioOutput() -> (name: String, icon: String) {
        let session = AVAudioSession.sharedInstance()
        if let output = session.currentRoute.outputs.first {
            let nameLower = output.portName.lowercased()
            switch output.portType {
            case .bluetoothA2DP, .bluetoothLE, .bluetoothHFP:
                // AirPods Max
                if nameLower.contains("airpods max") {
                    return (output.portName, "airpodsmax")
                }
                // AirPods Pro
                if nameLower.contains("airpods pro") {
                    return (output.portName, "airpodspro")
                }
                // AirPods
                if nameLower.contains("airpods") {
                    return (output.portName, "airpods.gen3")
                }
                // Beats
                if nameLower.contains("beats") {
                    return (output.portName, "beats.headphones")
                }
                // HomePod
                if nameLower.contains("homepod") {
                    return (output.portName, "homepodmini")
                }
                // Speakers (JBL, Marshall, Sony, Bose, etc.)
                if nameLower.contains("jbl") || nameLower.contains("marshall") ||
                   nameLower.contains("sony") || nameLower.contains("bose") ||
                   nameLower.contains("speaker") || nameLower.contains("soundbar") ||
                   nameLower.contains("flip") || nameLower.contains("charge") ||
                   nameLower.contains("boom") || nameLower.contains("harman") {
                    return (output.portName, "hifispeaker")
                }
                // Default Bluetooth — likely a speaker
                return (output.portName, "hifispeaker")
            case .headphones:
                return (output.portName, "headphones")
            case .airPlay:
                if nameLower.contains("apple tv") || nameLower.contains("appletv") {
                    return (output.portName, "appletv")
                }
                if nameLower.contains("homepod") {
                    return (output.portName, "homepodmini")
                }
                return (output.portName, "airplayvideo")
            case .builtInSpeaker:
                return (UIDevice.current.name, "iphone")
            case .carAudio:
                return (output.portName, "car.fill")
            case .usbAudio:
                return (output.portName, "cable.connector")
            case .lineOut:
                return (output.portName, "cable.connector.horizontal")
            case .HDMI:
                return (output.portName, "tv")
            default:
                return (output.portName, "speaker.wave.2.fill")
            }
        }
        return (UIDevice.current.name, "iphone")
    }

    private var albumArt: some View {
        Group {
            if let fileName = player.currentTrack?.fileName,
               let data = player.artworkCache[fileName],
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 280, height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
            } else {
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.currentTheme.accent.opacity(0.5),
                                theme.currentTheme.secondary.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 280, height: 280)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 80, weight: .ultraLight))
                            .foregroundStyle(.white.opacity(0.7))
                    }
            }
        }
        .shadow(color: theme.currentTheme.accent.opacity(0.25), radius: 24, y: 12)
        .scaleEffect(player.isPlaying ? 1.0 : 0.92)
        .animation(.easeInOut(duration: 0.5), value: player.isPlaying)
    }

    // MARK: - Track Info

    private var trackInfo: some View {
        VStack(spacing: 6) {
            Text(player.currentTrack?.title ?? Loc.noTrackSelected)
                .font(.custom(Loc.fontBold, size: 22))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(player.currentTrack?.artist ?? Loc.unknownArtist)
                .font(.custom(Loc.fontMedium, size: 15))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal)
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: 4) {
            if theme.sliderIcon == .defaultCircle {
                Slider(
                    value: Binding(
                        get: { isDraggingSlider ? dragValue : player.currentTime },
                        set: { dragValue = $0 }
                    ),
                    in: 0...max(player.duration, 0.01)
                ) { editing in
                    if editing {
                        isDraggingSlider = true
                    } else {
                        player.seek(to: dragValue)
                        isDraggingSlider = false
                    }
                }
                .tint(theme.currentTheme.accent)
            } else {
                CustomSlider(
                    value: Binding(
                        get: { isDraggingSlider ? dragValue : player.currentTime },
                        set: { dragValue = $0 }
                    ),
                    range: 0...max(player.duration, 0.01),
                    sliderIcon: theme.sliderIcon,
                    accentColor: theme.currentTheme.accent,
                    onDragStarted: {
                        isDraggingSlider = true
                    },
                    onDragEnded: {
                        player.seek(to: dragValue)
                        isDraggingSlider = false
                    }
                )
                .frame(height: 36)
            }

            HStack {
                Text(player.formatTime(isDraggingSlider ? dragValue : player.currentTime))
                    .font(.custom(Loc.fontMedium, size: 12).monospacedDigit())
                    .foregroundStyle(.secondary)

                Spacer()

                Text(player.formatTime(max(player.duration - (isDraggingSlider ? dragValue : player.currentTime), 0)))
                    .font(.custom(Loc.fontMedium, size: 12).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Controls

    private var controlButtons: some View {
        VStack(spacing: 24) {
            GlassEffectContainer {
                HStack(spacing: 32) {
                    Button {
                        player.previousTrack()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                            .frame(width: 52, height: 52)
                    }
                    .buttonStyle(.glass)

                    Button {
                        player.togglePlayPause()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 32))
                            .frame(width: 72, height: 72)
                    }
                    .buttonStyle(.glassProminent)
                    .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: player.isPlaying)

                    Button {
                        player.nextTrack()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                            .frame(width: 52, height: 52)
                    }
                    .buttonStyle(.glass)
                }
            }

            HStack(spacing: 20) {
                Button {
                    showSleepTimer = true
                } label: {
                    Image(systemName: player.isSleepTimerActive ? "moon.fill" : "moon.zzz")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(player.isSleepTimerActive ? theme.currentTheme.accent : Color.secondary)
                        .frame(width: 44, height: 44)
                }

                Button {
                    player.toggleShuffle()
                } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(player.isShuffleOn ? theme.currentTheme.accent : Color.secondary)
                        .frame(width: 44, height: 44)
                }

                Button {
                    player.toggleRepeatMode()
                } label: {
                    Image(systemName: player.repeatMode.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(player.repeatMode == .off ? Color.secondary : theme.currentTheme.accent)
                        .frame(width: 44, height: 44)
                }

                Button {
                    showQueue = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(!player.queue.isEmpty ? theme.currentTheme.accent : Color.secondary)
                        .frame(width: 44, height: 44)
                }

                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 44, height: 44)
                }
            }

            // Favorite button
            Button {
                withAnimation(.bouncy(duration: 0.4)) {
                    player.toggleFavoriteForCurrentTrack()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: player.currentTrack?.isFavorite == true ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .medium))
                        .symbolEffect(.bounce, value: player.currentTrack?.isFavorite)

                    Text(player.currentTrack?.isFavorite == true ? Loc.inFavorites : Loc.addToFavorites)
                        .font(.custom(Loc.fontMedium, size: 14))
                }
                .foregroundStyle(player.currentTrack?.isFavorite == true ? .red : Color.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .scaleEffect(player.currentTrack?.isFavorite == true ? 1.05 : 1.0)
            }
            .sensoryFeedback(.impact, trigger: player.currentTrack?.isFavorite)
        }
    }

    // MARK: - Lyrics

    private var lyricsKey: String? {
        guard let track = player.currentTrack else { return nil }
        return "\(track.title) - \(track.artist)".lowercased()
    }

    private var hasSyncedLyrics: Bool {
        guard let key = lyricsKey else { return false }
        return genius.cachedSyncedLyrics[key] != nil
    }

    @ViewBuilder
    private var lyricsSection: some View {
        if let key = lyricsKey, let syncedLines = genius.cachedSyncedLyrics[key] {
            // Synced lyrics preview (offset +0.3s to compensate display lag)
            let currentTime = (isDraggingSlider ? dragValue : player.currentTime) + 0.3
            let currentIndex = syncedLines.lastIndex(where: { $0.time <= currentTime }) ?? 0
            // When near the end, clamp start so we always show 4 lines
            let startIndex = min(currentIndex, max(0, syncedLines.count - 4))
            let endIndex = min(startIndex + 4, syncedLines.count)
            let rawPreview = Array(syncedLines[startIndex..<endIndex])
            let currentOffset = currentIndex - startIndex
            // Always show 4 lines to prevent block resizing
            let previewLines: [(text: String, isReal: Bool, isCurrent: Bool)] = (0..<4).map { i in
                if i < rawPreview.count {
                    return (rawPreview[i].text, true, i == currentOffset)
                } else {
                    return (" ", false, false)
                }
            }

            Button {
                showLyrics = true
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Image(systemName: "text.quote")
                            .font(.system(size: 13, weight: .bold))
                        Text(Loc.lyrics)
                            .font(.custom(Loc.fontBold, size: 13))
                            .tracking(0.5)
                        Spacer()
                        HStack(spacing: 4) {
                            Circle().fill(.green).frame(width: 6, height: 6)
                            Text("SYNCED")
                                .font(.custom(Loc.fontBold, size: 10))
                                .tracking(0.5)
                        }
                        .foregroundStyle(.green.opacity(0.7))
                    }
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(0..<4, id: \.self) { idx in
                            Text(previewLines[idx].text)
                                .font(.custom(Loc.fontBold, size: previewLines[idx].isCurrent ? 20 : 16))
                                .foregroundStyle(.white.opacity(previewLines[idx].isReal ? (previewLines[idx].isCurrent ? 0.9 : 0.35) : 0))
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 18)
                    .animation(.easeInOut(duration: 0.3), value: currentIndex)

                    HStack {
                        Text("LRCLIB")
                            .font(.custom(Loc.fontMedium, size: 11))
                            .foregroundStyle(.white.opacity(0.3))
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.currentTheme.accent.opacity(0.55),
                                    theme.currentTheme.secondary.opacity(0.4),
                                    theme.currentTheme.accent.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)
        } else if let key = lyricsKey, let lyrics = genius.cachedLyrics[key] {
            // Fallback: plain lyrics from Genius
            let lines = lyrics.components(separatedBy: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let preview = Array(lines.prefix(4))

            Button {
                showLyrics = true
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Image(systemName: "text.quote")
                            .font(.system(size: 13, weight: .bold))
                        Text(Loc.lyrics)
                            .font(.custom(Loc.fontBold, size: 13))
                            .tracking(0.5)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(preview.enumerated()), id: \.offset) { _, line in
                            if line.hasPrefix("[") && line.hasSuffix("]") {
                                Text(line)
                                    .font(.custom(Loc.fontBold, size: 13))
                                    .foregroundStyle(.white.opacity(0.35))
                            } else {
                                Text(line)
                                    .font(.custom(Loc.fontBold, size: 20))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.horizontal, 18)

                    HStack {
                        Text("Genius")
                            .font(.custom(Loc.fontMedium, size: 11))
                            .foregroundStyle(.white.opacity(0.3))
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.currentTheme.accent.opacity(0.55),
                                    theme.currentTheme.secondary.opacity(0.4),
                                    theme.currentTheme.accent.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)
        } else if genius.isLoadingLyrics {
            LyricsLoadingView()
        }
    }
}

// MARK: - Artist Selection

struct ArtistSelection: Identifiable {
    let id = UUID()
    let name: String
}

// MARK: - Artist Card

struct ArtistCard: View {
    let track: Track
    var onArtistTap: (String) -> Void
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var genius = GeniusManager.shared

    private var artists: [String] {
        track.artist
            .components(separatedBy: CharacterSet(charactersIn: ",&"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func trackCount(for artist: String) -> Int {
        let name = artist.lowercased()
        return player.tracks.filter {
            $0.artist.lowercased().contains(name)
        }.count
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(artists, id: \.self) { artist in
                Button {
                    onArtistTap(artist)
                } label: {
                    artistRow(name: artist, count: trackCount(for: artist))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func artistRow(name: String, count: Int) -> some View {
        HStack(spacing: 14) {
            // Avatar — Genius photo or track artwork
            ZStack {
                if let url = genius.cachedArtistImages[name.lowercased()] {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        localAvatar
                    }
                } else {
                    localAvatar
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [theme.currentTheme.accent.opacity(0.6), theme.currentTheme.secondary.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(Loc.artist)
                    .font(.custom(Loc.fontMedium, size: 10))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1)

                Text(name)
                    .font(.custom(Loc.fontBold, size: 18))
                    .lineLimit(1)

                if let bio = genius.cachedArtistBios[name.lowercased()], !bio.isEmpty {
                    Text(bio)
                        .font(.custom(Loc.fontMedium, size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("\(count) \(count == 1 ? Loc.trackSingular : Loc.trackCount) \(Loc.inLibrary)")
                        .font(.custom(Loc.fontMedium, size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .contentShape(Rectangle())
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    @ViewBuilder
    private var localAvatar: some View {
        if let data = player.artworkCache[track.fileName],
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [theme.currentTheme.accent.opacity(0.5), theme.currentTheme.secondary.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Image(systemName: "music.mic")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.8))
                }
        }
    }
}

// MARK: - Queue Sheet

// MARK: - Lyrics Sheet

struct LyricsSheet: View {
    let lyrics: String
    let trackTitle: String
    let artistName: String
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isDragging = false
    @State private var dragValue: TimeInterval = 0

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        theme.currentTheme.accent.opacity(0.6),
                        theme.currentTheme.secondary.opacity(0.4),
                        theme.currentTheme.accent.opacity(0.25),
                        Color(.systemBackground).opacity(0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            lyricsContent

                            HStack {
                                Text("Genius")
                                    .font(.custom(Loc.fontMedium, size: 12))
                                    .foregroundStyle(.white.opacity(0.3))
                                Spacer()
                            }
                            .padding(.top, 24)
                            .padding(.bottom, 40)
                        }
                        .padding(.horizontal, 24)
                    }

                    // Mini player controls
                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            if let data = player.artworkCache[player.currentTrack?.fileName ?? ""],
                               let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.white.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        Image(systemName: "music.note")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(trackTitle)
                                    .font(.custom(Loc.fontBold, size: 14))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(artistName)
                                    .font(.custom(Loc.fontMedium, size: 12))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .lineLimit(1)
                            }

                            Spacer()

                            Button {
                                player.togglePlayPause()
                            } label: {
                                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                            }
                            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: player.isPlaying)
                        }

                        Slider(
                            value: Binding(
                                get: { isDragging ? dragValue : player.currentTime },
                                set: { dragValue = $0 }
                            ),
                            in: 0...max(player.duration, 0.01)
                        ) { editing in
                            if editing {
                                isDragging = true
                            } else {
                                player.seek(to: dragValue)
                                isDragging = false
                            }
                        }
                        .tint(.white)

                        HStack {
                            Text(player.formatTime(isDragging ? dragValue : player.currentTime))
                                .font(.custom(Loc.fontMedium, size: 11).monospacedDigit())
                                .foregroundStyle(.white.opacity(0.5))
                            Spacer()
                            Text(player.formatTime(max(player.duration - (isDragging ? dragValue : player.currentTime), 0)))
                                .font(.custom(Loc.fontMedium, size: 11).monospacedDigit())
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
                    .background(Color.black.opacity(0.4))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var lyricsContent: some View {
        let lines = lyrics.components(separatedBy: "\n")

        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    Spacer()
                        .frame(height: 14)
                } else if line.hasPrefix("[") && line.hasSuffix("]") {
                    Text(line)
                        .font(.custom(Loc.fontBold, size: 14))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.top, 8)
                } else {
                    Text(line)
                        .font(.custom(Loc.fontBold, size: 24))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineSpacing(4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Lyrics Loading Animation

struct LyricsLoadingView: View {
    @ObservedObject var theme = ThemeManager.shared
    @State private var pulse = false

    private let lineWidths: [CGFloat] = [0.9, 0.7, 0.85, 0.6]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "text.quote")
                    .font(.system(size: 13, weight: .bold))
                Text(Loc.lyrics)
                    .font(.custom(Loc.fontBold, size: 13))
                    .tracking(0.5)
                Spacer()
                ProgressView()
                    .tint(.white.opacity(0.4))
                    .scaleEffect(0.8)
            }
            .foregroundStyle(.white.opacity(0.5))
            .textCase(.uppercase)
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(pulse ? 0.15 : 0.06))
                        .frame(height: i == 0 ? 22 : 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .scaleEffect(x: lineWidths[i], y: 1, anchor: .leading)
                        .animation(
                            .easeInOut(duration: 1.0)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: pulse
                        )
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            theme.currentTheme.accent.opacity(0.35),
                            theme.currentTheme.secondary.opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onAppear { pulse = true }
    }
}

// MARK: - Synced Lyrics Sheet

struct SyncedLyricsSheet: View {
    let lines: [SyncedLyricLine]
    let trackTitle: String
    let artistName: String
    @ObservedObject var player: AudioPlayerManager
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var currentLineIndex: Int = 0
    @State private var isDragging = false
    @State private var dragValue: TimeInterval = 0

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        theme.currentTheme.accent.opacity(0.6),
                        theme.currentTheme.secondary.opacity(0.4),
                        theme.currentTheme.accent.opacity(0.25),
                        Color(.systemBackground).opacity(0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 0) {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                                        Button {
                                            player.seek(to: line.time)
                                        } label: {
                                            Text(line.text)
                                                .font(.custom(Loc.fontBold, size: 24))
                                                .foregroundStyle(
                                                    index == currentLineIndex
                                                        ? .white
                                                        : index < currentLineIndex
                                                            ? .white.opacity(0.2)
                                                            : .white.opacity(0.4)
                                                )
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .lineSpacing(4)
                                        }
                                        .buttonStyle(.plain)
                                        .id(index)

                                        if index < lines.count - 1 {
                                            let gap = lines[index + 1].time - line.time
                                            if gap > 3.0 {
                                                Spacer().frame(height: 16)
                                            }
                                        }
                                    }
                                }

                                HStack {
                                    HStack(spacing: 4) {
                                        Circle().fill(.green).frame(width: 6, height: 6)
                                        Text("SYNCED")
                                            .font(.custom(Loc.fontBold, size: 10))
                                            .tracking(0.5)
                                    }
                                    .foregroundStyle(.green.opacity(0.5))

                                    Text(" · LRCLIB")
                                        .font(.custom(Loc.fontMedium, size: 12))
                                        .foregroundStyle(.white.opacity(0.3))
                                    Spacer()
                                }
                                .padding(.top, 24)
                                .padding(.bottom, 40)
                            }
                            .padding(.horizontal, 24)
                        }
                        .onChange(of: currentLineIndex) { _, newIndex in
                            withAnimation(.easeInOut(duration: 0.4)) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }

                    // Mini player controls
                    lyricsPlayerBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .onReceive(Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()) { _ in
            updateCurrentLine()
        }
    }

    private var lyricsPlayerBar: some View {
        VStack(spacing: 10) {
            // Track info
            HStack(spacing: 12) {
                if let data = player.artworkCache[player.currentTrack?.fileName ?? ""],
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.1))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(trackTitle)
                        .font(.custom(Loc.fontBold, size: 14))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(artistName)
                        .font(.custom(Loc.fontMedium, size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                }
                .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: player.isPlaying)
            }

            // Slider + time
            Slider(
                value: Binding(
                    get: { isDragging ? dragValue : player.currentTime },
                    set: { dragValue = $0 }
                ),
                in: 0...max(player.duration, 0.01)
            ) { editing in
                if editing {
                    isDragging = true
                } else {
                    player.seek(to: dragValue)
                    isDragging = false
                }
            }
            .tint(.white)

            HStack {
                Text(player.formatTime(isDragging ? dragValue : player.currentTime))
                    .font(.custom(Loc.fontMedium, size: 11).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text(player.formatTime(max(player.duration - (isDragging ? dragValue : player.currentTime), 0)))
                    .font(.custom(Loc.fontMedium, size: 11).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(Color.black.opacity(0.4))
    }

    private func updateCurrentLine() {
        let time = player.currentTime + 0.3
        var newIndex = 0
        for (i, line) in lines.enumerated() {
            if line.time <= time {
                newIndex = i
            } else {
                break
            }
        }
        if newIndex != currentLineIndex {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentLineIndex = newIndex
            }
        }
    }
}

// MARK: - Sleep Timer Sheet

struct SleepTimerSheet: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    private let options: [(label: String, minutes: Int)] = [
        ("5 \(Loc.minutesSuffix)", 5),
        ("10 \(Loc.minutesSuffix)", 10),
        ("15 \(Loc.minutesSuffix)", 15),
        ("30 \(Loc.minutesSuffix)", 30),
        ("45 \(Loc.minutesSuffix)", 45),
        ("60 \(Loc.minutesSuffix)", 60)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if player.isSleepTimerActive {
                    // Active timer display
                    VStack(spacing: 12) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(theme.currentTheme.accent)

                        if player.sleepTimerEndOfTrack {
                            Text(Loc.endOfTrack)
                                .font(.custom(Loc.fontBold, size: 22))
                        } else {
                            Text(formatRemaining(player.sleepTimerRemaining))
                                .font(.custom(Loc.fontBold, size: 32).monospacedDigit())
                        }

                        Text(Loc.timerActive)
                            .font(.custom(Loc.fontMedium, size: 15))
                            .foregroundStyle(.secondary)

                        Button {
                            player.cancelSleepTimer()
                            dismiss()
                        } label: {
                            Text(Loc.cancelTimer)
                                .font(.custom(Loc.fontBold, size: 16))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.glass)
                        .padding(.top, 8)
                    }
                    .padding(.top, 24)
                } else {
                    // Timer options
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(options, id: \.minutes) { option in
                            Button {
                                player.startSleepTimer(minutes: option.minutes)
                                dismiss()
                            } label: {
                                Text(option.label)
                                    .font(.custom(Loc.fontBold, size: 18))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                            }
                            .buttonStyle(.glass)
                            .sensoryFeedback(.impact(flexibility: .soft), trigger: player.isSleepTimerActive)
                        }

                        Button {
                            player.startSleepTimerEndOfTrack()
                            dismiss()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 14))
                                Text(Loc.endOfTrack)
                                    .font(.custom(Loc.fontBold, size: 16))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                        }
                        .buttonStyle(.glass)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                }

                Spacer()
            }
            .navigationTitle(Loc.sleepTimer)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Loc.done) { dismiss() }
                        .font(.custom(Loc.fontMedium, size: 15))
                }
            }
        }
    }

    private func formatRemaining(_ time: TimeInterval) -> String {
        let m = Int(time) / 60
        let s = Int(time) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Queue Sheet

struct QueueSheet: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if player.queue.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "list.bullet")
                            .font(.system(size: 60, weight: .thin))
                            .foregroundStyle(.secondary)
                        Text(Loc.emptyQueue)
                            .font(.custom(Loc.fontBold, size: 22))
                        Text(Loc.emptyQueueHint)
                            .font(.custom(Loc.fontMedium, size: 15))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // Now playing
                        if let current = player.currentTrack {
                            Section {
                                queueRow(track: current, isCurrent: true)
                            }
                        }

                        // Queue
                        Section(Loc.next) {
                            ForEach(Array(player.queue.enumerated()), id: \.element.id) { index, track in
                                queueRow(track: track, isCurrent: false)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                player.removeFromQueue(at: index)
                                            }
                                        } label: {
                                            Label(Loc.delete, systemImage: "trash")
                                        }
                                    }
                            }
                            .onMove { from, to in
                                player.queue.move(fromOffsets: from, toOffset: to)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(Loc.queue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Loc.done) { dismiss() }
                        .font(.custom(Loc.fontMedium, size: 15))
                }
            }
        }
    }

    private func queueRow(track: Track, isCurrent: Bool) -> some View {
        HStack(spacing: 12) {
            if let data = player.artworkCache[track.fileName],
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [theme.currentTheme.accent.opacity(0.4), theme.currentTheme.secondary.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.custom(Loc.fontMedium, size: 15))
                    .foregroundStyle(isCurrent ? theme.currentTheme.accent : .primary)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.custom(Loc.fontMedium, size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isCurrent {
                Image(systemName: "waveform")
                    .font(.caption)
                    .foregroundStyle(theme.currentTheme.accent)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Custom Slider with Icon Thumb

struct CustomSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let sliderIcon: SliderIcon
    let accentColor: Color
    var onDragStarted: (() -> Void)? = nil
    var onDragEnded: (() -> Void)? = nil
    @State private var isDragging = false

    private var progress: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return (value - range.lowerBound) / span
    }

    var body: some View {
        GeometryReader { geo in
            let trackHeight: CGFloat = 6
            let thumbSize: CGFloat = sliderIcon == .defaultCircle ? 20 : 32
            let usableWidth = geo.size.width - thumbSize
            let thumbX = thumbSize / 2 + usableWidth * progress

            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(accentColor.opacity(0.2))
                    .frame(height: trackHeight)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, thumbSize / 2 - trackHeight / 2)

                // Filled track
                Capsule()
                    .fill(accentColor)
                    .frame(width: max(0, thumbX), height: trackHeight)
                    .padding(.leading, 0)

                // Thumb icon
                Group {
                    if sliderIcon == .defaultCircle {
                        Circle()
                            .fill(accentColor)
                            .frame(width: thumbSize, height: thumbSize)
                            .shadow(color: accentColor.opacity(0.4), radius: 4, y: 2)
                    } else {
                        Image(systemName: ThemeManager.shared.activeSliderSymbol)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(accentColor)
                            .frame(width: thumbSize, height: thumbSize)
                            .scaleEffect(isDragging ? 1.25 : 1.0)
                            .animation(.spring(response: 0.3), value: isDragging)
                    }
                }
                .position(x: thumbX, y: geo.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            onDragStarted?()
                        }
                        let fraction = (gesture.location.x - thumbSize / 2) / usableWidth
                        let clamped = min(max(fraction, 0), 1)
                        let span = range.upperBound - range.lowerBound
                        value = range.lowerBound + span * clamped
                    }
                    .onEnded { _ in
                        isDragging = false
                        onDragEnded?()
                    }
            )
        }
    }
}

// MARK: - Track Actions Menu (isolated from player observation)

struct TrackActionsMenu: View {
    @Binding var showAddToPlaylist: Bool
    var onShare: () -> Void = {}

    var body: some View {
        Menu {
            Section {
                Button {
                    AudioPlayerManager.shared.addCurrentTrackToQueue()
                } label: {
                    Label(Loc.addToQueue, systemImage: "text.line.last.and.arrowtriangle.forward")
                        .imageScale(.large)
                }

                Button {
                    showAddToPlaylist = true
                } label: {
                    Label(Loc.addToPlaylist, systemImage: "text.badge.plus")
                        .imageScale(.large)
                }

                Button {
                    onShare()
                } label: {
                    Label(Loc.share, systemImage: "square.and.arrow.up")
                        .imageScale(.large)
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44)
                .glassEffect(.regular, in: .circle)
        }
    }
}

// MARK: - Share Preview Sheet

struct SharePreviewSheet: View {
    let track: Track
    let artwork: UIImage?
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var saved = false
    @State private var copied = false
    @State private var showActivitySheet = false
    @State private var selectedPalette: SharePalette = .sunset
    @State private var renderedImage: UIImage?

    private var currentImage: UIImage {
        renderedImage ?? ShareCardRenderer.render(track: track, artwork: artwork, palette: selectedPalette)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Preview
                Image(uiImage: currentImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
                    .animation(.easeInOut(duration: 0.35), value: selectedPalette)
                    .id(selectedPalette)

                // Palette picker
                HStack(spacing: 12) {
                    ForEach(SharePalette.allCases) { palette in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedPalette = palette
                                }
                                renderedImage = ShareCardRenderer.render(track: track, artwork: artwork, palette: palette)
                            } label: {
                                let colors = palette.swiftUIColors
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [colors.0, colors.1],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        if selectedPalette == palette {
                                            Circle()
                                                .strokeBorder(.white, lineWidth: 3)
                                        }
                                    }
                            }
                            .sensoryFeedback(.selection, trigger: selectedPalette)
                        }
                    }

                // Action buttons
                HStack(spacing: 16) {
                    Button {
                        UIImageWriteToSavedPhotosAlbum(currentImage, nil, nil, nil)
                        withAnimation(.spring(duration: 0.3)) { saved = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { saved = false }
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: saved ? "checkmark.circle.fill" : "photo.on.rectangle.angled")
                                .font(.system(size: 22))
                                .symbolEffect(.bounce, value: saved)
                            Text(saved ? Loc.done : Loc.save)
                                .font(.custom(Loc.fontMedium, size: 12))
                        }
                        .foregroundStyle(saved ? .green : theme.currentTheme.accent)
                        .frame(width: 80, height: 70)
                    }
                    .buttonStyle(.glass)
                    .sensoryFeedback(.success, trigger: saved)

                    Button {
                        showActivitySheet = true
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "arrow.up.message")
                                .font(.system(size: 22))
                            Text(Loc.share)
                                .font(.custom(Loc.fontMedium, size: 12))
                        }
                        .foregroundStyle(theme.currentTheme.accent)
                        .frame(width: 80, height: 70)
                    }
                    .buttonStyle(.glass)

                    Button {
                        UIPasteboard.general.image = currentImage
                        withAnimation(.spring(duration: 0.3)) { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { copied = false }
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                .font(.system(size: 22))
                                .symbolEffect(.bounce, value: copied)
                            Text(copied ? Loc.done : Loc.copy)
                                .font(.custom(Loc.fontMedium, size: 12))
                        }
                        .foregroundStyle(copied ? .green : theme.currentTheme.accent)
                        .frame(width: 80, height: 70)
                    }
                    .buttonStyle(.glass)
                    .sensoryFeedback(.success, trigger: copied)
                }

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("ShareLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 52)
                        .foregroundStyle(theme.currentTheme.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.currentTheme.accent)
                    }
                }
            }
            .sheet(isPresented: $showActivitySheet) {
                ActivitySheet(items: [currentImage])
            }
            .onAppear {
                renderedImage = ShareCardRenderer.render(track: track, artwork: artwork, palette: selectedPalette)
            }
        }
    }
}

// MARK: - Activity Sheet (UIActivityViewController)

struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Share Palette

enum SharePalette: String, CaseIterable, Identifiable {
    case sunset
    case ocean
    case forest
    case neon
    case lavender
    case ember
    case arctic

    var id: String { rawValue }

    var colors: (top: UIColor, mid: UIColor, bottom: UIColor) {
        switch self {
        case .sunset:   return (UIColor(red: 0.9, green: 0.3, blue: 0.2, alpha: 1), UIColor(red: 0.8, green: 0.5, blue: 0.1, alpha: 1), UIColor(red: 0.15, green: 0.05, blue: 0.1, alpha: 1))
        case .ocean:    return (UIColor(red: 0.0, green: 0.4, blue: 0.7, alpha: 1), UIColor(red: 0.0, green: 0.2, blue: 0.5, alpha: 1), UIColor(red: 0.0, green: 0.05, blue: 0.15, alpha: 1))
        case .forest:   return (UIColor(red: 0.1, green: 0.5, blue: 0.3, alpha: 1), UIColor(red: 0.05, green: 0.3, blue: 0.2, alpha: 1), UIColor(red: 0.02, green: 0.1, blue: 0.08, alpha: 1))
        case .neon:     return (UIColor(red: 0.9, green: 0.0, blue: 0.6, alpha: 1), UIColor(red: 0.3, green: 0.0, blue: 0.8, alpha: 1), UIColor(red: 0.05, green: 0.0, blue: 0.15, alpha: 1))
        case .lavender: return (UIColor(red: 0.6, green: 0.4, blue: 0.8, alpha: 1), UIColor(red: 0.4, green: 0.2, blue: 0.6, alpha: 1), UIColor(red: 0.1, green: 0.05, blue: 0.2, alpha: 1))
        case .ember:    return (UIColor(red: 0.8, green: 0.2, blue: 0.1, alpha: 1), UIColor(red: 0.5, green: 0.1, blue: 0.05, alpha: 1), UIColor(red: 0.1, green: 0.02, blue: 0.02, alpha: 1))
        case .arctic:   return (UIColor(red: 0.7, green: 0.85, blue: 0.95, alpha: 1), UIColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 1), UIColor(red: 0.05, green: 0.1, blue: 0.2, alpha: 1))
        }
    }

    var swiftUIColors: (Color, Color) {
        (Color(colors.top), Color(colors.mid))
    }
}

// MARK: - Share Card Renderer

enum ShareCardRenderer {
    static func render(track: Track, artwork: UIImage?, palette: SharePalette) -> UIImage {
        let width: CGFloat = 1080
        let height: CGFloat = 1920
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))

        return renderer.image { ctx in
            let context = ctx.cgContext

            // Background gradient from palette
            let pal = palette.colors
            let colors = [pal.top.cgColor, pal.mid.cgColor, pal.bottom.cgColor]
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 0.5, 1]
            )!
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: width, y: height),
                options: []
            )

            // Artwork with rounded corners and shadow
            let artSize: CGFloat = 640
            let artX = (width - artSize) / 2
            let artY: CGFloat = 360
            let artRect = CGRect(x: artX, y: artY, width: artSize, height: artSize)

            // Shadow
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: 20), blur: 60, color: UIColor.black.withAlphaComponent(0.5).cgColor)
            let artPath = UIBezierPath(roundedRect: artRect, cornerRadius: 40)
            UIColor.black.setFill()
            artPath.fill()
            context.restoreGState()

            // Artwork image clipped
            context.saveGState()
            artPath.addClip()
            if let artwork {
                artwork.draw(in: artRect)
            } else {
                // Placeholder gradient
                let placeholderColors = [
                    pal.top.withAlphaComponent(0.6).cgColor,
                    pal.mid.withAlphaComponent(0.4).cgColor
                ]
                let placeholderGradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: placeholderColors as CFArray,
                    locations: [0, 1]
                )!
                context.drawLinearGradient(
                    placeholderGradient,
                    start: artRect.origin,
                    end: CGPoint(x: artRect.maxX, y: artRect.maxY),
                    options: []
                )

                // Music note
                let noteFont = UIFont.systemFont(ofSize: 160, weight: .ultraLight)
                let noteStr = NSAttributedString(
                    string: "\u{266B}",
                    attributes: [
                        .font: noteFont,
                        .foregroundColor: UIColor.white.withAlphaComponent(0.5)
                    ]
                )
                let noteSize = noteStr.size()
                noteStr.draw(at: CGPoint(
                    x: artRect.midX - noteSize.width / 2,
                    y: artRect.midY - noteSize.height / 2
                ))
            }
            context.restoreGState()

            // "Now Listening" logo
            if let nowLogo = UIImage(named: "NowListeningLogo") {
                let nowHeight: CGFloat = 160
                let nowWidth = nowLogo.size.width / nowLogo.size.height * nowHeight
                let nowRect = CGRect(
                    x: (width - nowWidth) / 2,
                    y: artY - nowHeight - 30,
                    width: nowWidth,
                    height: nowHeight
                )
                context.saveGState()
                context.setAlpha(0.5)
                nowLogo.draw(in: nowRect)
                context.restoreGState()
            }

            // Track title
            let titleFont = UIFont(name: "Futura-Bold", size: 56) ?? UIFont.boldSystemFont(ofSize: 56)
            let titleParagraph = NSMutableParagraphStyle()
            titleParagraph.alignment = .center
            titleParagraph.lineBreakMode = .byTruncatingTail
            let titleStr = NSAttributedString(
                string: track.title,
                attributes: [
                    .font: titleFont,
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: titleParagraph
                ]
            )
            let titleRect = CGRect(x: 60, y: artY + artSize + 60, width: width - 120, height: 80)
            titleStr.draw(in: titleRect)

            // Artist name
            let artistFont = UIFont(name: "Futura-Medium", size: 38) ?? UIFont.systemFont(ofSize: 38, weight: .medium)
            let artistStr = NSAttributedString(
                string: track.artist,
                attributes: [
                    .font: artistFont,
                    .foregroundColor: UIColor.white.withAlphaComponent(0.7),
                    .paragraphStyle: titleParagraph
                ]
            )
            let artistRect = CGRect(x: 60, y: artY + artSize + 150, width: width - 120, height: 60)
            artistStr.draw(in: artistRect)

            // Decorative line
            let lineY = artY + artSize + 240
            context.setFillColor(UIColor.white.withAlphaComponent(0.15).cgColor)
            context.fill(CGRect(x: width / 2 - 80, y: lineY, width: 160, height: 3))

            // NotLogo below the line
            if let notLogo = UIImage(named: "NotLogo") {
                let notLogoHeight: CGFloat = 80
                let notLogoWidth = notLogo.size.width / notLogo.size.height * notLogoHeight
                let notLogoRect = CGRect(
                    x: (width - notLogoWidth) / 2,
                    y: lineY + 24,
                    width: notLogoWidth,
                    height: notLogoHeight
                )
                context.saveGState()
                context.setAlpha(0.5)
                notLogo.draw(in: notLogoRect)
                context.restoreGState()
            }

            // FullLogo at the bottom
            if let fullLogo = UIImage(named: "FullLogo") {
                let logoHeight: CGFloat = 120
                let logoWidth = fullLogo.size.width / fullLogo.size.height * logoHeight
                let logoRect = CGRect(
                    x: (width - logoWidth) / 2,
                    y: height - 160,
                    width: logoWidth,
                    height: logoHeight
                )
                context.saveGState()
                context.setAlpha(0.4)
                fullLogo.draw(in: logoRect)
                context.restoreGState()
            }
        }
    }
}
