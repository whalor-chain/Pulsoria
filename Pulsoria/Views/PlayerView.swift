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
