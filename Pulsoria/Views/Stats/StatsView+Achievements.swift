import SwiftUI

extension StatsView {
    // MARK: - Achievements Content

    var achievementsContent: some View {
        VStack(spacing: 16) {
            levelCard
                .padding(.horizontal)

            progressOverview
                .padding(.horizontal)

            ForEach(AchievementCategory.allCases) { category in
                let items = AchievementID.allCases.filter { $0.category == category }
                achievementSection(category: category, items: items)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Level Card

    private var levelCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isRu ? "Уровень" : "Level")
                        .font(.custom(Loc.fontMedium, size: 12))
                        .foregroundStyle(.secondary)
                    Text("\(stats.level)")
                        .font(.custom(Loc.fontBold, size: 36))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [theme.currentTheme.accent, theme.currentTheme.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(stats.xp) XP")
                        .font(.custom(Loc.fontBold, size: 16))
                    Text(isRu ? "\(stats.xpToNextLevel) XP до след." : "\(stats.xpToNextLevel) XP to next")
                        .font(.custom(Loc.fontMedium, size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.tertiarySystemBackground))

                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [theme.currentTheme.accent, theme.currentTheme.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * stats.xpProgress)
                }
            }
            .frame(height: 10)
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    // MARK: - Progress Overview

    private var progressOverview: some View {
        HStack(spacing: 10) {
            VStack(spacing: 4) {
                Text("\(stats.completedCount)")
                    .font(.custom(Loc.fontBold, size: 24))
                    .foregroundStyle(theme.currentTheme.accent)
                Text(isRu ? "Получено" : "Unlocked")
                    .font(.custom(Loc.fontMedium, size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .glassEffect(in: .rect(cornerRadius: 12))

            VStack(spacing: 4) {
                Text("\(stats.totalAchievements - stats.completedCount)")
                    .font(.custom(Loc.fontBold, size: 24))
                    .foregroundStyle(.secondary)
                Text(isRu ? "Осталось" : "Remaining")
                    .font(.custom(Loc.fontMedium, size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .glassEffect(in: .rect(cornerRadius: 12))

            VStack(spacing: 4) {
                Text("\(stats.bestStreak)")
                    .font(.custom(Loc.fontBold, size: 24))
                    .foregroundStyle(.orange)
                Text(isRu ? "Лучшая серия" : "Best Streak")
                    .font(.custom(Loc.fontMedium, size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .glassEffect(in: .rect(cornerRadius: 12))
        }
    }

    // MARK: - Achievement Section

    private func achievementSection(category: AchievementCategory, items: [AchievementID]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.currentTheme.accent)
                Text(isRu ? category.titleRu : category.titleEn)
                    .font(.custom(Loc.fontBold, size: 14))
                    .foregroundStyle(.secondary)
            }

            ForEach(items) { achievement in
                achievementRow(achievement)
            }
        }
    }

    private func achievementRow(_ achievement: AchievementID) -> some View {
        let isUnlocked = stats.unlockedAchievements.contains(achievement.rawValue)
        let ctx = stats.buildContext()
        let (current, target) = achievement.progress(ctx)
        let progressValue = target > 0 ? current / target : 0
        let rarity = achievement.rarity

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? rarityColor(rarity).opacity(0.2) : Color(.tertiarySystemBackground))
                    .frame(width: 44, height: 44)

                Image(systemName: achievement.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isUnlocked ? rarityColor(rarity) : .secondary.opacity(0.4))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(isRu ? achievement.titleRu : achievement.titleEn)
                        .font(.custom(Loc.fontBold, size: 13))
                        .foregroundStyle(isUnlocked ? .primary : .secondary)

                    Text(isRu ? rarity.titleRu : rarity.titleEn)
                        .font(.custom(Loc.fontMedium, size: 8))
                        .foregroundStyle(rarityColor(rarity))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(rarityColor(rarity).opacity(0.15), in: Capsule())
                }

                Text(isRu ? achievement.descRu : achievement.descEn)
                    .font(.custom(Loc.fontMedium, size: 11))
                    .foregroundStyle(.secondary)

                if !isUnlocked {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(.tertiarySystemBackground))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(rarityColor(rarity).opacity(0.6))
                                .frame(width: geo.size.width * progressValue)
                        }
                    }
                    .frame(height: 4)
                }
            }

            Spacer()

            VStack(spacing: 2) {
                if isUnlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(rarityColor(rarity))
                } else {
                    Text("\(Int(current))/\(Int(target))")
                        .font(.custom(Loc.fontMedium, size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text("+\(rarity.xp)")
                    .font(.custom(Loc.fontMedium, size: 9).monospacedDigit())
                    .foregroundStyle(rarityColor(rarity).opacity(0.7))
            }
        }
        .padding(12)
        .glassEffect(in: .rect(cornerRadius: 14))
    }

    private func rarityColor(_ rarity: AchievementRarity) -> Color {
        switch rarity {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }

    // MARK: - Achievement Unlocked Overlay

    func achievementUnlockedOverlay(_ achievement: AchievementID) -> some View {
        VStack(spacing: 16) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: achievement.icon)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.currentTheme.accent, theme.currentTheme.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.bounce, value: stats.newlyUnlocked)

                Text(isRu ? "Достижение получено!" : "Achievement Unlocked!")
                    .font(.custom(Loc.fontBold, size: 18))

                Text(isRu ? achievement.titleRu : achievement.titleEn)
                    .font(.custom(Loc.fontMedium, size: 15))
                    .foregroundStyle(.secondary)

                Text(isRu ? achievement.rarity.titleRu : achievement.rarity.titleEn)
                    .font(.custom(Loc.fontMedium, size: 12))
                    .foregroundStyle(rarityColor(achievement.rarity))

                Text("+\(achievement.rarity.xp) XP")
                    .font(.custom(Loc.fontBold, size: 14))
                    .foregroundStyle(rarityColor(achievement.rarity))

                Button {
                    withAnimation {
                        stats.newlyUnlocked = nil
                    }
                } label: {
                    Text(isRu ? "Круто!" : "Awesome!")
                        .font(.custom(Loc.fontBold, size: 15))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.glassProminent)
                .tint(theme.currentTheme.accent)
                .padding(.horizontal, 20)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .glassEffect(in: .rect(cornerRadius: 24))
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color.black.opacity(0.4).ignoresSafeArea())
        .transition(.opacity)
    }

}
