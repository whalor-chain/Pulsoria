import SwiftUI

extension StatsView {
    // MARK: - Music DNA

    var musicDNAContent: some View {
        VStack(spacing: 16) {
            personalityCard
                .padding(.horizontal)

            overviewCards
                .padding(.horizontal)

            todayVsAverageCard
                .padding(.horizontal)

            if let top = player.topTracks.first {
                mostPlayedCard(top)
                    .padding(.horizontal)
            }

            personalRecordsCard
                .padding(.horizontal)

            if !stats.artistDistribution().isEmpty {
                artistChart
                    .padding(.horizontal)
            }

            diversityCard
                .padding(.horizontal)

            heatmapCard
                .padding(.horizontal)

            weeklyChart
                .padding(.horizontal)

            allTimeStatsCard
                .padding(.horizontal)
        }
    }

    // MARK: - Personality Card

    private var personalityCard: some View {
        let p = stats.personality()
        return VStack(spacing: 12) {
            Image(systemName: p.icon)
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.currentTheme.accent, theme.currentTheme.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(isRu ? p.titleRu : p.titleEn)
                .font(.custom(Loc.fontBold, size: 20))

            Text(isRu ? p.descRu : p.descEn)
                .font(.custom(Loc.fontMedium, size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 20))
    }

    // MARK: - Overview Cards

    private var overviewCards: some View {
        let totalHours = player.totalListeningTime / 3600.0

        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            overviewPill(
                icon: "play.fill",
                value: "\(player.totalPlays)",
                label: isRu ? "Воспроизведений" : "Total Plays",
                color: .blue
            )
            overviewPill(
                icon: "clock.fill",
                value: formatHours(totalHours),
                label: isRu ? "Часов музыки" : "Hours of Music",
                color: .purple
            )
            overviewPill(
                icon: "flame.fill",
                value: "\(stats.currentStreak)",
                label: isRu ? "Дней подряд" : "Day Streak",
                color: .orange
            )
            overviewPill(
                icon: "person.2.fill",
                value: "\(Set(player.tracks.map(\.artist)).count)",
                label: isRu ? "Артистов" : "Artists",
                color: .green
            )
        }
    }

    private func overviewPill(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)

            Text(value)
                .font(.custom(Loc.fontBold, size: 22))
                .foregroundStyle(.primary)

            Text(label)
                .font(.custom(Loc.fontMedium, size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glassEffect(in: .rect(cornerRadius: 14))
    }

    // MARK: - Artist Chart

    private var artistChart: some View {
        let data = stats.artistDistribution()
        let colors: [Color] = [
            theme.currentTheme.accent,
            theme.currentTheme.secondary,
            .blue, .green, .orange, .pink
        ]

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.currentTheme.accent)
                Text(isRu ? "Топ артисты" : "Top Artists")
                    .font(.custom(Loc.fontBold, size: 15))
            }

            ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 10) {
                    Text(item.name)
                        .font(.custom(Loc.fontMedium, size: 12))
                        .foregroundStyle(.primary)
                        .frame(width: 80, alignment: .leading)
                        .lineLimit(1)

                    GeometryReader { geo in
                        let maxWidth = geo.size.width
                        let barWidth = max(4, maxWidth * item.percentage / 100.0)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(colors[index % colors.count].opacity(0.7))
                            .frame(width: barWidth, height: 20)
                    }
                    .frame(height: 20)

                    Text("\(Int(item.percentage))%")
                        .font(.custom(Loc.fontMedium, size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    // MARK: - Heatmap Card

    private var heatmapCard: some View {
        let maxPlays = max(1, stats.hourlyPlays.max() ?? 1)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.currentTheme.accent)
                Text(isRu ? "Когда ты слушаешь" : "When You Listen")
                    .font(.custom(Loc.fontBold, size: 15))
            }

            // 24-hour grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 12), spacing: 3) {
                ForEach(0..<24, id: \.self) { hour in
                    let intensity = Double(stats.hourlyPlays[hour]) / Double(maxPlays)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.currentTheme.accent.opacity(max(0.08, intensity * 0.9)))
                        .frame(height: 28)
                        .overlay {
                            Text("\(hour)")
                                .font(.custom(Loc.fontMedium, size: 8).monospacedDigit())
                                .foregroundStyle(intensity > 0.3 ? .white : .secondary)
                        }
                }
            }

            HStack {
                Circle().fill(theme.currentTheme.accent.opacity(0.08)).frame(width: 10, height: 10)
                Text(isRu ? "Мало" : "Low")
                    .font(.custom(Loc.fontMedium, size: 9))
                    .foregroundStyle(.secondary)
                Spacer()
                Circle().fill(theme.currentTheme.accent.opacity(0.9)).frame(width: 10, height: 10)
                Text(isRu ? "Много" : "High")
                    .font(.custom(Loc.fontMedium, size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    // MARK: - Today vs Average

    private var todayVsAverageCard: some View {
        let todayMin = player.todayListeningTime / 60.0
        let todayPlays = player.todayPlays
        let totalDays = max(1, stats.totalDaysListened)
        let avgMinPerDay = player.totalListeningTime / 60.0 / Double(totalDays)
        let avgPlaysPerDay = Double(player.totalPlays) / Double(totalDays)
        let timeDiff = todayMin - avgMinPerDay
        let playsDiff = Double(todayPlays) - avgPlaysPerDay

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.currentTheme.accent)
                Text(isRu ? "Сегодня vs Среднее" : "Today vs Average")
                    .font(.custom(Loc.fontBold, size: 15))
            }

            HStack(spacing: 12) {
                comparisonPill(
                    title: isRu ? "Минуты" : "Minutes",
                    today: "\(Int(todayMin))",
                    avg: "\(Int(avgMinPerDay))",
                    diff: timeDiff,
                    unit: isRu ? "мин" : "min"
                )
                comparisonPill(
                    title: isRu ? "Треки" : "Plays",
                    today: "\(todayPlays)",
                    avg: "\(Int(avgPlaysPerDay))",
                    diff: playsDiff,
                    unit: ""
                )
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    private func comparisonPill(title: String, today: String, avg: String, diff: Double, unit: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.custom(Loc.fontMedium, size: 10))
                .foregroundStyle(.secondary)

            Text(today)
                .font(.custom(Loc.fontBold, size: 24))

            HStack(spacing: 3) {
                Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 9, weight: .bold))
                Text("\(diff >= 0 ? "+" : "")\(Int(diff))\(unit.isEmpty ? "" : " \(unit)")")
                    .font(.custom(Loc.fontMedium, size: 10).monospacedDigit())
            }
            .foregroundStyle(diff >= 0 ? .green : .orange)

            Text(isRu ? "средн. \(avg)" : "avg \(avg)")
                .font(.custom(Loc.fontMedium, size: 9))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .glassEffect(in: .rect(cornerRadius: 12))
    }

    // MARK: - Most Played Track

    private func mostPlayedCard(_ track: Track) -> some View {
        HStack(spacing: 14) {
            if let data = player.artworkCache[track.fileName],
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemBackground))
                    .frame(width: 70, height: 70)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(isRu ? "Самый популярный трек" : "Most Played Track")
                    .font(.custom(Loc.fontMedium, size: 10))
                    .foregroundStyle(theme.currentTheme.accent)

                Text(track.title)
                    .font(.custom(Loc.fontBold, size: 16))
                    .lineLimit(1)

                Text(track.artist)
                    .font(.custom(Loc.fontMedium, size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label("\(track.playCount) \(isRu ? "прослуш." : "plays")", systemImage: "play.fill")
                    if let last = track.lastPlayed {
                        Label(relativeDate(last), systemImage: "clock")
                    }
                }
                .font(.custom(Loc.fontMedium, size: 10))
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    // MARK: - Personal Records

    private var personalRecordsCard: some View {
        let peakHour = stats.hourlyPlays.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
        let peakPlays = stats.hourlyPlays[peakHour]
        let maxTrackPlays = player.tracks.map(\.playCount).max() ?? 0
        let favArtist = player.topArtists.first?.name ?? "-"
        let favArtistPlays = player.topArtists.first?.playCount ?? 0

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                Text(isRu ? "Личные рекорды" : "Personal Records")
                    .font(.custom(Loc.fontBold, size: 15))
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                recordItem(
                    icon: "clock.badge.fill",
                    title: isRu ? "Пик-час" : "Peak Hour",
                    value: "\(peakHour):00",
                    detail: "\(peakPlays) \(isRu ? "треков" : "plays")",
                    color: .blue
                )
                recordItem(
                    icon: "flame.fill",
                    title: isRu ? "Лучшая серия" : "Best Streak",
                    value: "\(stats.bestStreak)",
                    detail: isRu ? "дней подряд" : "days in a row",
                    color: .orange
                )
                recordItem(
                    icon: "arrow.counterclockwise",
                    title: isRu ? "Макс. повтор" : "Max Repeat",
                    value: "\(maxTrackPlays)",
                    detail: isRu ? "раз один трек" : "times one track",
                    color: .purple
                )
                recordItem(
                    icon: "star.fill",
                    title: isRu ? "Топ артист" : "Top Artist",
                    value: favArtist,
                    detail: "\(favArtistPlays) \(isRu ? "прослуш." : "plays")",
                    color: .green
                )
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    private func recordItem(icon: String, title: String, value: String, detail: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)

            Text(value)
                .font(.custom(Loc.fontBold, size: 16))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.custom(Loc.fontMedium, size: 10))
                .foregroundStyle(.secondary)

            Text(detail)
                .font(.custom(Loc.fontMedium, size: 8))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .glassEffect(in: .rect(cornerRadius: 10))
    }

    // MARK: - Diversity Score

    private var diversityCard: some View {
        let totalArtists = Set(player.tracks.map(\.artist)).count
        let listenedArtists = Set(player.tracks.filter { $0.playCount > 0 }.map(\.artist)).count
        let diversityPercent = totalArtists > 0 ? Double(listenedArtists) / Double(totalArtists) * 100 : 0

        let topTrackPlays = player.tracks.map(\.playCount).max() ?? 0
        let totalPlays = max(1, player.totalPlays)
        let concentrationPercent = Double(topTrackPlays) / Double(totalPlays) * 100
        let spreadScore = max(0, min(100, 100 - concentrationPercent))

        let avgPlaysPerTrack = player.tracks.isEmpty ? 0.0 : Double(totalPlays) / Double(player.tracks.count)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.currentTheme.accent)
                Text(isRu ? "Разнообразие" : "Diversity")
                    .font(.custom(Loc.fontBold, size: 15))
            }

            HStack(spacing: 10) {
                diversityRing(
                    value: diversityPercent,
                    label: isRu ? "Артисты" : "Artists",
                    detail: "\(listenedArtists)/\(totalArtists)",
                    color: .green
                )
                diversityRing(
                    value: spreadScore,
                    label: isRu ? "Разброс" : "Spread",
                    detail: isRu ? "равномерность" : "evenness",
                    color: .blue
                )
                VStack(spacing: 6) {
                    Text(String(format: "%.1f", avgPlaysPerTrack))
                        .font(.custom(Loc.fontBold, size: 20))
                    Text(isRu ? "Среднее\nна трек" : "Avg per\ntrack")
                        .font(.custom(Loc.fontMedium, size: 9))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    private func diversityRing(value: Double, label: String, detail: String, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 5)
                    .frame(width: 50, height: 50)
                Circle()
                    .trim(from: 0, to: min(1, value / 100))
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                Text("\(Int(value))%")
                    .font(.custom(Loc.fontBold, size: 11).monospacedDigit())
            }
            Text(label)
                .font(.custom(Loc.fontMedium, size: 9))
                .foregroundStyle(.secondary)
            Text(detail)
                .font(.custom(Loc.fontMedium, size: 8))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - All-Time Stats

    private var allTimeStatsCard: some View {
        let totalMinutes = Int(player.totalListeningTime / 60)
        let totalTracks = player.tracks.count
        let favCount = player.tracks.filter(\.isFavorite).count
        let playlistCount = playlists.playlists.count
        let avgSessionMin = stats.totalDaysListened > 0 ? totalMinutes / stats.totalDaysListened : 0

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "infinity")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.currentTheme.accent)
                Text(isRu ? "За всё время" : "All Time")
                    .font(.custom(Loc.fontBold, size: 15))
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                allTimeStat(value: "\(player.totalPlays)", label: isRu ? "Воспроизв." : "Plays")
                allTimeStat(value: formatAllTimeHours(player.totalListeningTime), label: isRu ? "Часов" : "Hours")
                allTimeStat(value: "\(totalTracks)", label: isRu ? "Треков" : "Tracks")
                allTimeStat(value: "\(favCount)", label: isRu ? "Избранных" : "Favorites")
                allTimeStat(value: "\(playlistCount)", label: isRu ? "Плейлистов" : "Playlists")
                allTimeStat(value: "\(avgSessionMin)\(isRu ? "м" : "m")", label: isRu ? "Ср. сессия" : "Avg Session")
                allTimeStat(value: "\(stats.totalDaysListened)", label: isRu ? "Дней" : "Days")
                allTimeStat(value: "\(stats.completedCount)/\(stats.totalAchievements)", label: isRu ? "Ачивок" : "Badges")
                allTimeStat(value: "\(stats.xp)", label: "XP")
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    private func allTimeStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.custom(Loc.fontBold, size: 15).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.custom(Loc.fontMedium, size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .glassEffect(in: .rect(cornerRadius: 8))
    }

    // MARK: - Weekly Chart

    private var weeklyChart: some View {
        let data = stats.weeklyListeningData()
        let maxMinutes = max(1, data.map(\.minutes).max() ?? 1)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.currentTheme.accent)
                Text(isRu ? "За неделю" : "This Week")
                    .font(.custom(Loc.fontBold, size: 15))
            }

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 4) {
                        Text("\(Int(item.minutes))")
                            .font(.custom(Loc.fontMedium, size: 9).monospacedDigit())
                            .foregroundStyle(.secondary)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [theme.currentTheme.accent, theme.currentTheme.secondary],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(height: max(4, CGFloat(item.minutes / maxMinutes) * 100))

                        Text(item.day)
                            .font(.custom(Loc.fontMedium, size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 140)

            Text(isRu ? "минут прослушивания" : "minutes listened")
                .font(.custom(Loc.fontMedium, size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func formatHours(_ hours: Double) -> String {
        if hours < 1 {
            return "\(Int(hours * 60))\(isRu ? "м" : "m")"
        }
        return String(format: "%.1f", hours)
    }

    private func formatAllTimeHours(_ seconds: TimeInterval) -> String {
        let hours = seconds / 3600.0
        if hours < 1 { return "\(Int(seconds / 60))\(isRu ? "м" : "m")" }
        if hours < 100 { return String(format: "%.1f", hours) }
        return "\(Int(hours))"
    }

    private func relativeDate(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 60 { return isRu ? "только что" : "just now" }
        if diff < 3600 { return "\(Int(diff / 60))\(isRu ? " мин назад" : "m ago")" }
        if diff < 86400 { return "\(Int(diff / 3600))\(isRu ? " ч назад" : "h ago")" }
        return "\(Int(diff / 86400))\(isRu ? " дн назад" : "d ago")"
    }
}
