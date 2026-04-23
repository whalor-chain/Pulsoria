import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var theme = ThemeManager.shared
    var onTap: () -> Void = {}

    /// Decoded cover cached across renders — `UIImage(data:)` ran inline
    /// in `body` on every progressTimer tick (4 Hz), which was ~10 ms
    /// of main-thread work per tick. Caching removes the decode from
    /// the hot path.
    @State private var cover: UIImage?

    private var progress: Double {
        guard player.duration > 0 else { return 0 }
        return player.currentTime / player.duration
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.ultraThinMaterial)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.currentTheme.accent,
                                    theme.currentTheme.secondary.opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 4)
            .clipShape(Capsule())
            .padding(.horizontal, 12)

            HStack(spacing: 12) {
                // Tappable area — opens full player
                HStack(spacing: 12) {
                    trackArtwork
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        MarqueeText(
                            text: player.currentTrack?.title ?? "",
                            font: .custom(Loc.fontMedium, size: 15)
                        )

                        MarqueeText(
                            text: player.currentTrack?.artist ?? "",
                            font: .custom(Loc.fontMedium, size: 12)
                        )
                        .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture { onTap() }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(Loc.a11yOpenPlayer)
                .accessibilityValue("\(player.currentTrack?.title ?? ""), \(player.currentTrack?.artist ?? "")")

                Button {
                    if let track = player.currentTrack {
                        player.toggleFavorite(for: track)
                    }
                } label: {
                    Image(systemName: player.currentTrack?.isFavorite == true ? "heart.fill" : "heart")
                        .font(.body)
                        .foregroundStyle(player.currentTrack?.isFavorite == true ? theme.currentTheme.accent : .secondary)
                        .frame(width: 30, height: 30)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.bounce, value: player.currentTrack?.isFavorite)
                }
                .accessibilityLabel(
                    player.currentTrack?.isFavorite == true ? Loc.a11yRemoveFavorite : Loc.a11yAddFavorite
                )

                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 36, height: 36)
                        .contentTransition(.symbolEffect(.replace.downUp))
                }
                .accessibilityLabel(player.isPlaying ? Loc.a11yPause : Loc.a11yPlay)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .glassEffect(in: .rect(cornerRadius: 16))
        .padding(.horizontal, 8)
        .task {
            if let track = player.currentTrack {
                await player.loadArtwork(for: track)
            }
        }
        // Decode the cover once per track name. Polls a few times so we
        // catch late-arriving Genius artwork after the initial play.
        .task(id: player.currentTrack?.fileName) {
            await hydrateCover()
        }
    }

    private func hydrateCover() async {
        let fn = player.currentTrack?.fileName
        if let fn, let data = player.artworkCache[fn], let img = UIImage(data: data) {
            cover = img
            return
        }
        cover = nil
        for _ in 0..<15 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if Task.isCancelled { return }
            if let fn, let data = player.artworkCache[fn], let img = UIImage(data: data) {
                cover = img
                return
            }
        }
    }

    @ViewBuilder
    private var trackArtwork: some View {
        if let uiImage = cover {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            RoundedRectangle(cornerRadius: 8)
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
                .overlay {
                    Image(systemName: "music.note")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
        }
    }
}
