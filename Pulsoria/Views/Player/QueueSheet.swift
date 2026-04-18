import SwiftUI

// MARK: - Queue Sheet

struct QueueSheet: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if player.queue.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "list.bullet")
                            .font(.system(size: 60, weight: .thin))
                            .foregroundStyle(.secondary)
                        Text(Loc.emptyQueue)
                            .font(.custom(Loc.fontBold, size: 22))
                        Text(Loc.emptyQueueHint)
                            .font(.custom(Loc.fontMedium, size: 15))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // Now playing
                        if let current = player.currentTrack {
                            Section {
                                queueRow(track: current, isCurrent: true)
                            }
                        }

                        // Queue
                        Section(Loc.next) {
                            ForEach(Array(player.queue.enumerated()), id: \.element.id) { index, track in
                                queueRow(track: track, isCurrent: false)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                player.removeFromQueue(at: index)
                                            }
                                        } label: {
                                            Label(Loc.delete, systemImage: "trash")
                                        }
                                    }
                            }
                            .onMove { from, to in
                                player.queue.move(fromOffsets: from, toOffset: to)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(Loc.queue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Loc.done) { dismiss() }
                        .font(.custom(Loc.fontMedium, size: 15))
                }
            }
        }
    }

    private func queueRow(track: Track, isCurrent: Bool) -> some View {
        HStack(spacing: 12) {
            if let data = player.artworkCache[track.fileName],
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [theme.currentTheme.accent.opacity(0.4), theme.currentTheme.secondary.opacity(0.3)],
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
                    .font(.custom(Loc.fontMedium, size: 15))
                    .foregroundStyle(isCurrent ? theme.currentTheme.accent : .primary)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.custom(Loc.fontMedium, size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isCurrent {
                Image(systemName: "waveform")
                    .font(.caption)
                    .foregroundStyle(theme.currentTheme.accent)
            }
        }
        .padding(.vertical, 4)
    }
}

