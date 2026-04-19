import SwiftUI

/// Host picks one of their local tracks and spins up a room around it.
struct CreateRoomSheet: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var rooms = ListeningRoomManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTrack: Track?
    @State private var isCreating = false
    @State private var errorMessage: String?

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
                                selectedTrack = track
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
                                    if selectedTrack?.id == track.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(theme.currentTheme.accent)
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
            .navigationTitle(Loc.startRoom)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(Loc.cancel) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        guard let track = selectedTrack else { return }
                        createRoom(for: track)
                    } label: {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text(Loc.startRoom)
                                .font(.custom(Loc.fontBold, size: 15))
                        }
                    }
                    .disabled(selectedTrack == nil || isCreating)
                }
            }
            .alert(Loc.errorTitle, isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ), presenting: errorMessage) { _ in
                Button("OK", role: .cancel) { }
            } message: { message in
                Text(message)
            }
        }
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

    private func createRoom(for track: Track) {
        isCreating = true
        Task {
            do {
                _ = try await rooms.createRoom(for: track)
                // Start the host's own playback of this track so others can sync.
                if let index = player.tracks.firstIndex(where: { $0.id == track.id }) {
                    player.playTrack(at: index)
                }
                isCreating = false
                dismiss()
            } catch {
                isCreating = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
