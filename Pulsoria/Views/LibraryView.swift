import SwiftUI
import AVFoundation
import PhotosUI
import UniformTypeIdentifiers

enum LibraryMode: String, CaseIterable {
    case tracks, albums, artists, playlists

    var icon: String {
        switch self {
        case .tracks: return "music.note"
        case .artists: return "music.mic"
        case .albums: return "play.square.stack"
        case .playlists: return "music.pages"
        }
    }

    var label: String {
        switch self {
        case .tracks: return Loc.tracksTab
        case .artists: return Loc.artists
        case .albums: return Loc.albums
        case .playlists: return Loc.playlists
        }
    }
}

struct StagedImport: Identifiable {
    let id = UUID()
    let sourceURL: URL
    var title: String
    var artist: String
    let fileExtension: String
    let fileSize: String
    var fileDuration: String
    var artworkData: Data?
    var foundTitle: Bool = false
    var foundArtist: Bool = false
    var suggestedTitle: String? = nil
    var suggestedArtist: String? = nil
}

struct LibraryView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var playlistManager = PlaylistManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var genius = GeniusManager.shared
    @Namespace private var pickerNamespace
    @State private var searchText = ""
    @State private var selectedArtist: ArtistSelection?
    @State private var showFavoritesOnly = false
    @State private var showFavoriteArtistsOnly = false
    @State private var favoriteArtistNames: Set<String> = Set(UserDefaults.standard.stringArray(forKey: UserDefaultsKey.favoriteArtists) ?? [])
    @State private var favoriteAlbumNames: Set<String> = Set(UserDefaults.standard.stringArray(forKey: UserDefaultsKey.favoriteAlbums) ?? [])
    @State private var showFavoriteAlbumsOnly = false
    @State private var showFileImporter = false
    @State private var importError: String?
    @State private var showImportError = false
    @State private var libraryMode: LibraryMode = .tracks
    @State private var showCountBadge = false
    @State private var countBadgeTask: Task<Void, Never>?
    @State private var showNewPlaylistAlert = false
    @State private var newPlaylistName = ""
    @State private var showAddToPlaylistSheet = false
    @State private var trackToAdd: Track?
    @State private var albumTrack: Track?
    @State private var artistToOpen: String?
    @State private var shareTrack: Track?
    @State private var stagedImports: [StagedImport] = []
    @State private var showImportReview = false
    @State private var isSearching = false
    @FocusState private var isSearchFocused: Bool

    private var searchPrompt: String {
        switch libraryMode {
        case .tracks: return Loc.searchTracks
        case .artists: return Loc.searchArtists
        case .albums: return Loc.searchAlbums
        case .playlists: return Loc.searchPlaylists
        }
    }

    // MARK: - Custom Header

    private var libraryHeader: some View {
        VStack(spacing: 12) {
            if isSearching {
                librarySearchBar
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, isSearching ? 8 : 0)
    }

    private var librarySearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(searchPrompt, text: $searchText)
                .font(.custom(Loc.fontMedium, size: 15))
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(in: .capsule)
    }

    private var countLabel: String {
        let count = badgeCount(for: libraryMode)
        let ru = ThemeManager.shared.language == .russian
        switch libraryMode {
        case .tracks:
            return ru ? "\(count) треков" : "\(count) tracks"
        case .albums:
            return ru ? "\(count) альбомов" : "\(count) albums"
        case .artists:
            return ru ? "\(count) артистов" : "\(count) artists"
        case .playlists:
            return ru ? "\(count) плейлистов" : "\(count) playlists"
        }
    }

    private func badgeCount(for mode: LibraryMode) -> Int {
        switch mode {
        case .tracks: return player.tracks.count
        case .albums: return Set(genius.cachedAlbumNames.values).count
        case .artists: return Set(player.tracks.map(\.artist)).count
        case .playlists: return playlistManager.playlists.count
        }
    }

    private var libraryModePicker: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(LibraryMode.allCases, id: \.self) { mode in
                    let isSelected = libraryMode == mode
                    Button {
                        // Softer spring (matches SocialHub picker) so
                        // the glass pill glides between modes.
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
                            libraryMode = mode
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 10, weight: .medium))
                            Text(mode.label)
                                .font(.custom(
                                    isSelected ? Loc.fontBold : Loc.fontMedium,
                                    size: 12
                                ))
                                .lineLimit(1)
                        }
                        .foregroundStyle(
                            isSelected ? theme.currentTheme.accent : .secondary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        // Lock tap area before the glass clipping so
                        // the outer capsule's rounded corners don't
                        // nibble into the hit rectangle at the edges.
                        .contentShape(.rect)
                        .glassEffect(
                            isSelected
                                ? .regular.tint(theme.currentTheme.accent.opacity(0.2)).interactive()
                                : .identity,
                            in: .capsule
                        )
                        .glassEffectID(mode.rawValue, in: pickerNamespace)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .glassEffect(in: .capsule)
        }
        .sensoryFeedback(.selection, trigger: libraryMode)
    }

    private func swipeToChangeMode(_ direction: Int) {
        let allCases = LibraryMode.allCases
        guard let currentIndex = allCases.firstIndex(of: libraryMode) else { return }
        let newIndex = currentIndex.advanced(by: direction)
        guard allCases.indices.contains(newIndex) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            libraryMode = allCases[newIndex]
        }
    }

    private var filteredTracks: [Track] {
        var result = player.tracks

        if showFavoritesOnly {
            result = result.filter(\.isFavorite)
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.artist.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Group {
                    switch libraryMode {
                    case .tracks:
                        if player.tracks.isEmpty {
                            emptyState
                        } else if filteredTracks.isEmpty {
                            favoritesEmptyState(hint: Loc.noFavoriteTracksHint)
                        } else {
                            trackList
                        }
                    case .artists:
                        artistList
                    case .albums:
                        albumList
                    case .playlists:
                        playlistList
                    }
                }
                // Same spring as the picker pill (response 0.5,
                // damping 0.88) — pill-glide and content cross-fade
                // share one curve so they read as one gesture.
                .animation(.spring(response: 0.5, dampingFraction: 0.88), value: libraryMode)
            }
            .safeAreaInset(edge: .top) {
                VStack(spacing: 0) {
                    if isSearching {
                        librarySearchBar
                            .padding(.horizontal)
                            .padding(.bottom, 6)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    libraryModePicker
                        .padding(.horizontal)
                }
                .padding(.vertical, 6)
            }
            .overlay(alignment: .top) {
                if showCountBadge {
                    Text(countLabel)
                        .font(.custom(Loc.fontMedium, size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .glassEffect(in: .capsule)
                        .transition(.opacity)
                        .padding(.top, isSearching ? 110 : 60)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showCountBadge)
            .onChange(of: libraryMode) {
                countBadgeTask?.cancel()
                withAnimation {
                    showCountBadge = true
                }
                countBadgeTask = Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    if !Task.isCancelled {
                        withAnimation {
                            showCountBadge = false
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isSearching.toggle()
                            if isSearching {
                                isSearchFocused = true
                            } else {
                                isSearchFocused = false
                                searchText = ""
                            }
                        }
                    } label: {
                        Image(systemName: isSearching ? "xmark" : "magnifyingglass")
                            .foregroundStyle(theme.currentTheme.accent)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }

                ToolbarItem(placement: .principal) {
                    Image("LibraryLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 52)
                        .foregroundStyle(theme.currentTheme.accent)
                }

                if libraryMode != .playlists {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            if libraryMode == .tracks {
                                withAnimation { showFavoritesOnly.toggle() }
                            } else if libraryMode == .artists {
                                withAnimation { showFavoriteArtistsOnly.toggle() }
                            } else if libraryMode == .albums {
                                withAnimation { showFavoriteAlbumsOnly.toggle() }
                            }
                        } label: {
                            let isFav: Bool = {
                                switch libraryMode {
                                case .tracks: return showFavoritesOnly
                                case .artists: return showFavoriteArtistsOnly
                                case .albums: return showFavoriteAlbumsOnly
                                case .playlists: return false
                                }
                            }()
                            Image(systemName: isFav ? "heart.fill" : "heart")
                                .foregroundStyle(isFav ? .pink : theme.currentTheme.accent)
                        }
                    }
                }

                if libraryMode == .tracks || libraryMode == .playlists {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            if libraryMode == .tracks {
                                showFileImporter = true
                            } else if libraryMode == .playlists {
                                showNewPlaylistAlert = true
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel(
                            libraryMode == .playlists ? Loc.newPlaylist : Loc.a11yImportMusic
                        )
                    }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.audio, .mp3, .mpeg4Audio, .wav, .aiff],
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result)
            }
            .alert(Loc.importError, isPresented: $showImportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importError ?? "Unknown error")
            }
            .alert(Loc.newPlaylist, isPresented: $showNewPlaylistAlert) {
                TextField(Loc.playlistName, text: $newPlaylistName)
                Button(Loc.cancel, role: .cancel) {
                    newPlaylistName = ""
                }
                Button(Loc.create) {
                    let name = newPlaylistName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty {
                        playlistManager.createPlaylist(name: name)
                    }
                    newPlaylistName = ""
                }
            } message: {
                Text(Loc.enterPlaylistName)
            }
            .sheet(isPresented: $showAddToPlaylistSheet) {
                AddToPlaylistSheet(track: trackToAdd)
            }
            .sheet(isPresented: $showImportReview) {
                ImportReviewSheet(stagedImports: $stagedImports) {
                    for item in stagedImports {
                        player.importTrack(
                            from: item.sourceURL,
                            title: item.title,
                            artist: item.artist,
                            artworkData: item.artworkData
                        )
                    }
                    stagedImports.removeAll()
                }
            }
            .navigationDestination(item: $albumTrack) { track in
                AlbumDetailView(track: track)
            }
            .navigationDestination(item: $artistToOpen) { artistName in
                if let track = player.tracks.first(where: {
                    $0.artist.lowercased().contains(artistName.lowercased())
                }) {
                    ArtistPageView(artistName: artistName, initialTrack: track)
                }
            }
            .sheet(item: $shareTrack) { track in
                SharePreviewSheet(
                    track: track,
                    artwork: {
                        if let data = player.artworkCache[track.fileName] {
                            return UIImage(data: data)
                        }
                        return nil
                    }()
                )
            }
            .onAppear {
                favoriteArtistNames = Set(UserDefaults.standard.stringArray(forKey: UserDefaultsKey.favoriteArtists) ?? [])
                favoriteAlbumNames = Set(UserDefaults.standard.stringArray(forKey: UserDefaultsKey.favoriteAlbums) ?? [])
            }
        }
    }

    // MARK: - File Import

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            // Grab security access on main thread, then move everything to background
            var accessedURLs: [(url: URL, ext: String, scoped: Bool)] = []
            for url in urls {
                let scoped = url.startAccessingSecurityScopedResource()
                // Include even if not scoped (e.g. shared extension temp files)
                accessedURLs.append((url: url, ext: url.pathExtension, scoped: scoped))
            }
            guard !accessedURLs.isEmpty else { return }

            DispatchQueue.global(qos: .userInitiated).async {
                var staged: [StagedImport] = []

                for item in accessedURLs {
                    let url = item.url

                    // Parse name from filename
                    let rawName = url.deletingPathExtension().lastPathComponent
                    // Clean: replace underscores with spaces, remove trailing numbers (download IDs)
                    var cleaned = rawName.replacingOccurrences(of: "_", with: " ")
                    // Remove trailing numeric IDs like " 79494233" (8+ digits only)
                    if let range = cleaned.range(of: #"\s+\d{8,}$"#, options: .regularExpression) {
                        cleaned.removeSubrange(range)
                    }
                    // Remove common bracket/paren suffixes like "(1)", "[Official Audio]"
                    cleaned = cleaned.replacingOccurrences(of: #"\s*[\(\[].*?[\)\]]"#, with: "", options: .regularExpression)
                    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

                    let parts = cleaned.components(separatedBy: " - ")
                    let artist = parts.count > 1
                        ? parts[0].trimmingCharacters(in: .whitespaces)
                        : ""
                    let title = parts.count > 1
                        ? parts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespaces)
                        : cleaned

                    // File size
                    let fileSize: String
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                       let size = attrs[.size] as? Int64 {
                        let mb = Double(size) / 1_048_576
                        fileSize = String(format: "%.1f MB", mb)
                    } else {
                        fileSize = "—"
                    }

                    // Copy to temp (skip if already in temp dir)
                    let tempURL: URL
                    if url.path.hasPrefix(FileManager.default.temporaryDirectory.path) {
                        tempURL = url
                    } else {
                        tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                        try? FileManager.default.removeItem(at: tempURL)
                        try? FileManager.default.copyItem(at: url, to: tempURL)
                    }

                    if item.scoped {
                        url.stopAccessingSecurityScopedResource()
                    }

                    // Load duration, metadata & artwork synchronously on background thread
                    let asset = AVURLAsset(url: tempURL)
                    var fileDuration = "0:00"
                    var artworkData: Data? = nil
                    var metaTitle: String? = nil
                    var metaArtist: String? = nil

                    let group = DispatchGroup()
                    group.enter()
                    Task.detached(priority: .userInitiated) {
                        if let dur = try? await asset.load(.duration) {
                            let sec = CMTimeGetSeconds(dur)
                            let mins = Int(sec) / 60
                            let secs = Int(sec) % 60
                            fileDuration = String(format: "%d:%02d", mins, secs)
                        }
                        if let meta = try? await asset.load(.commonMetadata) {
                            // Title from metadata
                            let titleItems = AVMetadataItem.metadataItems(from: meta, filteredByIdentifier: .commonIdentifierTitle)
                            if let titleItem = titleItems.first, let str = try? await titleItem.load(.stringValue), !str.isEmpty {
                                metaTitle = str
                            }
                            // Artist from metadata
                            let artistItems = AVMetadataItem.metadataItems(from: meta, filteredByIdentifier: .commonIdentifierArtist)
                            if let artistItem = artistItems.first, let str = try? await artistItem.load(.stringValue), !str.isEmpty {
                                metaArtist = str.replacingOccurrences(of: "/", with: ", ")
                            }
                            // Artwork
                            let artworkItems = AVMetadataItem.metadataItems(from: meta, filteredByIdentifier: .commonIdentifierArtwork)
                            if let artItem = artworkItems.first, let data = try? await artItem.load(.dataValue) {
                                artworkData = data
                            }
                        }
                        // If no embedded artwork, try fetching from Genius
                        let finalTitle = metaTitle ?? title
                        let finalArtist = metaArtist ?? artist
                        if artworkData == nil && !finalTitle.isEmpty {
                            artworkData = await GeniusManager.shared.fetchSongArtworkData(title: finalTitle, artist: finalArtist)
                        }
                        group.leave()
                    }
                    group.wait()

                    let finalTitle = metaTitle ?? title
                    let finalArtist = metaArtist ?? artist
                    let foundTitle = metaTitle != nil || parts.count > 1
                    let foundArtist = metaArtist != nil || (parts.count > 1 && !artist.isEmpty)

                    // Search Genius for suggestion (skip if both found in metadata)
                    var sugTitle: String? = nil
                    var sugArtist: String? = nil
                    let skipSuggestion = metaTitle != nil && metaArtist != nil
                    // Token comes from `AppSecrets.plist` (gitignored) —
                    // old hardcoded literal was rotated out in Apr 2026.
                    let geniusToken = AppSecrets.geniusToken
                    let searchQuery = "\(finalTitle) \(finalArtist)".trimmingCharacters(in: .whitespaces)
                    let sugGroup = DispatchGroup()
                    sugGroup.enter()
                    Task.detached(priority: .userInitiated) {
                        if !skipSuggestion, !searchQuery.isEmpty,
                           let encoded = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                           let url = URL(string: "https://api.genius.com/search?q=\(encoded)") {
                            var request = URLRequest(url: url)
                            request.setValue("Bearer \(geniusToken)", forHTTPHeaderField: "Authorization")
                            if let (data, _) = try? await URLSession.shared.data(for: request),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let response = json["response"] as? [String: Any],
                               let hits = response["hits"] as? [[String: Any]],
                               let firstHit = hits.first,
                               let result = firstHit["result"] as? [String: Any] {
                                let gTitle = result["title"] as? String
                                let primaryArtist = result["primary_artist"] as? [String: Any]
                                let gArtist = primaryArtist?["name"] as? String

                                // Normalize for comparison: lowercase, trim, remove punctuation
                                func normalize(_ s: String) -> String {
                                    s.lowercased()
                                     .trimmingCharacters(in: .whitespacesAndNewlines)
                                     .replacingOccurrences(of: "[^a-zа-яё0-9 ]", with: "", options: .regularExpression)
                                }

                                if let gt = gTitle, normalize(gt) != normalize(finalTitle) {
                                    sugTitle = gt
                                }
                                if let ga = gArtist, normalize(ga) != normalize(finalArtist) {
                                    sugArtist = ga
                                }
                                // Always suggest artist if current is empty
                                if finalArtist.trimmingCharacters(in: .whitespaces).isEmpty, let ga = gArtist, !ga.isEmpty {
                                    sugArtist = ga
                                }
                            }
                        }
                        sugGroup.leave()
                    }
                    sugGroup.wait()

                    staged.append(StagedImport(
                        sourceURL: tempURL,
                        title: finalTitle,
                        artist: finalArtist,
                        fileExtension: item.ext,
                        fileSize: fileSize,
                        fileDuration: fileDuration,
                        artworkData: artworkData,
                        foundTitle: foundTitle,
                        foundArtist: foundArtist,
                        suggestedTitle: sugTitle,
                        suggestedArtist: sugArtist
                    ))
                }

                // Show sheet on main thread with delay for fileImporter dismissal
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if !staged.isEmpty {
                        stagedImports = staged
                        showImportReview = true
                    }
                }
            }

        case .failure(let error):
            importError = error.localizedDescription
            showImportError = true
        }
    }

    // MARK: - Track List

    private var trackList: some View {
        List {
            ForEach(filteredTracks) { track in
                TrackRow(
                    track: track,
                    isCurrentTrack: track.id == player.currentTrack?.id,
                    isPlaying: track.id == player.currentTrack?.id && player.isPlaying,
                    onTap: {
                        if let actualIndex = player.tracks.firstIndex(where: { $0.id == track.id }) {
                            player.playingSource = Loc.library
                            player.playTrack(at: actualIndex)
                        }
                    },
                    onAddToPlaylist: {
                        trackToAdd = track
                        showAddToPlaylistSheet = true
                    },
                    onOpenAlbum: {
                        albumTrack = track
                    },
                    onOpenArtist: {
                        let artist = track.artist.components(separatedBy: ",").first?
                            .trimmingCharacters(in: .whitespaces) ?? track.artist
                        artistToOpen = artist
                    },
                    onShare: {
                        shareTrack = track
                    }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation {
                            player.deleteTrack(track)
                        }
                    } label: {
                        Label(Loc.delete, systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        player.addToQueue(track)
                    } label: {
                        Label(Loc.addToQueue, systemImage: "text.line.last.and.arrowtriangle.forward")
                    }
                    .tint(.orange)

                    Button {
                        trackToAdd = track
                        showAddToPlaylistSheet = true
                    } label: {
                        Label(Loc.addToPlaylist, systemImage: "text.badge.plus")
                    }
                    .tint(theme.currentTheme.accent)
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 80, for: .scrollContent)
    }

    // MARK: - Artist List

    private var uniqueArtists: [String] {
        var seen = Set<String>()
        var result: [String] = []

        for track in player.tracks {
            let names = track.artist
                .replacingOccurrences(of: " & ", with: ",")
                .replacingOccurrences(of: " feat. ", with: ",")
                .replacingOccurrences(of: " feat ", with: ",")
                .replacingOccurrences(of: " ft. ", with: ",")
                .replacingOccurrences(of: " ft ", with: ",")
                .replacingOccurrences(of: " x ", with: ",")
                .replacingOccurrences(of: " X ", with: ",")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            for name in names {
                let key = name.lowercased()
                if !seen.contains(key) {
                    seen.insert(key)
                    result.append(name)
                }
            }
        }

        // Filter by search
        if !searchText.isEmpty {
            result = result.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }

        // Filter favorites only
        if showFavoriteArtistsOnly {
            result = result.filter { favoriteArtistNames.contains($0.lowercased()) }
        }

        // Favorites first, then alphabetical
        return result.sorted { a, b in
            let aFav = favoriteArtistNames.contains(a.lowercased())
            let bFav = favoriteArtistNames.contains(b.lowercased())
            if aFav != bFav { return aFav }
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }
    }

    private func toggleFavoriteArtist(_ name: String) {
        let key = name.lowercased()
        if favoriteArtistNames.contains(key) {
            favoriteArtistNames.remove(key)
        } else {
            favoriteArtistNames.insert(key)
        }
        UserDefaults.standard.set(Array(favoriteArtistNames), forKey: UserDefaultsKey.favoriteArtists)
    }

    private func toggleFavoriteAlbum(_ name: String) {
        let key = name.lowercased()
        if favoriteAlbumNames.contains(key) {
            favoriteAlbumNames.remove(key)
        } else {
            favoriteAlbumNames.insert(key)
        }
        UserDefaults.standard.set(Array(favoriteAlbumNames), forKey: UserDefaultsKey.favoriteAlbums)
    }

    private func trackCount(for artist: String) -> Int {
        let name = artist.lowercased()
        return player.tracks.filter { $0.artist.lowercased().contains(name) }.count
    }

    private var artistList: some View {
        Group {
            if player.tracks.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "music.mic")
                        .font(.system(size: 60, weight: .thin))
                        .foregroundStyle(.secondary)
                    Text(Loc.noArtists)
                        .font(.custom(Loc.fontBold, size: 22))
                    Text(Loc.noArtistsHint)
                        .font(.custom(Loc.fontMedium, size: 15))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if uniqueArtists.isEmpty {
                favoritesEmptyState(hint: Loc.noFavoriteArtistsHint)
            } else {
                List {
                    ForEach(uniqueArtists, id: \.self) { artist in
                        NavigationLink {
                            if let track = player.tracks.first(where: {
                                $0.artist.lowercased().contains(artist.lowercased())
                            }) {
                                ArtistPageView(artistName: artist, initialTrack: track)
                            }
                        } label: {
                            ArtistRowView(
                                name: artist,
                                trackCount: trackCount(for: artist),
                                isFavorite: favoriteArtistNames.contains(artist.lowercased()),
                                onFavorite: { toggleFavoriteArtist(artist) }
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .contentMargins(.bottom, 80, for: .scrollContent)
            }
        }
    }

    // MARK: - Album List

    private var uniqueAlbums: [(name: String, artist: String, trackCount: Int, artwork: Data?, track: Track)] {
        let genius = GeniusManager.shared
        var albumMap: [String: (artist: String, count: Int, artwork: Data?, track: Track)] = [:]

        for track in player.tracks {
            if let albumName = genius.cachedAlbumNames[track.fileName], !albumName.isEmpty {
                let key = albumName.lowercased()
                if var existing = albumMap[key] {
                    existing.count += 1
                    albumMap[key] = existing
                } else {
                    // Use primary artist from Genius (album owner), fallback to track artist
                    let albumArtist = genius.cachedAlbumArtist[key] ?? track.artist
                    let artworkData = player.artworkCache[track.fileName]
                    albumMap[key] = (artist: albumArtist, count: 1, artwork: artworkData, track: track)
                }
            }
        }

        var result: [(name: String, artist: String, trackCount: Int, artwork: Data?, track: Track)]
        result = albumMap.map { key, val in
            let name = GeniusManager.shared.cachedAlbumNames.values.first(where: { $0.lowercased() == key }) ?? key
            return (name: name, artist: val.artist, trackCount: val.count, artwork: val.artwork, track: val.track)
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) || $0.artist.lowercased().contains(query)
            }
        }

        if showFavoriteAlbumsOnly {
            result = result.filter { favoriteAlbumNames.contains($0.name.lowercased()) }
        }

        return result.sorted {
            let aFav = favoriteAlbumNames.contains($0.name.lowercased())
            let bFav = favoriteAlbumNames.contains($1.name.lowercased())
            if aFav != bFav { return aFav }
            return $0.name.lowercased() < $1.name.lowercased()
        }
    }

    private var albumList: some View {
        Group {
            if player.tracks.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "play.square.stack")
                        .font(.system(size: 60, weight: .thin))
                        .foregroundStyle(.secondary)
                    Text(Loc.noAlbums)
                        .font(.custom(Loc.fontBold, size: 22))
                    Text(Loc.noAlbumsHint)
                        .font(.custom(Loc.fontMedium, size: 15))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if uniqueAlbums.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "play.square.stack")
                        .font(.system(size: 60, weight: .thin))
                        .foregroundStyle(.secondary)
                    Text(Loc.noAlbumsFound)
                        .font(.custom(Loc.fontBold, size: 22))
                    Text(Loc.noAlbumsFoundHint)
                        .font(.custom(Loc.fontMedium, size: 15))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(uniqueAlbums, id: \.name) { album in
                        NavigationLink {
                            AlbumDetailView(track: album.track)
                        } label: {
                            HStack(spacing: 14) {
                                if let data = album.artwork, let img = UIImage(data: data) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 56, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                } else {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 56, height: 56)
                                        .overlay {
                                            Image(systemName: "play.square.stack")
                                                .font(.title2)
                                                .foregroundStyle(.secondary)
                                        }
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(album.name)
                                        .font(.custom(Loc.fontBold, size: 16))
                                        .lineLimit(1)
                                    Text("\(album.artist) · \(album.trackCount) \(album.trackCount == 1 ? Loc.trackSingular : Loc.trackPlural)")
                                        .font(.custom(Loc.fontMedium, size: 13))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .contentMargins(.bottom, 80, for: .scrollContent)
            }
        }
    }

    // MARK: - Playlist List

    private var playlistList: some View {
        Group {
            if playlistManager.playlists.isEmpty {
                VStack(spacing: 20) {
                    Spacer()

                    Image(systemName: "music.note.list")
                        .font(.system(size: 60, weight: .thin))
                        .foregroundStyle(.secondary)

                    Text(Loc.noPlaylists)
                        .font(.custom(Loc.fontBold, size: 22))
                        .foregroundStyle(.primary)

                    Text(Loc.noPlaylistsHint)
                        .font(.custom(Loc.fontMedium, size: 15))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    GlassEffectContainer {
                        Button {
                            showNewPlaylistAlert = true
                        } label: {
                            Label(Loc.newPlaylist, systemImage: "plus.circle.fill")
                                .font(.custom(Loc.fontBold, size: 17))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.glass)
                        .tint(theme.currentTheme.accent)
                        .sensoryFeedback(.impact(flexibility: .soft), trigger: showNewPlaylistAlert)
                    }
                    .padding(.top, 4)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(playlistManager.playlists) { playlist in
                        NavigationLink {
                            PlaylistDetailView(playlist: playlist)
                        } label: {
                            PlaylistRowView(
                                name: playlist.name,
                                trackCount: playlistManager.resolvedTracks(for: playlist, from: player.tracks).count,
                                iconName: "music.note.list",
                                iconColor: .white.opacity(0.7)
                            )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    playlistManager.deletePlaylist(playlist)
                                }
                            } label: {
                                Label(Loc.delete, systemImage: "trash")
                            }
                        }
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .contentMargins(.bottom, 80, for: .scrollContent)
            }
        }
    }

    // MARK: - Favorites Empty State

    private func favoritesEmptyState(hint: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "heart.slash")
                .font(.system(size: 60, weight: .thin))
                .foregroundStyle(.secondary)

            Text(Loc.noFavorites)
                .font(.custom(Loc.fontBold, size: 22))

            Text(hint)
                .font(.custom(Loc.fontMedium, size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "music.note.house")
                .font(.system(size: 60, weight: .thin))
                .foregroundStyle(.secondary)

            Text(Loc.noTracksYet)
                .font(.custom(Loc.fontBold, size: 22))

            Text(Loc.importHint)
                .font(.custom(Loc.fontMedium, size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
