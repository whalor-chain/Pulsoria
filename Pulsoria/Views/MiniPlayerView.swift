import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var theme = ThemeManager.shared
    var onTap: () -> Void = {}

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
                        Text(player.currentTrack?.title ?? "")
                            .font(.custom(Loc.fontMedium, size: 15))
                            .lineLimit(1)

                        Text(player.currentTrack?.artist ?? "")
                            .font(.custom(Loc.fontMedium, size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture { onTap() }

                Button {
                    if let track = player.currentTrack {
                        player.toggleFavorite(for: track)
                    }
                } label: {
                    Image(systemName: player.currentTrack?.isFavorite == true ? "heart.fill" : "heart")
                        .font(.body)
                        .foregroundStyle(player.currentTrack?.isFavorite == true ? theme.currentTheme.accent : .secondary)
                        .frame(width: 30, height: 30)
                }

                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 36, height: 36)
                }
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
    }

    @ViewBuilder
    private var trackArtwork: some View {
        if let fileName = player.currentTrack?.fileName,
           let data = player.artworkCache[fileName],
           let uiImage = UIImage(data: data) {
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
