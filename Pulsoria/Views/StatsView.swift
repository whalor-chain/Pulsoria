import SwiftUI

struct StatsView: View {
    @ObservedObject var stats = StatsManager.shared
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var playlists = PlaylistManager.shared

    @State private var selectedSection: StatsSection = .dna

    var isRu: Bool { ThemeManager.shared.language == .russian }

    enum StatsSection: String, CaseIterable {
        case dna, achievements
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                sectionPicker
                    .padding(.horizontal)

                if selectedSection == .dna {
                    musicDNAContent
                } else {
                    achievementsContent
                }
            }
            .padding(.bottom, player.currentTrack != nil ? 100 : 30)
        }
        .scrollIndicators(.hidden)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            stats.checkAchievements()
        }
        .overlay {
            if let achievement = stats.newlyUnlocked {
                achievementUnlockedOverlay(achievement)
            }
        }
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(StatsSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSection = section
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: section == .dna ? "waveform.circle" : "trophy")
                            .font(.system(size: 16, weight: .semibold))
                        Text(sectionTitle(section))
                            .font(.custom(Loc.fontBold, size: 12))
                    }
                    .foregroundStyle(selectedSection == section ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selectedSection == section
                            ? AnyShapeStyle(theme.currentTheme.accent.opacity(0.5))
                            : AnyShapeStyle(Color.clear),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .glassEffect(in: .rect(cornerRadius: 12))
                }
                .sensoryFeedback(.selection, trigger: selectedSection)
            }
        }
    }

    private func sectionTitle(_ section: StatsSection) -> String {
        switch section {
        case .dna: return isRu ? "Музыка ДНК" : "Music DNA"
        case .achievements: return isRu ? "Достижения" : "Achievements"
        }
    }
}
