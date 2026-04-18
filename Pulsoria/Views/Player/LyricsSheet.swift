import SwiftUI

// MARK: - Lyrics Sheet

struct LyricsSheet: View {
    let lyrics: String
    let trackTitle: String
    let artistName: String
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
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
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            lyricsContent

                            HStack {
                                Text("Genius")
                                    .font(.custom(Loc.fontMedium, size: 12))
                                    .foregroundStyle(.white.opacity(0.3))
                                Spacer()
                            }
                            .padding(.top, 24)
                            .padding(.bottom, 40)
                        }
                        .padding(.horizontal, 24)
                    }

                    // Mini player controls
                    VStack(spacing: 10) {
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
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var lyricsContent: some View {
        let lines = lyrics.components(separatedBy: "\n")

        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    Spacer()
                        .frame(height: 14)
                } else if line.hasPrefix("[") && line.hasSuffix("]") {
                    Text(line)
                        .font(.custom(Loc.fontBold, size: 14))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.top, 8)
                } else {
                    Text(line)
                        .font(.custom(Loc.fontBold, size: 24))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineSpacing(4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Lyrics Loading Animation

struct LyricsLoadingView: View {
    @ObservedObject var theme = ThemeManager.shared
    @State private var pulse = false

    private let lineWidths: [CGFloat] = [0.9, 0.7, 0.85, 0.6]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "text.quote")
                    .font(.system(size: 13, weight: .bold))
                Text(Loc.lyrics)
                    .font(.custom(Loc.fontBold, size: 13))
                    .tracking(0.5)
                Spacer()
                ProgressView()
                    .tint(.white.opacity(0.4))
                    .scaleEffect(0.8)
            }
            .foregroundStyle(.white.opacity(0.5))
            .textCase(.uppercase)
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(pulse ? 0.15 : 0.06))
                        .frame(height: i == 0 ? 22 : 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .scaleEffect(x: lineWidths[i], y: 1, anchor: .leading)
                        .animation(
                            .easeInOut(duration: 1.0)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: pulse
                        )
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            theme.currentTheme.accent.opacity(0.35),
                            theme.currentTheme.secondary.opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onAppear { pulse = true }
    }
}
