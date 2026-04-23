import SwiftUI
import AVFoundation
import Combine

struct PlayerView: View {
    /// Called when the user wants to close the player (chevron button
    /// or drag-down gesture past threshold). `ContentView` animates
    /// the switch back to mini-player visibility.
    var onDismiss: () -> Void = {}

    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var genius = GeniusManager.shared
    @ObservedObject var palettes = CoverPaletteManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isDraggingSlider = false
    @State private var dragValue: TimeInterval = 0
    @State private var showQueue = false
    @State private var showAddToPlaylist = false
    @State private var selectedArtist: ArtistSelection?
    @State private var showLyrics = false
    @State private var showSleepTimer = false
    @State private var showShareSheet = false

    /// Drag-down-to-dismiss: y-translation while the user is dragging.
    /// Resets to 0 on release (either snap back or triggering dismiss).
    @State private var dismissDrag: CGFloat = 0

    // Brush-wipe transition: on track change we build a snapshot of
    // (old, new) cover images and play a diagonal brush animation over
    // the album art for ~0.85 s.
    @State private var brushSnapshot: CoverBrushSnapshot?
    @State private var previousArtworkFileName: String?

    // Cover carousel: horizontal drag on the album art reveals prev/next
    // track covers in a 3D fan. Release past threshold switches track;
    // otherwise springs back to zero.
    @State private var carouselDragX: CGFloat = 0

    // When the carousel triggers a track change, the swipe itself is
    // already the visual transition — skip the brush overlay for that
    // one change so the two animations don't fight.
    @State private var suppressNextFracture = false

    // Decoded cover caches. Decoding `UIImage(data:)` in `body` on every
    // rebuild burned ~50–150 ms per render and was the main source of
    // scroll/button jank; caching once per file name fixes that.
    @State private var currentCover: UIImage?
    @State private var prevCover: UIImage?
    @State private var nextCover: UIImage?

    /// Cached audio-output name + icon. Re-computed only when iOS fires
    /// `AVAudioSession.routeChangeNotification`, not on every body
    /// rebuild (the old inline call did `AVAudioSession` + `UIDevice`
    /// syscalls 4 × /sec).
    @State private var audioOutput: (name: String, icon: String) = (UIDevice.current.name, "iphone")

    /// Task we spawn to auto-clear `brushSnapshot` after the animation.
    /// Stored so fast successive track switches can cancel the previous
    /// cleanup before it wipes the *new* snapshot by accident.
    @State private var brushCleanupTask: Task<Void, Never>?

    /// Most-recent palette-derived accent / secondary. Updated only
    /// when a new palette actually lands (inside a `withAnimation`
    /// block, so Color interpolation runs). Never reverts to nil or
    /// theme mid-playback — that's what was causing the purple flash
    /// between tracks (palette briefly absent → fell back to theme).
    @State private var displayedAccent: Color?
    @State private var displayedSecondary: Color?

    var body: some View {
        // Drag-down-to-dismiss: scale the whole player down & fade as
        // the user drags. Past threshold on release, `onDismiss` is
        // called; otherwise we snap back.
        let dragClamped = max(0, dismissDrag)
        let dragProgress = min(dragClamped / 300, 1)

        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                backgroundGradient
                    .ignoresSafeArea()
                    .opacity(1.0 - Double(dragProgress) * 0.35)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        albumArt
                        trackInfo
                        progressSection
                        controlButtons
                        lyricsSection

                        if let track = player.currentTrack {
                            ArtistCard(
                                track: track,
                                onArtistTap: { name in
                                    selectedArtist = ArtistSelection(name: name)
                                },
                                tintAccent: activeAccent,
                                tintSecondary: activeSecondary
                            )
                        }

                        Image("FullLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 32)
                            .opacity(0.3)
                            .padding(.top, 8)
                            .padding(.bottom, 20)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        if !player.playingSource.isEmpty {
                            Text(player.playingSource)
                                .font(.custom(Loc.fontMedium, size: 13))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        listeningOnDevice
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    TrackActionsMenu(
                        showAddToPlaylist: $showAddToPlaylist,
                        onShare: { showShareSheet = true },
                        tint: .white
                    )
                }
            }
        }
        .task {
            audioOutput = Self.resolveAudioOutput()
        }
        // Decode the current cover once per track instead of on every
        // `body` invocation. Also triggers `player.loadArtwork` — keeping
        // both in the same task avoids the double Genius fetch we used
        // to fire from a separate `.onChange`.
        .task(id: player.currentTrack?.fileName) {
            if let track = player.currentTrack {
                await player.loadArtwork(for: track)
            }
            await hydrateCurrentCover()
        }
        // Re-read the audio output when iOS tells us the route changed
        // (AirPods connected, speaker switched, etc.). Much cheaper
        // than polling in `body`.
        .onReceive(NotificationCenter.default.publisher(
            for: AVAudioSession.routeChangeNotification
        )) { _ in
            audioOutput = Self.resolveAudioOutput()
        }
        // Same treatment for the neighbouring carousel covers — only
        // decoded when they could actually be revealed, otherwise nil.
        .task(id: prevNeighbor?.fileName) {
            prevCover = await decodeArtwork(fileName: prevNeighbor?.fileName)
        }
        .task(id: nextNeighbor?.fileName) {
            nextCover = await decodeArtwork(fileName: nextNeighbor?.fileName)
        }
        .onChange(of: player.currentTrack?.fileName) { _, _ in
            // Keyed off fileName so it lines up with the other
            // `.task(id:)` on the same key — consistent identity.
            showLyrics = false
            // New track's palette is probably not cached yet; leave
            // `displayedAccent` at the previous value so we don't
            // flash the theme colour between tracks. `palettes.cache`
            // onChange below will swap it in once extraction lands.
            syncDisplayedPalette(animated: true)
        }
        // Fires every time a palette is extracted for any track.
        // When it's *our* track's palette, animate the tint in.
        .onChange(of: palettes.cache) { _, _ in
            syncDisplayedPalette(animated: true)
        }
        // Flipping the cover-gradient toggle on → seed from current
        // palette without animation (the fallback handles the flip
        // itself via the theme-accent default).
        .onChange(of: theme.useCoverGradient) { _, _ in
            syncDisplayedPalette(animated: false)
        }
        .onAppear {
            syncDisplayedPalette(animated: false)
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
                                .accessibilityLabel(Loc.a11yCloseSheet)
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let track = player.currentTrack {
                // Re-use the cached decoded cover instead of decoding
                // the JPEG again for the share sheet.
                SharePreviewSheet(track: track, artwork: currentCover)
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
                        tintAccent: activeAccent,
                        tintSecondary: activeSecondary,
                        player: player
                    )
                } else if let lyrics = genius.cachedLyrics[key] {
                    LyricsSheet(
                        lyrics: lyrics,
                        trackTitle: player.currentTrack?.title ?? "",
                        artistName: player.currentTrack?.artist ?? "",
                        tintAccent: activeAccent,
                        tintSecondary: activeSecondary
                    )
                }
            }
        }
        .offset(y: max(0, dismissDrag))
        .scaleEffect(1.0 - min(dismissDrag, 300) / 1500, anchor: .top)
    }



    // MARK: - Background

    @ViewBuilder
    private var backgroundGradient: some View {
        if theme.useCoverGradient {
            CoverGradientBackground(
                fileName: player.currentTrack?.fileName,
                fallbackPalette: themeFallbackPalette
            )
            .overlay(
                // Tones the gradient so foreground UI stays readable
                // on very bright covers — fades to systemBackground at
                // the bottom where the scroll content sits dense.
                LinearGradient(
                    colors: [
                        Color(.systemBackground).opacity(0.0),
                        Color(.systemBackground).opacity(0.35),
                        Color(.systemBackground).opacity(0.75)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        } else {
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
    }

    /// Accent colour used across the player's interactive controls.
    /// Always reads from `displayedAccent` when cover-gradient is on —
    /// that state is updated (with animation) only once a new palette
    /// actually lands, which means mid-track-switch we keep the
    /// previous accent rather than flashing back to the theme colour.
    private var activeAccent: Color {
        guard theme.useCoverGradient else {
            return theme.currentTheme.accent
        }
        return displayedAccent ?? theme.currentTheme.accent
    }

    /// Secondary tint — same holding behaviour as `activeAccent`.
    private var activeSecondary: Color {
        guard theme.useCoverGradient else {
            return theme.currentTheme.secondary
        }
        return displayedSecondary ?? theme.currentTheme.secondary
    }

    /// Mirrors the current track's extracted palette into the
    /// displayed-* state vars. No-op when the palette isn't cached
    /// yet for the current track — we leave the previous value in
    /// place, which is the whole point of having this indirection.
    private func syncDisplayedPalette(animated: Bool) {
        guard theme.useCoverGradient,
              let fn = player.currentTrack?.fileName,
              let palette = palettes.palette(for: fn) else { return }
        let update = {
            displayedAccent = palette.accentColor
            displayedSecondary = palette.secondaryColor
        }
        if animated {
            withAnimation(.easeInOut(duration: 0.45)) { update() }
        } else {
            update()
        }
    }

    /// Palette derived from the current theme's accent + secondary —
    /// used when the cover hasn't been decoded yet so the gradient
    /// still reads as coloured rather than flat black.
    private var themeFallbackPalette: CoverPalette {
        let a = uiColorRGB(UIColor(theme.currentTheme.accent))
        let b = uiColorRGB(UIColor(theme.currentTheme.secondary))
        return CoverPalette(quadrants: [a, b.mixed(with: a, t: 0.3), a.mixed(with: .black, t: 0.35), b])
    }

    private func uiColorRGB(_ color: UIColor) -> RGB {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &alpha)
        return RGB(r: Double(r), g: Double(g), b: Double(b))
    }

    // MARK: - Album Art

    private var listeningOnDevice: some View {
        HStack(spacing: 6) {
            Image(systemName: audioOutput.icon)
                .font(.system(size: 12, weight: .medium))
            Text(audioOutput.name)
                .font(.custom(Loc.fontMedium, size: 13))
        }
        .foregroundStyle(.secondary)
    }

    /// Reads the current route's first output and maps its port type +
    /// name to (display name, SF symbol). Called only on route changes
    /// (+ first appear) — not inline in `body`.
    private static func resolveAudioOutput() -> (name: String, icon: String) {
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
        ZStack {
            // Ghost covers — prev on the left, next on the right. Their
            // visibility ramps up proportionally to how far the user is
            // dragging. They share the same 3D perspective plane so the
            // carousel reads as a single fan.
            carouselSideCover(track: prevNeighbor, side: .left)
            carouselSideCover(track: nextNeighbor, side: .right)

            // Current cover — bank/scale/offset with the drag so it
            // reads as pivoting out of frame. Hero-tag lives on this
            // sub-group (not the outer ZStack) so `matchedGeometry`
            // only interpolates the main cover, not the carousel
            // side covers / brush overlay that sit in the same stack.
            Group {
                if let uiImage = currentCover {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 320, height: 320)
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
                        .frame(width: 320, height: 320)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 80, weight: .ultraLight))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                }
            }
            // Hero tag LIVES on the already-sized, already-clipped
            // view — the mini-player applies matchedGeometryEffect in
            // exactly the same order so SwiftUI can interpolate
            // symmetric frames instead of guessing intermediate sizes.
            .offset(x: carouselDragX * Carousel.dragFollow)
            .rotation3DEffect(
                .degrees(Double(-carouselDragX) * Carousel.rotationPerPoint),
                axis: (x: 0, y: 1, z: 0),
                perspective: Carousel.perspective
            )
            .scaleEffect(1.0 - min(abs(carouselDragX) / Carousel.centerShrinkDivisor, Carousel.centerMaxShrink))

            // Brush overlay — sweeps old → new cover diagonally.
            if let snapshot = brushSnapshot {
                CoverBrushTransitionView(snapshot: snapshot, size: 320, cornerRadius: 28)
                    .id(snapshot.token)
                    .onAppear {
                        // Cancel any previous cleanup — if the user
                        // switched tracks faster than the animation
                        // window, the old timer would otherwise nil out
                        // the current snapshot prematurely.
                        brushCleanupTask?.cancel()
                        let token = snapshot.token
                        brushCleanupTask = Task { @MainActor in
                            // Brush animation is 0.9 s; give it a
                            // ~150 ms render-flush margin so the fully
                            // swept final frame has time to commit
                            // before we unmount the overlay — without
                            // that margin the mid-feather can appear
                            // as a faint residue of the old cover.
                            try? await Task.sleep(nanoseconds: 1_050_000_000)
                            if Task.isCancelled { return }
                            if brushSnapshot?.token == token {
                                brushSnapshot = nil
                            }
                        }
                    }
            }
        }
        .frame(width: 320, height: 320)
        .shadow(color: activeAccent.opacity(0.25), radius: 24, y: 12)
        .scaleEffect(player.isPlaying ? 1.0 : 0.92)
        .animation(.easeInOut(duration: 0.5), value: player.isPlaying)
        .animation(.easeInOut(duration: 0.45), value: activeAccent)
        .gesture(
            DragGesture(minimumDistance: 12)
                .onChanged { value in
                    // Only react to predominantly horizontal drags so
                    // the parent ScrollView's vertical scroll still
                    // wins for up/down swipes.
                    if abs(value.translation.width) > abs(value.translation.height) {
                        carouselDragX = value.translation.width
                    }
                }
                .onEnded { value in
                    if value.translation.width > Carousel.switchThreshold {
                        suppressNextFracture = true
                        player.previousTrack()
                    } else if value.translation.width < -Carousel.switchThreshold {
                        suppressNextFracture = true
                        player.nextTrack()
                    }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                        carouselDragX = 0
                    }
                }
        )
        .onChange(of: player.currentTrack?.fileName) { oldValue, newValue in
            guard oldValue != newValue, let old = oldValue, let new = newValue else {
                previousArtworkFileName = newValue
                return
            }
            if suppressNextFracture {
                suppressNextFracture = false
                previousArtworkFileName = newValue
                return
            }
            // Source of truth = `player.artworkCache` (a persistent
            // dict on the player). Reading `@State currentCover` here
            // would race with `hydrateCurrentCover`, which can clear
            // the cache to nil before `.onChange` reads it on fast
            // switches.
            if let oldData = player.artworkCache[old],
               let oldImage = UIImage(data: oldData),
               let newData = player.artworkCache[new],
               let newImage = UIImage(data: newData) {
                brushSnapshot = .make(old: oldImage, new: newImage)
            }
            previousArtworkFileName = newValue
        }
    }

    // MARK: - Carousel neighbours

    private enum CarouselSide { case left, right }

    /// Tuning constants for the 3D cover-swipe carousel. Extracted out
    /// of the layout code so the numbers are named and tweakable.
    private enum Carousel {
        /// Horizontal drag, in points, that triggers a prev/next track
        /// switch. Shorter = twitchier, longer = more deliberate.
        static let switchThreshold: CGFloat = 90
        /// Denominator used to convert drag distance into a 0…1 reveal
        /// factor for the side covers. Roughly "fully revealed at N pt".
        static let revealDivisor: CGFloat = 200
        /// Attenuation of the current cover's drag offset vs raw drag —
        /// it follows the finger but slightly lazier for depth feel.
        static let dragFollow: CGFloat = 0.6
        /// Follow factor for side covers (slightly faster than the
        /// centre so they look "pushed in" by the current cover).
        static let sideDragFollow: CGFloat = 0.9
        /// Degrees of 3D Y-axis rotation per point of drag.
        static let rotationPerPoint: Double = 0.18
        /// 3D perspective used for both the current and side covers.
        static let perspective: CGFloat = 0.6
        /// Base offset at which side covers sit when drag == 0.
        static let sideBaseOffset: CGFloat = 200
        /// Starting rotation of side covers (before drag modulates it).
        static let sideBaseRotation: Double = 45
        /// Centre cover shrinks a little as drag grows — this is the
        /// denominator controlling how aggressively.
        static let centerShrinkDivisor: CGFloat = 900
        /// Maximum shrink (0…1) applied to centre cover during drag.
        static let centerMaxShrink: CGFloat = 0.2
    }

    /// Adjacent tracks in the player's current list, wrapping around at
    /// the ends so the carousel never shows an empty slot.
    private var prevNeighbor: Track? {
        guard !player.tracks.isEmpty else { return nil }
        let i = (player.currentTrackIndex - 1 + player.tracks.count) % player.tracks.count
        return i == player.currentTrackIndex ? nil : player.tracks[i]
    }

    private var nextNeighbor: Track? {
        guard !player.tracks.isEmpty else { return nil }
        let i = (player.currentTrackIndex + 1) % player.tracks.count
        return i == player.currentTrackIndex ? nil : player.tracks[i]
    }

    /// Renders a prev or next cover that fades in with rotation as the
    /// user drags. Positive `carouselDragX` surfaces the left cover;
    /// negative surfaces the right. Skipped entirely while idle so we
    /// don't decode / transform an invisible view every frame.
    @ViewBuilder
    private func carouselSideCover(track: Track?, side: CarouselSide) -> some View {
        let sign: CGFloat = side == .left ? 1 : -1
        let reveal = max(0, min(1, sign * carouselDragX / Carousel.revealDivisor))
        // `track` itself isn't rendered — we use the pre-decoded cached
        // image — but we still guard on its presence so the empty-list
        // case (no neighbour) doesn't show a placeholder.
        if track != nil, reveal > 0.01 {
            let baseOffset: CGFloat = side == .left ? -Carousel.sideBaseOffset : Carousel.sideBaseOffset
            let rotation: Double = side == .left ? Carousel.sideBaseRotation : -Carousel.sideBaseRotation
            let cached: UIImage? = side == .left ? prevCover : nextCover

            sideCoverImage(cached: cached)
                .frame(width: 320, height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .scaleEffect(0.68 + reveal * 0.22)
                .opacity(reveal * 0.9)
                .offset(x: baseOffset + carouselDragX * Carousel.sideDragFollow)
                .rotation3DEffect(
                    .degrees(rotation - Double(carouselDragX) * Carousel.rotationPerPoint),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: Carousel.perspective
                )
                .allowsHitTesting(false)
        }
    }

    // MARK: - Artwork decode helpers

    /// Decodes the current cover, polling a bit so late-arriving Genius
    /// artwork also lands. Cancelled automatically when `fileName`
    /// changes (via `.task(id:)`).
    private func hydrateCurrentCover() async {
        let fn = player.currentTrack?.fileName
        // Immediate decode first — common case on replay.
        if let img = await decodeArtwork(fileName: fn) {
            currentCover = img
            kickPaletteExtraction(for: fn)
            return
        }
        currentCover = nil
        // Up to ~3 s of retries at 200 ms for artwork that's still
        // loading in the background.
        for _ in 0..<15 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if Task.isCancelled { return }
            if let img = await decodeArtwork(fileName: fn) {
                currentCover = img
                kickPaletteExtraction(for: fn)
                return
            }
        }
    }

    /// Nudges `CoverPaletteManager` to extract (or re-use) the
    /// gradient palette for the track. Cheap when palette is cached —
    /// the manager dedups internally. Skipped entirely when the
    /// cover-gradient feature is off, otherwise we'd burn CoreImage
    /// cycles + memory extracting palettes nobody will ever render.
    private func kickPaletteExtraction(for fileName: String?) {
        guard theme.useCoverGradient,
              let fileName,
              let data = player.artworkCache[fileName] else { return }
        CoverPaletteManager.shared.ensurePalette(for: fileName, imageData: data)
    }

    /// Looks up raw cover data in the player's cache and decodes it.
    /// Returns nil if the file isn't in cache yet or decoding fails.
    private func decodeArtwork(fileName: String?) async -> UIImage? {
        guard let fileName,
              let data = player.artworkCache[fileName] else { return nil }
        return UIImage(data: data)
    }

    @ViewBuilder
    private func sideCoverImage(cached: UIImage?) -> some View {
        if let uiImage = cached {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            LinearGradient(
                colors: [
                    theme.currentTheme.accent.opacity(0.45),
                    theme.currentTheme.secondary.opacity(0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 60, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    // MARK: - Track Info

    private var trackInfo: some View {
        VStack(spacing: 6) {
            MarqueeText(
                text: player.currentTrack?.title ?? Loc.noTrackSelected,
                font: .custom(Loc.fontBold, size: 22),
                alignment: .center
            )
            .foregroundStyle(.primary)

            MarqueeText(
                text: player.currentTrack?.artist ?? Loc.unknownArtist,
                font: .custom(Loc.fontMedium, size: 15),
                alignment: .center
            )
            .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal)
    }

    // MARK: - Progress

    /// Isolates the 4 Hz `currentTime` churn into its own View so the
    /// rest of `PlayerView.body` doesn't re-evaluate on every tick.
    private var progressSection: some View {
        PlayerProgressSection(
            isDragging: $isDraggingSlider,
            dragValue: $dragValue,
            accent: activeAccent
        )
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
                    .accessibilityLabel(Loc.a11yPreviousTrack)

                    Button {
                        player.togglePlayPause()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 32))
                            .frame(width: 72, height: 72)
                            .contentTransition(.symbolEffect(.replace.downUp))
                    }
                    .buttonStyle(.glassProminent)
                    .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: player.isPlaying)
                    .accessibilityLabel(player.isPlaying ? Loc.a11yPause : Loc.a11yPlay)

                    Button {
                        player.nextTrack()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                            .frame(width: 52, height: 52)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel(Loc.a11yNextTrack)
                }
            }
            // Tints the glass play/prev/next buttons with the active
            // accent — picked up automatically by `.buttonStyle(.glass*)`
            // from the environment. When cover-gradient is off this
            // is the theme accent, so behaviour matches prior builds.
            .tint(activeAccent)

            HStack(spacing: 20) {
                Button {
                    showSleepTimer = true
                } label: {
                    Image(systemName: player.isSleepTimerActive ? "moon.fill" : "moon.zzz")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(player.isSleepTimerActive ? activeAccent : Color.secondary)
                        .frame(width: 44, height: 44)
                        .symbolEffect(.bounce, value: player.isSleepTimerActive)
                        .symbolEffect(.pulse, options: .repeating, isActive: player.isSleepTimerActive)
                }
                .accessibilityLabel(Loc.a11ySleepTimer)

                Button {
                    player.toggleShuffle()
                } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(player.isShuffleOn ? activeAccent : Color.secondary)
                        .frame(width: 44, height: 44)
                        .symbolEffect(.bounce, value: player.isShuffleOn)
                }
                .accessibilityLabel(Loc.a11yShuffle)
                .accessibilityValue(player.isShuffleOn ? "on" : "off")

                Button {
                    player.toggleRepeatMode()
                } label: {
                    Image(systemName: player.repeatMode.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(player.repeatMode == .off ? Color.secondary : activeAccent)
                        .frame(width: 44, height: 44)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.bounce, value: player.repeatMode)
                }
                .accessibilityLabel(Loc.a11yRepeat)

                Button {
                    showQueue = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(!player.queue.isEmpty ? activeAccent : Color.secondary)
                        .frame(width: 44, height: 44)
                        .symbolEffect(.bounce, value: player.queue.count)
                }
                .accessibilityLabel(Loc.a11yQueue)

                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(Loc.a11yShare)
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

    @ViewBuilder
    private var lyricsSection: some View {
        if let key = lyricsKey, let syncedLines = genius.cachedSyncedLyrics[key] {
            // Synced lyrics preview (offset +0.3s to compensate display lag)
            let currentTime = (isDraggingSlider ? dragValue : player.currentTime) + 0.3
            let currentIndex = syncedLines.lastIndex(where: { $0.time <= currentTime }) ?? 0
            let startIndex = min(currentIndex, max(0, syncedLines.count - 4))
            let endIndex = min(startIndex + 4, syncedLines.count)
            let rawPreview = Array(syncedLines[startIndex..<endIndex])
            let currentOffset = currentIndex - startIndex
            // Always show 4 lines to prevent block resizing.
            let previewLines: [LyricsPreviewLine] = (0..<4).map { i in
                if i < rawPreview.count {
                    return .init(text: rawPreview[i].text, isReal: true, isCurrent: i == currentOffset)
                } else {
                    return .init(text: " ", isReal: false, isCurrent: false)
                }
            }
            LyricsPreviewCard(
                source: .synced,
                animateValue: currentIndex,
                syncedLines: previewLines,
                plainLines: nil,
                onTap: { showLyrics = true },
                tintAccent: activeAccent,
                tintSecondary: activeSecondary
            )
        } else if let key = lyricsKey, let lyrics = genius.cachedLyrics[key] {
            let lines = lyrics.components(separatedBy: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let preview = Array(lines.prefix(4))
            LyricsPreviewCard(
                source: .plain,
                animateValue: 0,
                syncedLines: nil,
                plainLines: preview,
                onTap: { showLyrics = true },
                tintAccent: activeAccent,
                tintSecondary: activeSecondary
            )
        } else if genius.isLoadingLyrics {
            LyricsLoadingView(
                tintAccent: activeAccent,
                tintSecondary: activeSecondary
            )
        }
    }
}

// MARK: - Lyrics preview card

/// A single line of the 4-line synced lyrics preview.
private struct LyricsPreviewLine {
    let text: String
    /// False for filler lines that keep the card height stable.
    let isReal: Bool
    /// True for the line that currently matches playback time.
    let isCurrent: Bool
}

/// Unified card rendering both the synced and plain Genius variants.
/// Was 150 lines of duplicated layout before extraction.
private struct LyricsPreviewCard: View {
    enum Source { case synced, plain }

    let source: Source
    /// Drives the line-change animation (currentIndex for synced).
    let animateValue: Int
    let syncedLines: [LyricsPreviewLine]?
    let plainLines: [String]?
    let onTap: () -> Void
    /// Palette-driven tint pair; card background re-skins per album
    /// when cover-gradient is on.
    var tintAccent: Color
    var tintSecondary: Color

    @ObservedObject var theme = ThemeManager.shared

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                header
                body(for: source)
                footer
            }
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        HStack {
            Image(systemName: "text.quote")
                .font(.system(size: 13, weight: .bold))
            Text(Loc.lyrics)
                .font(.custom(Loc.fontBold, size: 13))
                .tracking(0.5)
            Spacer()
            if source == .synced {
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 6, height: 6)
                    Text("SYNCED")
                        .font(.custom(Loc.fontBold, size: 10))
                        .tracking(0.5)
                }
                .foregroundStyle(.green.opacity(0.7))
            } else {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .foregroundStyle(.white.opacity(0.5))
        .textCase(.uppercase)
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func body(for source: Source) -> some View {
        switch source {
        case .synced:
            syncedBody
        case .plain:
            plainBody
        }
    }

    private var syncedBody: some View {
        let lines = syncedLines ?? []
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(0..<lines.count, id: \.self) { idx in
                let line = lines[idx]
                Text(line.text)
                    .font(.custom(Loc.fontBold, size: line.isCurrent ? 20 : 16))
                    .foregroundStyle(.white.opacity(line.isReal ? (line.isCurrent ? 0.9 : 0.35) : 0))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 18)
        .animation(.easeInOut(duration: 0.3), value: animateValue)
    }

    private var plainBody: some View {
        let lines = plainLines ?? []
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
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
    }

    private var footer: some View {
        HStack {
            Text(source == .synced ? "LRCLIB" : "Genius")
                .font(.custom(Loc.fontMedium, size: 11))
                .foregroundStyle(.white.opacity(0.3))
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                LinearGradient(
                    colors: [
                        tintAccent.opacity(0.55),
                        tintSecondary.opacity(0.4),
                        tintAccent.opacity(0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

// MARK: - Progress subview

/// Progress slider + elapsed/remaining time labels. Observes the
/// `AudioPlayerManager` directly — it's the only part of the player UI
/// that needs to react to 4 Hz `currentTime` updates, so isolating it
/// keeps the enclosing `PlayerView` from rebuilding on every tick.
private struct PlayerProgressSection: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @Binding var isDragging: Bool
    @Binding var dragValue: TimeInterval
    /// Tint override — usually the dynamic palette accent so the
    /// slider matches the current cover's colour. Falls back to the
    /// theme accent when no cover palette is available.
    var accent: Color

    var body: some View {
        VStack(spacing: 4) {
            slider
            timeLabels
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var slider: some View {
        if theme.sliderIcon == .defaultCircle {
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
            .tint(accent)
        } else {
            CustomSlider(
                value: Binding(
                    get: { isDragging ? dragValue : player.currentTime },
                    set: { dragValue = $0 }
                ),
                range: 0...max(player.duration, 0.01),
                sliderIcon: theme.sliderIcon,
                accentColor: accent,
                onDragStarted: { isDragging = true },
                onDragEnded: {
                    player.seek(to: dragValue)
                    isDragging = false
                }
            )
            .frame(height: 36)
        }
    }

    private var timeLabels: some View {
        let shownTime = isDragging ? dragValue : player.currentTime
        return HStack {
            Text(player.formatTime(shownTime))
                .font(.custom(Loc.fontMedium, size: 12).monospacedDigit())
                .foregroundStyle(.secondary)

            Spacer()

            Text(player.formatTime(max(player.duration - shownTime, 0)))
                .font(.custom(Loc.fontMedium, size: 12).monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}
