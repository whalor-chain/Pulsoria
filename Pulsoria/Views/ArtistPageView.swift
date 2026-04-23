import SwiftUI

struct ArtistPageView: View {
    let artistName: String
    let initialTrack: Track
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var genius = GeniusManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var isFavoriteArtist: Bool = false

    private var artistTracks: [Track] {
        let name = artistName.lowercased()
        return player.tracks.filter { $0.artist.lowercased().contains(name) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                artistHeader
                    .padding(.top, 20)

                actionButtons

                // Genius info
                if genius.hasToken {
                    if genius.isLoading {
                        geniusSkeletonSection
                    } else {
                        if let info = genius.artistInfo {
                            geniusInfoSection(info: info)
                        }

                        if let song = genius.songInfo {
                            songInfoSection(song: song)
                        }
                    }
                }

                trackListSection
            }
            .padding(.horizontal)
            .padding(.bottom, 80)
        }
        .background {
            LinearGradient(
                colors: [
                    theme.currentTheme.accent.opacity(0.2),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let favs = UserDefaults.standard.stringArray(forKey: UserDefaultsKey.favoriteArtists) ?? []
            isFavoriteArtist = favs.contains(artistName.lowercased())
        }
        .task {
            if genius.hasToken {
                await genius.fetchArtistInfo(name: artistName)
                await genius.fetchSongInfo(title: initialTrack.title, artist: artistName)
            }
        }
    }

    // MARK: - Artist Header

    private var artistHeader: some View {
        VStack(spacing: 16) {
            // Avatar — Genius image or local artwork
            ZStack {
                if let geniusURL = genius.artistInfo?.imageURL {
                    AsyncImage(url: geniusURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        localAvatar
                    }
                    .frame(width: 140, height: 140)
                    .clipShape(Circle())
                } else {
                    localAvatar
                }
            }
            .shadow(color: theme.currentTheme.accent.opacity(0.3), radius: 20, y: 8)

            Text(genius.artistInfo?.name ?? artistName)
                .font(.custom(Loc.fontBold, size: 28))
                .multilineTextAlignment(.center)

            // Stats
            HStack(spacing: 16) {
                statBadge(
                    value: "\(artistTracks.count)",
                    label: artistTracks.count == 1 ? Loc.trackSingular : Loc.trackCount
                )

                statBadge(
                    value: "\(favoritesCount)",
                    label: Loc.favorites
                )
            }

            // Favorite button
            Button {
                withAnimation(.bouncy(duration: 0.4)) {
                    isFavoriteArtist.toggle()
                    saveFavoriteArtist()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isFavoriteArtist ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .medium))
                        .symbolEffect(.bounce, value: isFavoriteArtist)

                    Text(isFavoriteArtist ? Loc.inFavorites : Loc.addToFavorites)
                        .font(.custom(Loc.fontMedium, size: 14))
                }
                .foregroundStyle(isFavoriteArtist ? .pink : Color.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .scaleEffect(isFavoriteArtist ? 1.05 : 1.0)
            }
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.4), trigger: isFavoriteArtist)
        }
    }

    @ViewBuilder
    private var localAvatar: some View {
        if let data = player.artworkCache[initialTrack.fileName],
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 140, height: 140)
                .clipShape(Circle())
        } else {
            Circle()
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
                .frame(width: 140, height: 140)
                .overlay {
                    Image(systemName: "music.mic")
                        .font(.system(size: 50, weight: .thin))
                        .foregroundStyle(.white.opacity(0.8))
                }
        }
    }

    private var favoritesCount: Int {
        artistTracks.filter(\.isFavorite).count
    }

    private func saveFavoriteArtist() {
        var favs = UserDefaults.standard.stringArray(forKey: UserDefaultsKey.favoriteArtists) ?? []
        let key = artistName.lowercased()
        if isFavoriteArtist {
            if !favs.contains(key) { favs.append(key) }
        } else {
            favs.removeAll { $0 == key }
        }
        UserDefaults.standard.set(favs, forKey: UserDefaultsKey.favoriteArtists)
    }

    private func statBadge(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom(Loc.fontBold, size: 20))

            Text(label)
                .font(.custom(Loc.fontMedium, size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(width: 100)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    // MARK: - Genius Skeleton

    /// Placeholder for the Genius bio + song-info blocks. Matches
    /// the real section's silhouette (two glass cards, one with a
    /// 6-line bio, one with a short song description) so the
    /// transition to real data doesn't shift the page.
    private var geniusSkeletonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Skeleton(cornerRadius: 4)
                .frame(width: 120, height: 18)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<5, id: \.self) { i in
                    Skeleton(cornerRadius: 4)
                        .frame(height: 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .scaleEffect(x: [1.0, 0.92, 0.96, 0.85, 0.6][i], y: 1, anchor: .leading)
                }
            }
            .padding(14)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))

            Skeleton(cornerRadius: 4)
                .frame(width: 140, height: 18)
                .padding(.leading, 4)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Skeleton(cornerRadius: 4)
                        .frame(height: 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .scaleEffect(x: [0.95, 0.8, 0.55][i], y: 1, anchor: .leading)
                }
            }
            .padding(14)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
        }
    }

    // MARK: - Genius Info

    private func geniusInfoSection(info: GeniusArtistInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Biography
            if let bio = info.description, !bio.isEmpty, bio != "?" {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Loc.biography)
                        .font(.custom(Loc.fontBold, size: 18))
                        .padding(.leading, 4)

                    Text(bio)
                        .font(.custom(Loc.fontMedium, size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))
                }
            }

            // Social media
            let socials = buildSocials(info: info)
            if !socials.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Loc.socialMedia)
                        .font(.custom(Loc.fontBold, size: 18))
                        .padding(.leading, 4)

                    VStack(spacing: 2) {
                        ForEach(socials, id: \.name) { social in
                            Button {
                                if let url = URL(string: social.url) {
                                    openURL(url)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: social.icon)
                                        .font(.system(size: 16))
                                        .foregroundStyle(theme.currentTheme.accent)
                                        .frame(width: 28)

                                    Text(social.displayName)
                                        .font(.custom(Loc.fontMedium, size: 15))

                                    Spacer()

                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 14)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
                }
            }
        }
    }

    private struct SocialLink {
        let name: String
        let displayName: String
        let icon: String
        let url: String
    }

    private func buildSocials(info: GeniusArtistInfo) -> [SocialLink] {
        var result: [SocialLink] = []

        if let ig = info.instagramName, !ig.isEmpty {
            result.append(SocialLink(
                name: "instagram",
                displayName: "@\(ig)",
                icon: "camera",
                url: "https://instagram.com/\(ig)"
            ))
        }
        if let tw = info.twitterName, !tw.isEmpty {
            result.append(SocialLink(
                name: "twitter",
                displayName: "@\(tw)",
                icon: "at",
                url: "https://x.com/\(tw)"
            ))
        }
        if let fb = info.facebookName, !fb.isEmpty {
            result.append(SocialLink(
                name: "facebook",
                displayName: fb,
                icon: "hand.thumbsup",
                url: "https://facebook.com/\(fb)"
            ))
        }

        return result
    }

    // MARK: - Song Info

    private func songInfoSection(song: GeniusSongInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Loc.songInfo)
                .font(.custom(Loc.fontBold, size: 18))
                .padding(.leading, 4)

            VStack(spacing: 2) {
                if let album = song.albumName {
                    infoRow(label: Loc.album, value: album)
                }

                if let date = song.releaseDate {
                    infoRow(label: Loc.releaseDate, value: date)
                }

                if let pageURL = song.pageURL {
                    Button {
                        openURL(pageURL)
                    } label: {
                        HStack {
                            Image(systemName: "globe")
                                .font(.system(size: 16))
                                .foregroundStyle(theme.currentTheme.accent)
                                .frame(width: 28)

                            Text(Loc.openInGenius)
                                .font(.custom(Loc.fontMedium, size: 15))

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                    }
                    .buttonStyle(.plain)
                }
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.custom(Loc.fontMedium, size: 14))
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.custom(Loc.fontMedium, size: 14))
                .lineLimit(1)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        GlassEffectContainer {
            HStack(spacing: 12) {
                Button {
                    playAllTracks(shuffle: false)
                } label: {
                    Label(Loc.playAll, systemImage: "play.fill")
                        .font(.custom(Loc.fontBold, size: 15))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.glass)
                .tint(theme.currentTheme.accent)

                Button {
                    playAllTracks(shuffle: true)
                } label: {
                    Label(Loc.shuffleAll, systemImage: "shuffle")
                        .font(.custom(Loc.fontBold, size: 15))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.glass)
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.4), trigger: player.isPlaying)
    }

    private func playAllTracks(shuffle: Bool) {
        guard let firstTrack = artistTracks.first,
              let index = player.tracks.firstIndex(where: { $0.id == firstTrack.id }) else { return }

        if shuffle {
            player.isShuffleOn = true
        }

        player.playingSource = artistName
        player.playTrack(at: index)

        for track in artistTracks.dropFirst() {
            player.addToQueue(track)
        }
    }

    // MARK: - Track List

    private var trackListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Loc.allTracks)
                .font(.custom(Loc.fontBold, size: 18))
                .padding(.leading, 4)

            VStack(spacing: 2) {
                ForEach(Array(artistTracks.enumerated()), id: \.element.id) { index, track in
                    Button {
                        if let actualIndex = player.tracks.firstIndex(where: { $0.id == track.id }) {
                            player.playingSource = artistName
                            player.playTrack(at: actualIndex)
                        }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                if track.id == player.currentTrack?.id && player.isPlaying {
                                    Image(systemName: "waveform")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(theme.currentTheme.accent)
                                        .symbolEffect(.variableColor.iterative, isActive: true)
                                        .frame(width: 28)
                                } else {
                                    Text("\(index + 1)")
                                        .font(.custom(Loc.fontMedium, size: 15))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 28)
                                }
                            }

                            if let data = player.artworkCache[track.fileName],
                               let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                theme.currentTheme.accent.opacity(0.4),
                                                theme.currentTheme.secondary.opacity(0.3)
                                            ],
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
                                    .font(.custom(Loc.fontMedium, size: 16))
                                    .foregroundStyle(
                                        track.id == player.currentTrack?.id
                                            ? theme.currentTheme.accent
                                            : .primary
                                    )
                                    .lineLimit(1)
                            }

                            Spacer()

                            if track.isFavorite {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.pink)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                    }
                    .buttonStyle(.plain)

                    if index < artistTracks.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
        }
    }
}
