import SwiftUI

// MARK: - Lyrics Sheet

struct LyricsSheet: View {
    let lyrics: String
    let trackTitle: String
    let artistName: String
    /// Palette-driven tint pair, injected by PlayerView so the sheet
    /// background matches the current cover when cover-gradient is on.
    /// Defaults to nil → falls back to theme.
    var tintAccent: Color? = nil
    var tintSecondary: Color? = nil

    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isDragging = false
    @State private var dragValue: TimeInterval = 0

    private var accent: Color { tintAccent ?? theme.currentTheme.accent }
    private var secondary: Color { tintSecondary ?? theme.currentTheme.secondary }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        accent.opacity(0.6),
                        secondary.opacity(0.4),
                        accent.opacity(0.25),
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
                            .foregroundStyle(.white)
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
    /// Palette-driven tint pair for the card background. Defaults to
    /// theme so existing call-sites keep working; PlayerView passes
    /// `activeAccent` / `activeSecondary` to match the cover palette.
    var tintAccent: Color? = nil
    var tintSecondary: Color? = nil

    @ObservedObject var theme = ThemeManager.shared

    private var accent: Color { tintAccent ?? theme.currentTheme.accent }
    private var secondary: Color { tintSecondary ?? theme.currentTheme.secondary }

    /// Line-by-line width fractions — mimics real lyrics where each
    /// line is a different length, so the skeleton reads as "lyrics
    /// are about to appear" instead of "generic loading block".
    private let lineWidths: [CGFloat] = [0.9, 0.72, 0.86, 0.6]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "text.quote")
                    .font(.system(size: 13, weight: .bold))
                Text(Loc.lyrics)
                    .font(.custom(Loc.fontBold, size: 13))
                    .tracking(0.5)
                Spacer()
            }
            .foregroundStyle(.white.opacity(0.5))
            .textCase(.uppercase)
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(0..<4, id: \.self) { i in
                    Skeleton(cornerRadius: 6, fill: .white.opacity(0.18))
                        .frame(height: i == 0 ? 22 : 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .scaleEffect(x: lineWidths[i], y: 1, anchor: .leading)
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
                            accent.opacity(0.35),
                            secondary.opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
