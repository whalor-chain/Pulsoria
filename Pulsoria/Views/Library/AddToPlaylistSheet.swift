import SwiftUI

struct AddToPlaylistSheet: View {
    let track: Track?
    @ObservedObject var playlistManager = PlaylistManager.shared
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showNewPlaylistAlert = false
    @State private var newPlaylistName = ""

    var body: some View {
        NavigationStack {
            Group {
                if playlistManager.playlists.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 60, weight: .thin))
                            .foregroundStyle(.secondary)

                        Text(Loc.noPlaylists)
                            .font(.custom(Loc.fontBold, size: 22))

                        Text(Loc.noPlaylistsHint)
                            .font(.custom(Loc.fontMedium, size: 15))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button {
                            showNewPlaylistAlert = true
                        } label: {
                            Label(Loc.newPlaylist, systemImage: "plus.circle.fill")
                                .font(.custom(Loc.fontBold, size: 17))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.currentTheme.accent)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(playlistManager.playlists) { playlist in
                            Button {
                                if let track = track {
                                    playlistManager.addTrack(track, to: playlist)
                                }
                                dismiss()
                            } label: {
                                HStack {
                                    PlaylistRowView(
                                        name: playlist.name,
                                        trackCount: playlistManager.resolvedTracks(for: playlist, from: player.tracks).count,
                                        iconName: "music.note.list",
                                        iconColor: .white.opacity(0.7)
                                    )

                                    if let track = track,
                                       playlist.trackFileNames.contains(track.fileName) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(theme.currentTheme.accent)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(Loc.selectPlaylist)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(Loc.cancel) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewPlaylistAlert = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert(Loc.newPlaylist, isPresented: $showNewPlaylistAlert) {
                TextField(Loc.playlistName, text: $newPlaylistName)
                Button(Loc.cancel, role: .cancel) { newPlaylistName = "" }
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
        }
        .presentationDetents([.medium, .large])
    }
}

