import SwiftUI

/// Lets the host swap the currently-playing track without leaving the
/// room. Tapping a row immediately switches playback locally and writes
/// the new metadata into Firestore; the background upload of the new
/// audio file is kicked off by `ListeningRoomManager.hostSwitchTrack`.
struct HostTrackPickerSheet: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var rooms = ListeningRoomManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if player.tracks.isEmpty {
                    ContentUnavailableView(
                        Loc.importHint,
                        systemImage: "music.note",
                        description: Text(Loc.importHint)
                    )
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(player.tracks) { track in
                            Button {
                                select(track)
                            } label: {
                                HStack(spacing: 12) {
                                    artwork(for: track)
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(track.title)
                                            .font(.custom(Loc.fontMedium, size: 15))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Text(track.artist)
                                            .font(.custom(Loc.fontMedium, size: 12))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    if isCurrent(track) {
                                        Image(systemName: "waveform")
                                            .foregroundStyle(theme.currentTheme.accent)
                                            .symbolEffect(.pulse, options: .repeating)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text(Loc.pickTrackForRoom)
                    }
                }
            }
            .navigationTitle(theme.language == .russian ? "Сменить трек" : "Change track")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Loc.cancel) { dismiss() }
                }
            }
        }
    }

    private func isCurrent(_ track: Track) -> Bool {
        rooms.currentRoom?.playback.trackFileName == track.fileName
    }

    private func select(_ track: Track) {
        guard !isCurrent(track) else {
            dismiss()
            return
        }
        // Start locally so the host hears the switch immediately; the
        // room sync + Storage upload is handled by `hostSwitchTrack`.
        if let index = player.tracks.firstIndex(where: { $0.id == track.id }) {
            player.playTrack(at: index)
        }
        Task { try? await rooms.hostSwitchTrack(to: track) }
        dismiss()
    }

    @ViewBuilder
    private func artwork(for track: Track) -> some View {
        if let data = player.artworkCache[track.fileName],
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [theme.currentTheme.accent.opacity(0.4), theme.currentTheme.secondary.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Image(systemName: "music.note")
                        .foregroundStyle(.white.opacity(0.8))
                }
        }
    }
}
