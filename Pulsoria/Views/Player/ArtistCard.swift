import SwiftUI

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
