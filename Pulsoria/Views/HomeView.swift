import SwiftUI

struct HomeView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var playlistManager = PlaylistManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var genius = GeniusManager.shared
    @State private var showSettings = false
    @State private var showStats = false
    @AppStorage("userNickname") private var userNickname = ""
    @State private var profileImage: UIImage? = SettingsView.loadProfileImage()

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let ru = ThemeManager.shared.language == .russian
        switch hour {
        case 5..<12: return ru ? "Доброе утро" : "Good Morning"
        case 12..<18: return ru ? "Добрый день" : "Good Afternoon"
        case 18..<23: return ru ? "Добрый вечер" : "Good Evening"
        default: return ru ? "Доброй ночи" : "Good Night"
        }
    }

    private var greetingIcon: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "sun.max.fill"
        case 12..<18: return "sun.min.fill"
        case 18..<23: return "moon.stars.fill"
        default: return "moon.zzz.fill"
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if player.tracks.isEmpty {
                    emptyState
                } else {
                    dashboardContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        if let profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 36, height: 36)
                                .foregroundStyle(theme.currentTheme.accent)
                        }
                    }
                    .buttonStyle(.plain)
                }
                ToolbarItem(placement: .principal) {
                    Image("FullLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 52)
                        .foregroundStyle(theme.currentTheme.accent)
                }
            }
            .sheet(isPresented: $showStats) {
                NavigationStack {
                    StatsView()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    showStats = false
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            }
                            ToolbarItem(placement: .principal) {
                                Image("StatsLogo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 52)
                                    .foregroundStyle(theme.currentTheme.accent)
                            }
                        }
                }
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showSettings, onDismiss: {
                profileImage = SettingsView.loadProfileImage()
            }) {
                NavigationStack {
                    SettingsView(hideTitle: true)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    showSettings = false
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            }
                        }
                }
                .presentationDragIndicator(.visible)
            }
        }
        .task {
            if !player.tracks.isEmpty {
                await genius.prefetchAllAlbums(tracks: player.tracks)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "music.note.house")
                .font(.system(size: 64))
                .foregroundStyle(theme.currentTheme.accent.opacity(0.5))
            Text(Loc.noActivity)
                .font(.custom(Loc.fontBold, size: 22))
                .foregroundStyle(.primary)
            Text(Loc.noActivityHint)
                .font(.custom(Loc.fontMedium, size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    // MARK: - Dashboard

    private var dashboardContent: some View {
        ScrollView {
            VStack(spacing: 24) {

                heroCard
                    .padding(.horizontal)

                if !player.recentlyPlayed.isEmpty {
                    horizontalSection(
                        title: Loc.recentlyPlayed,
                        tracks: Array(player.recentlyPlayed.prefix(15))
                    )
                }

                if !player.recentlyAdded.isEmpty {
                    horizontalSection(
                        title: Loc.recentlyAdded,
                        tracks: Array(player.recentlyAdded.prefix(15))
                    )
                }

                if !player.topTracks.isEmpty {
                    topTracksSection
                        .padding(.horizontal)
                }

                if !player.topArtists.isEmpty {
                    topArtistsSection
                }

                if !playlistManager.playlists.isEmpty {
                    playlistsSection
                }

                if !player.recentlyLiked.isEmpty {
                    horizontalSection(
                        title: Loc.recentlyLiked,
                        tracks: Array(player.recentlyLiked.prefix(15))
                    )
                }
            }
            .padding(.bottom, 100)
        }
    }



    // MARK: - Hero Card

    private var heroCard: some View {
        idleHero
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .glassEffect(in: .rect(cornerRadius: 20))
    }

    private var idleHero: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(userNickname.isEmpty ? greeting : "\(greeting), \(userNickname)")
                        .font(.custom(Loc.fontBold, size: 22))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [theme.currentTheme.accent, theme.currentTheme.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text(Loc.today)
                        .font(.custom(Loc.fontMedium, size: 14))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: greetingIcon)
                    .font(.system(size: 32))
                    .foregroundStyle(theme.currentTheme.accent.opacity(0.4))
            }

            Spacer()

            HStack(spacing: 12) {
                statPill(icon: "play.fill", value: "\(player.todayPlays)", label: Loc.totalPlays)
                statPill(icon: "clock.fill", value: formattedTodayTime, label: Loc.listened)
                statPill(icon: "music.note", value: "\(player.tracks.count)", label: Loc.tracksTab)
            }

            Button {
                showStats = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis.ascending")
                        .font(.system(size: 14, weight: .semibold))
                    Text(Loc.stats)
                        .font(.custom(Loc.fontBold, size: 14))
                }
                .foregroundStyle(theme.currentTheme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(Capsule())
            }
            .buttonStyle(.glass)
        }
        .padding(20)
    }

    private var formattedTodayTime: String {
        let totalMinutes = Int(player.todayListeningTime / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)\(Loc.hoursShort) \(minutes)\(Loc.minutesShort)"
        }
        return "\(minutes)\(Loc.minutesShort)"
    }

    private func statPill(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.currentTheme.accent)
            Text(value)
                .font(.custom(Loc.fontBold, size: 18))
                .foregroundStyle(.primary)
            Text(label)
                .font(.custom(Loc.fontMedium, size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .glassEffect(in: .rect(cornerRadius: 12))
    }

    // MARK: - Horizontal Track Section

    private func horizontalSection(title: String, tracks: [Track]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.custom(Loc.fontBold, size: 20))
                .foregroundStyle(.primary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(tracks) { track in
                        trackCard(track)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func trackCard(_ track: Track) -> some View {
        NavigationLink(destination: AlbumDetailView(track: track)) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    if let data = player.artworkCache[track.fileName],
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 140, height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.secondarySystemBackground))
                            .frame(width: 140, height: 140)
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.tertiary)
                            }
                    }

                    // Now playing indicator
                    if player.currentTrack?.id == track.id && player.isPlaying {
                        VStack {
                            Spacer()
                            HStack {
                                Image(systemName: "waveform")
                                    .font(.caption)
                                    .foregroundStyle(theme.currentTheme.accent)
                                    .symbolEffect(.variableColor.iterative, isActive: true)
                                Spacer()
                            }
                            .padding(8)
                        }
                        .frame(width: 140, height: 140)
                    }
                }

                Text(track.title)
                    .font(.custom(Loc.fontBold, size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(track.artist)
                    .font(.custom(Loc.fontMedium, size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 140)
        }
        .buttonStyle(.plain)
        .task {
            await player.loadArtwork(for: track)
        }
    }

    // MARK: - Top Tracks

    private var topTracksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Loc.topTracks)
                .font(.custom(Loc.fontBold, size: 20))
                .foregroundStyle(.primary)

            VStack(spacing: 8) {
                ForEach(Array(player.topTracks.prefix(5).enumerated()), id: \.element.id) { index, track in
                    Button {
                        if let i = player.tracks.firstIndex(where: { $0.id == track.id }) {
                            player.playTrack(at: i)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text("#\(index + 1)")
                                .font(.custom(Loc.fontBold, size: 16))
                                .foregroundStyle(theme.currentTheme.accent)
                                .frame(width: 30, alignment: .leading)

                            if let data = player.artworkCache[track.fileName],
                               let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.tertiarySystemBackground))
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        Image(systemName: "music.note")
                                            .foregroundStyle(.tertiary)
                                    }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.custom(Loc.fontBold, size: 14))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.custom(Loc.fontMedium, size: 12))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            if player.currentTrack?.id == track.id && player.isPlaying {
                                Image(systemName: "waveform")
                                    .font(.caption)
                                    .foregroundStyle(theme.currentTheme.accent)
                                    .symbolEffect(.variableColor.iterative, isActive: true)
                            }

                            Text("\(track.playCount) \(Loc.plays)")
                                .font(.custom(Loc.fontMedium, size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .glassEffect(in: .rect(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .task {
                        await player.loadArtwork(for: track)
                    }
                }
            }
        }
    }

    // MARK: - Top Artists

    private var topArtistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Loc.topArtists)
                .font(.custom(Loc.fontBold, size: 20))
                .foregroundStyle(.primary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(player.topArtists.prefix(10).enumerated()), id: \.offset) { _, artist in
                        if let firstTrack = player.tracks.first(where: { $0.artist == artist.name }) {
                            NavigationLink(destination: ArtistPageView(artistName: artist.name, initialTrack: firstTrack)) {
                                VStack(spacing: 8) {
                                    if let url = genius.cachedArtistImages[artist.name.lowercased()] {
                                        AsyncImage(url: url) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 80, height: 80)
                                                .clipShape(Circle())
                                        } placeholder: {
                                            Circle()
                                                .fill(Color(.secondarySystemBackground))
                                                .frame(width: 80, height: 80)
                                                .overlay {
                                                    ProgressView()
                                                }
                                        }
                                    } else {
                                        Circle()
                                            .fill(Color(.secondarySystemBackground))
                                            .frame(width: 80, height: 80)
                                            .overlay {
                                                Image(systemName: "music.mic")
                                                    .font(.title2)
                                                    .foregroundStyle(.tertiary)
                                            }
                                    }

                                    Text(artist.name)
                                        .font(.custom(Loc.fontBold, size: 12))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    Text("\(artist.playCount) \(Loc.plays)")
                                        .font(.custom(Loc.fontMedium, size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 90)
                            }
                            .buttonStyle(.plain)
                            .task {
                                await genius.prefetchArtists(from: artist.name)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Playlists

    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Loc.yourPlaylists)
                .font(.custom(Loc.fontBold, size: 20))
                .foregroundStyle(.primary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(playlistManager.playlists) { playlist in
                        NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                            VStack(alignment: .leading, spacing: 8) {
                                playlistArtworkGrid(playlist)
                                    .frame(width: 140, height: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))

                                Text(playlist.name)
                                    .font(.custom(Loc.fontBold, size: 13))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                Text("\(playlist.trackFileNames.count) \(Loc.tracksTab.lowercased())")
                                    .font(.custom(Loc.fontMedium, size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 140)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func playlistArtworkGrid(_ playlist: Playlist) -> some View {
        let trackNames = Array(playlist.trackFileNames.prefix(4))
        let artworks: [UIImage] = trackNames.compactMap { name in
            guard let data = player.artworkCache[name] else { return nil }
            return UIImage(data: data)
        }

        return Group {
            if artworks.count >= 4 {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)], spacing: 2) {
                    ForEach(0..<4, id: \.self) { i in
                        Image(uiImage: artworks[i])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 69, height: 69)
                            .clipped()
                    }
                }
            } else if let first = artworks.first {
                Image(uiImage: first)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
                    .overlay {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                    }
            }
        }
    }
}

#Preview {
    HomeView()
}
