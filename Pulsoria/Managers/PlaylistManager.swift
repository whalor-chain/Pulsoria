import SwiftUI
import Combine

@MainActor
class PlaylistManager: ObservableObject {
    static let shared = PlaylistManager()

    @Published var playlists: [Playlist] = []

    

    private init() {
        loadPlaylists()
    }

    // MARK: - Persistence

    private func loadPlaylists() {
        guard let data = UserDefaults.standard.data(forKey: UserDefaultsKey.userPlaylists),
              let decoded = try? JSONDecoder().decode([Playlist].self, from: data) else {
            return
        }
        playlists = decoded
    }

    private func savePlaylists() {
        let userPlaylists = playlists.filter { !$0.isAutoFavorites }
        if let data = try? JSONEncoder().encode(userPlaylists) {
            UserDefaults.standard.set(data, forKey: UserDefaultsKey.userPlaylists)
        }
    }

    // MARK: - CRUD

    func createPlaylist(name: String) {
        let playlist = Playlist(name: name)
        playlists.append(playlist)
        savePlaylists()
    }

    func renamePlaylist(_ playlist: Playlist, to newName: String) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[index].name = newName
        savePlaylists()
    }

    func deletePlaylist(_ playlist: Playlist) {
        guard !playlist.isAutoFavorites else { return }
        playlists.removeAll { $0.id == playlist.id }
        savePlaylists()
    }

    // MARK: - Track Management

    func addTrack(_ track: Track, to playlist: Playlist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }),
              !playlists[index].trackFileNames.contains(track.fileName) else { return }
        playlists[index].trackFileNames.append(track.fileName)
        savePlaylists()
    }

    func removeTrack(_ track: Track, from playlist: Playlist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[index].trackFileNames.removeAll { $0 == track.fileName }
        savePlaylists()
    }

    // MARK: - Resolve

    func resolvedTracks(for playlist: Playlist, from allTracks: [Track]) -> [Track] {
        if playlist.isAutoFavorites {
            return allTracks.filter(\.isFavorite)
        }
        return playlist.trackFileNames.compactMap { fileName in
            allTracks.first { $0.fileName == fileName }
        }
    }

    // MARK: - Favorites Playlist

    private static let favoritesID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    func favoritesPlaylist() -> Playlist {
        Playlist(
            id: Self.favoritesID,
            name: Loc.favoriteTracks,
            trackFileNames: [],
            isAutoFavorites: true
        )
    }

    func allPlaylistsForDisplay() -> [Playlist] {
        [favoritesPlaylist()] + playlists
    }
}
