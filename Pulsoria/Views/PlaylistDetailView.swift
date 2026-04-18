import SwiftUI

struct PlaylistDetailView: View {
    let playlist: Playlist
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var playlistManager = PlaylistManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @State private var showRenameAlert = false
    @State private var renameText = ""

    private var playlistTracks: [Track] {
        playlistManager.resolvedTracks(for: playlist, from: player.tracks)
    }

    var body: some View {
        Group {
            if playlistTracks.isEmpty {
                emptyPlaylistState
            } else {
                trackList
            }
        }
        .navigationTitle(playlist.isAutoFavorites ? Loc.favoriteTracks : playlist.name)
        .toolbar {
            if !playlist.isAutoFavorites {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            renameText = playlist.name
                            showRenameAlert = true
                        } label: {
                            Label(Loc.rename, systemImage: "pencil")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .alert(Loc.rename, isPresented: $showRenameAlert) {
            TextField(Loc.playlistName, text: $renameText)
            Button(Loc.cancel, role: .cancel) { }
            Button(Loc.done) {
                let name = renameText.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    playlistManager.renamePlaylist(playlist, to: name)
                }
            }
        }
    }

    // MARK: - Track List

    private var trackList: some View {
        List {
            ForEach(playlistTracks) { track in
                TrackRow(
                    track: track,
                    isCurrentTrack: track.id == player.currentTrack?.id,
                    isPlaying: track.id == player.currentTrack?.id && player.isPlaying,
                    onTap: {
                        if let index = player.tracks.firstIndex(where: { $0.id == track.id }) {
                            player.playingSource = playlist.name
                            player.playTrack(at: index)
                        }
                    }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if !playlist.isAutoFavorites {
                        Button(role: .destructive) {
                            withAnimation {
                                playlistManager.removeTrack(track, from: playlist)
                            }
                        } label: {
                            Label(Loc.removeFromPlaylist, systemImage: "minus.circle")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .contentMargins(.bottom, 80, for: .scrollContent)
    }

    // MARK: - Empty State

    private var emptyPlaylistState: some View {
        VStack(spacing: 16) {
            Image(systemName: playlist.isAutoFavorites ? "heart.slash" : "music.note.list")
                .font(.system(size: 60, weight: .thin))
                .foregroundStyle(.secondary)

            Text(Loc.emptyPlaylist)
                .font(.custom(Loc.fontBold, size: 22))
                .foregroundStyle(.primary)

            Text(Loc.emptyPlaylistHint)
                .font(.custom(Loc.fontMedium, size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
