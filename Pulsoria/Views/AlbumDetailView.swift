import SwiftUI

struct AlbumDetailView: View {
    let track: Track
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var genius = GeniusManager.shared

    @State private var albumName: String?
    @State private var albumArtworkURL: URL?
    @State private var albumReleaseDate: String?
    @State private var albumTracks: [Track] = []
    @State private var isLoading = true
    @State private var isFavorite = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                artworkHeader
                albumInfo

                if isLoading {
                    ProgressView()
                        .padding(.top, 20)
                } else {
                    favoriteButton
                    actionButtons
                    trackList
                }
            }
            .padding(.bottom, 100)
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAlbumData()
            if let name = albumName {
                let favs = Set(UserDefaults.standard.stringArray(forKey: "favoriteAlbums") ?? [])
                isFavorite = favs.contains(name.lowercased())
            }
        }
    }

    // MARK: - Load Album Data

    private func loadAlbumData() async {
        // Check if already prefetched
        if let cached = genius.cachedAlbumNames[track.fileName] {
            applyAlbum(cached)
            isLoading = false
            return
        }

        // Fetch for this track if not yet prefetched
        guard let name = await genius.fetchAlbumInfo(for: track) else {
            albumTracks = [track]
            isLoading = false
            return
        }

        applyAlbum(name)
        isLoading = false
    }

    private func applyAlbum(_ name: String) {
        albumName = name
        albumArtworkURL = genius.cachedAlbumArtwork[name.lowercased()]
        albumReleaseDate = genius.cachedAlbumReleaseDate[name.lowercased()]
        albumTracks = player.tracks.filter {
            genius.cachedAlbumNames[$0.fileName] == name
        }
        if albumTracks.isEmpty {
            albumTracks = [track]
        }
    }

    // MARK: - Artwork Header

    private var artworkHeader: some View {
        VStack(spacing: 0) {
            if let albumArtworkURL {
                AsyncImage(url: albumArtworkURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 240, height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: theme.currentTheme.accent.opacity(0.3), radius: 20, y: 10)
                } placeholder: {
                    trackArtworkFallback
                }
            } else {
                trackArtworkFallback
            }
        }
        .padding(.top, 20)
    }

    private var trackArtworkFallback: some View {
        Group {
            if let data = player.artworkCache[track.fileName],
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 240, height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: theme.currentTheme.accent.opacity(0.3), radius: 20, y: 10)
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 240, height: 240)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                    }
            }
        }
    }

    // MARK: - Album Info

    private var albumInfo: some View {
        VStack(spacing: 6) {
            Text(albumName ?? track.title)
                .font(.custom(Loc.fontBold, size: 24))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text({
                if let name = albumName,
                   let primaryArtist = GeniusManager.shared.cachedAlbumArtist[name.lowercased()] {
                    return primaryArtist
                }
                return track.artist
            }())
                .font(.custom(Loc.fontMedium, size: 16))
                .foregroundStyle(theme.currentTheme.accent)

            if albumName != nil && !isLoading {
                let count = albumTracks.count
                let ru = ThemeManager.shared.language == .russian
                HStack(spacing: 4) {
                    Text(Loc.album)
                    if let albumReleaseDate {
                        Text("·")
                        Text(albumReleaseDate)
                    }
                    Text("·")
                    Text("\(count) \(count == 1 ? (ru ? "трек" : "track") : Loc.tracksTab.lowercased())")
                }
                .font(.custom(Loc.fontMedium, size: 13))
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button {
                if let first = albumTracks.first,
                   let index = player.tracks.firstIndex(where: { $0.id == first.id }) {
                    player.playingSource = albumName ?? track.title
                    player.playTrack(at: index)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(Loc.playAll)
                        .font(.custom(Loc.fontBold, size: 14))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(theme.currentTheme.accent)
                .clipShape(Capsule())
            }

            Button {
                let shuffled = albumTracks.shuffled()
                if let first = shuffled.first,
                   let index = player.tracks.firstIndex(where: { $0.id == first.id }) {
                    player.playingSource = albumName ?? track.title
                    player.playTrack(at: index)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 14, weight: .semibold))
                    Text(Loc.shuffle)
                        .font(.custom(Loc.fontBold, size: 14))
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .glassEffect(in: .capsule)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Favorite

    private var favoriteButton: some View {
        Button {
            withAnimation(.bouncy(duration: 0.4)) {
                isFavorite.toggle()
                guard let name = albumName else { return }
                var favs = Set(UserDefaults.standard.stringArray(forKey: "favoriteAlbums") ?? [])
                let key = name.lowercased()
                if isFavorite {
                    favs.insert(key)
                } else {
                    favs.remove(key)
                }
                UserDefaults.standard.set(Array(favs), forKey: "favoriteAlbums")
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 18, weight: .medium))
                    .symbolEffect(.bounce, value: isFavorite)
                Text(isFavorite ? Loc.inFavourites : Loc.addToFavourites)
                    .font(.custom(Loc.fontMedium, size: 14))
            }
            .foregroundStyle(isFavorite ? .red : .secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .scaleEffect(isFavorite ? 1.05 : 1.0)
        }
        .sensoryFeedback(.impact, trigger: isFavorite)
    }

    // MARK: - Track List

    private var trackList: some View {
        VStack(spacing: 0) {
            ForEach(Array(albumTracks.enumerated()), id: \.element.id) { index, albumTrack in
                Button {
                    if let i = player.tracks.firstIndex(where: { $0.id == albumTrack.id }) {
                        player.playingSource = albumName ?? track.title
                        player.playTrack(at: i)
                    }
                } label: {
                    HStack(spacing: 14) {
                        if player.currentTrack?.id == albumTrack.id && player.isPlaying {
                            Image(systemName: "waveform")
                                .font(.system(size: 12))
                                .foregroundStyle(theme.currentTheme.accent)
                                .symbolEffect(.variableColor.iterative, isActive: true)
                                .frame(width: 24)
                        } else {
                            Text("\(index + 1)")
                                .font(.custom(Loc.fontMedium, size: 14))
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                        }

                        if let data = player.artworkCache[albumTrack.fileName],
                           let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.tertiarySystemBackground))
                                .frame(width: 40, height: 40)
                                .overlay {
                                    Image(systemName: "music.note")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(albumTrack.title)
                                .font(.custom(Loc.fontBold, size: 15))
                                .foregroundStyle(player.currentTrack?.id == albumTrack.id ? theme.currentTheme.accent : .primary)
                                .lineLimit(1)

                            Text(albumTrack.artist)
                                .font(.custom(Loc.fontMedium, size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                if index < albumTracks.count - 1 {
                    Divider()
                        .padding(.leading, 94)
                }
            }
        }
    }
}
