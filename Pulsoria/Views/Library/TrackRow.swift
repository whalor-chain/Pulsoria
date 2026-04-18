import SwiftUI

struct TrackRow: View {
    let track: Track
    let isCurrentTrack: Bool
    let isPlaying: Bool
    let onTap: () -> Void
    var onAddToPlaylist: (() -> Void)? = nil
    var onOpenAlbum: (() -> Void)? = nil
    var onOpenArtist: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @State private var showActions = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Album art from metadata
                trackArtwork
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        if isPlaying {
                            Image(systemName: "waveform")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(theme.currentTheme.accent)
                                .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                        }

                        Text(track.title)
                            .font(.custom(Loc.fontMedium, size: 17))
                            .foregroundStyle(isCurrentTrack ? theme.currentTheme.accent : .primary)
                            .lineLimit(1)
                    }

                    Text(track.artist)
                        .font(.custom(Loc.fontMedium, size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    showActions = true
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                        .font(.body)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.4), trigger: showActions)
            }
            .padding(.vertical, 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .task {
            await player.loadArtwork(for: track)
        }
        .sheet(isPresented: $showActions) {
            TrackActionsSheet(
                track: track,
                onAddToPlaylist: onAddToPlaylist,
                onOpenAlbum: onOpenAlbum,
                onOpenArtist: onOpenArtist,
                onShare: onShare
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var trackArtwork: some View {
        if let data = player.artworkCache[track.fileName],
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [theme.currentTheme.accent.opacity(0.4), theme.currentTheme.secondary.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    if isPlaying {
                        Image(systemName: "waveform")
                            .font(.caption)
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "music.note")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
        }
    }
}

