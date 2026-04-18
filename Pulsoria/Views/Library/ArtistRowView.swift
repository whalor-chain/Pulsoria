import SwiftUI

struct ArtistRowView: View {
    let name: String
    let trackCount: Int
    let isFavorite: Bool
    let onFavorite: () -> Void
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var genius = GeniusManager.shared

    var body: some View {
        HStack(spacing: 14) {
            // Avatar — Genius photo or gradient
            ZStack {
                if let url = genius.cachedArtistImages[name.lowercased()] {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        avatarPlaceholder
                    }
                } else {
                    avatarPlaceholder
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.custom(Loc.fontMedium, size: 17))
                    .lineLimit(1)

                Text("\(trackCount) \(trackCount == 1 ? Loc.trackSingular : Loc.trackCount)")
                    .font(.custom(Loc.fontMedium, size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 1)
        .contentShape(Rectangle())
        .task {
            if genius.cachedArtistImages[name.lowercased()] == nil {
                await genius.prefetchArtists(from: name)
            }
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [theme.currentTheme.accent.opacity(0.4), theme.currentTheme.secondary.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: "music.mic")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.7))
            }
    }
}

