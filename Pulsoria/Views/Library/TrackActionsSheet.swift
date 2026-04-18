import SwiftUI

struct TrackActionsSheet: View {
    let track: Track
    var onAddToPlaylist: (() -> Void)?
    var onOpenAlbum: (() -> Void)?
    var onOpenArtist: (() -> Void)?
    var onShare: (() -> Void)?
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Track info header
            HStack(spacing: 14) {
                if let data = player.artworkCache[track.fileName],
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [theme.currentTheme.accent.opacity(0.4), theme.currentTheme.secondary.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.custom(Loc.fontBold, size: 17))
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.custom(Loc.fontMedium, size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()
                .padding(.horizontal, 20)

            // Actions
            VStack(spacing: 4) {
                actionButton(
                    title: track.isFavorite ? Loc.inFavorites : Loc.addToFavorites,
                    icon: track.isFavorite ? "heart.fill" : "heart",
                    color: track.isFavorite ? .pink : .primary
                ) {
                    player.toggleFavorite(for: track)
                    dismiss()
                }

                actionButton(
                    title: Loc.addToQueue,
                    icon: "text.line.last.and.arrowtriangle.forward",
                    color: .primary
                ) {
                    player.addToQueue(track)
                    dismiss()
                }

                if let onAddToPlaylist {
                    actionButton(
                        title: Loc.addToPlaylist,
                        icon: "text.badge.plus",
                        color: .primary
                    ) {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onAddToPlaylist()
                        }
                    }
                }

                if let onOpenAlbum {
                    actionButton(
                        title: Loc.openAlbum,
                        icon: "play.square.stack",
                        color: .primary
                    ) {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onOpenAlbum()
                        }
                    }
                }

                if let onOpenArtist {
                    actionButton(
                        title: Loc.openArtist,
                        icon: "music.mic",
                        color: .primary
                    ) {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onOpenArtist()
                        }
                    }
                }

                actionButton(
                    title: Loc.share,
                    icon: "square.and.arrow.up",
                    color: .primary
                ) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onShare?()
                    }
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 12)

            Spacer()
        }
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                    .frame(width: 28)

                Text(title)
                    .font(.custom(Loc.fontMedium, size: 16))
                    .foregroundStyle(color)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

