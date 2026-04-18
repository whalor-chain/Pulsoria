import Testing
import Foundation
@testable import Pulsoria

@MainActor
struct PlaylistManagerTests {

    // MARK: - Fixtures

    private func makeTrack(
        title: String,
        fileName: String,
        isFavorite: Bool = false
    ) -> Track {
        Track(
            title: title,
            artist: "Tester",
            fileName: fileName,
            fileExtension: "mp3",
            isFavorite: isFavorite
        )
    }

    // MARK: - resolvedTracks

    @Test func resolvedTracksLooksUpByFileName() {
        let manager = PlaylistManager.shared
        let all: [Track] = [
            makeTrack(title: "A", fileName: "file-a"),
            makeTrack(title: "B", fileName: "file-b"),
            makeTrack(title: "C", fileName: "file-c")
        ]
        let playlist = Playlist(name: "Mix", trackFileNames: ["file-c", "file-a"])
        let resolved = manager.resolvedTracks(for: playlist, from: all)

        #expect(resolved.map(\.fileName) == ["file-c", "file-a"])
    }

    @Test func resolvedTracksSkipsMissingFileNames() {
        let manager = PlaylistManager.shared
        let all: [Track] = [makeTrack(title: "Only", fileName: "kept")]
        let playlist = Playlist(name: "Ghosts", trackFileNames: ["deleted", "kept", "gone"])

        let resolved = manager.resolvedTracks(for: playlist, from: all)
        #expect(resolved.map(\.fileName) == ["kept"])
    }

    @Test func resolvedTracksForFavoritesIgnoresFileNames() {
        let manager = PlaylistManager.shared
        let all: [Track] = [
            makeTrack(title: "A", fileName: "a", isFavorite: true),
            makeTrack(title: "B", fileName: "b", isFavorite: false),
            makeTrack(title: "C", fileName: "c", isFavorite: true)
        ]
        // Auto-favorites playlist ignores trackFileNames and uses isFavorite.
        let favorites = Playlist(name: "Favs", trackFileNames: ["b"], isAutoFavorites: true)
        let resolved = manager.resolvedTracks(for: favorites, from: all)

        #expect(Set(resolved.map(\.fileName)) == ["a", "c"])
    }

    // MARK: - favoritesPlaylist

    @Test func favoritesPlaylistHasStableID() {
        let manager = PlaylistManager.shared
        let first = manager.favoritesPlaylist()
        let second = manager.favoritesPlaylist()
        #expect(first.id == second.id)
        #expect(first.isAutoFavorites)
        #expect(second.isAutoFavorites)
    }

    // MARK: - allPlaylistsForDisplay

    @Test func allPlaylistsForDisplayPutsFavoritesFirst() {
        let manager = PlaylistManager.shared
        let all = manager.allPlaylistsForDisplay()
        #expect(all.first?.isAutoFavorites == true)
    }

    // MARK: - Playlist equality

    @Test func playlistEqualityIsIDBased() {
        let id = UUID()
        let a = Playlist(id: id, name: "Original", trackFileNames: ["x"])
        let b = Playlist(id: id, name: "Renamed", trackFileNames: ["y", "z"])
        #expect(a == b)
    }

    @Test func playlistDefaultsAreEmpty() {
        let p = Playlist(name: "Empty")
        #expect(p.trackFileNames.isEmpty)
        #expect(!p.isAutoFavorites)
    }
}
