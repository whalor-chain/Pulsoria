import SwiftUI

struct MusicSettingsView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var theme = ThemeManager.shared

    var body: some View {
        List {
            crossfadeSection
        }
        .contentMargins(.bottom, 80, for: .scrollContent)
        .navigationTitle(Loc.music)
    }

    private var crossfadeSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    HStack {
                        Text(Loc.crossfade)
                        Spacer()
                        Text(player.crossfadeDuration > 0 ? "\(Int(player.crossfadeDuration)) \(Loc.seconds)" : Loc.off)
                            .font(.custom(Loc.fontMedium, size: 15))
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: player.crossfadeDuration > 0 ? "apple.haptics.and.music.note" : "apple.haptics.and.music.note.slash")
                        .foregroundStyle(theme.currentTheme.accent)
                }

                Slider(
                    value: $player.crossfadeDuration,
                    in: 0...12,
                    step: 1
                )
                .tint(theme.currentTheme.accent)

                Text(Loc.crossfadeHint)
                    .font(.custom(Loc.fontMedium, size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
