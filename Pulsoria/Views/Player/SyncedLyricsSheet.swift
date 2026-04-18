import SwiftUI

// MARK: - Synced Lyrics Sheet

struct SyncedLyricsSheet: View {
    let lines: [SyncedLyricLine]
    let trackTitle: String
    let artistName: String
    @ObservedObject var player: AudioPlayerManager
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var currentLineIndex: Int = 0
    @State private var isDragging = false
    @State private var dragValue: TimeInterval = 0

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        theme.currentTheme.accent.opacity(0.6),
                        theme.currentTheme.secondary.opacity(0.4),
                        theme.currentTheme.accent.opacity(0.25),
                        Color(.systemBackground).opacity(0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 0) {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                                        Button {
                                            player.seek(to: line.time)
                                        } label: {
                                            Text(line.text)
                                                .font(.custom(Loc.fontBold, size: 24))
                                                .foregroundStyle(
                                                    index == currentLineIndex
                                                        ? .white
                                                        : index < currentLineIndex
                                                            ? .white.opacity(0.2)
                                                            : .white.opacity(0.4)
                                                )
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .lineSpacing(4)
                                        }
                                        .buttonStyle(.plain)
                                        .id(index)

                                        if index < lines.count - 1 {
                                            let gap = lines[index + 1].time - line.time
                                            if gap > 3.0 {
                                                Spacer().frame(height: 16)
                                            }
                                        }
                                    }
                                }

                                HStack {
                                    HStack(spacing: 4) {
                                        Circle().fill(.green).frame(width: 6, height: 6)
                                        Text("SYNCED")
                                            .font(.custom(Loc.fontBold, size: 10))
                                            .tracking(0.5)
                                    }
                                    .foregroundStyle(.green.opacity(0.5))

                                    Text(" · LRCLIB")
                                        .font(.custom(Loc.fontMedium, size: 12))
                                        .foregroundStyle(.white.opacity(0.3))
                                    Spacer()
                                }
                                .padding(.top, 24)
                                .padding(.bottom, 40)
                            }
                            .padding(.horizontal, 24)
                        }
                        .onChange(of: currentLineIndex) { _, newIndex in
                            withAnimation(.easeInOut(duration: 0.4)) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }

                    // Mini player controls
                    lyricsPlayerBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .onReceive(Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()) { _ in
            updateCurrentLine()
        }
    }

    private var lyricsPlayerBar: some View {
        VStack(spacing: 10) {
            // Track info
            HStack(spacing: 12) {
                if let data = player.artworkCache[player.currentTrack?.fileName ?? ""],
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.1))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(trackTitle)
                        .font(.custom(Loc.fontBold, size: 14))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(artistName)
                        .font(.custom(Loc.fontMedium, size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                }
                .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: player.isPlaying)
            }

            // Slider + time
            Slider(
                value: Binding(
                    get: { isDragging ? dragValue : player.currentTime },
                    set: { dragValue = $0 }
                ),
                in: 0...max(player.duration, 0.01)
            ) { editing in
                if editing {
                    isDragging = true
                } else {
                    player.seek(to: dragValue)
                    isDragging = false
                }
            }
            .tint(.white)

            HStack {
                Text(player.formatTime(isDragging ? dragValue : player.currentTime))
                    .font(.custom(Loc.fontMedium, size: 11).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text(player.formatTime(max(player.duration - (isDragging ? dragValue : player.currentTime), 0)))
                    .font(.custom(Loc.fontMedium, size: 11).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(Color.black.opacity(0.4))
    }

    private func updateCurrentLine() {
        let time = player.currentTime + 0.3
        var newIndex = 0
        for (i, line) in lines.enumerated() {
            if line.time <= time {
                newIndex = i
            } else {
                break
            }
        }
        if newIndex != currentLineIndex {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentLineIndex = newIndex
            }
        }
    }
}

