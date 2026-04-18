import SwiftUI

// MARK: - Sleep Timer Sheet

struct SleepTimerSheet: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    private let options: [(label: String, minutes: Int)] = [
        ("5 \(Loc.minutesSuffix)", 5),
        ("10 \(Loc.minutesSuffix)", 10),
        ("15 \(Loc.minutesSuffix)", 15),
        ("30 \(Loc.minutesSuffix)", 30),
        ("45 \(Loc.minutesSuffix)", 45),
        ("60 \(Loc.minutesSuffix)", 60)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if player.isSleepTimerActive {
                    // Active timer display
                    VStack(spacing: 12) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(theme.currentTheme.accent)

                        if player.sleepTimerEndOfTrack {
                            Text(Loc.endOfTrack)
                                .font(.custom(Loc.fontBold, size: 22))
                        } else {
                            Text(formatRemaining(player.sleepTimerRemaining))
                                .font(.custom(Loc.fontBold, size: 32).monospacedDigit())
                        }

                        Text(Loc.timerActive)
                            .font(.custom(Loc.fontMedium, size: 15))
                            .foregroundStyle(.secondary)

                        Button {
                            player.cancelSleepTimer()
                            dismiss()
                        } label: {
                            Text(Loc.cancelTimer)
                                .font(.custom(Loc.fontBold, size: 16))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.glass)
                        .padding(.top, 8)
                    }
                    .padding(.top, 24)
                } else {
                    // Timer options
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(options, id: \.minutes) { option in
                            Button {
                                player.startSleepTimer(minutes: option.minutes)
                                dismiss()
                            } label: {
                                Text(option.label)
                                    .font(.custom(Loc.fontBold, size: 18))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                            }
                            .buttonStyle(.glass)
                            .sensoryFeedback(.impact(flexibility: .soft), trigger: player.isSleepTimerActive)
                        }

                        Button {
                            player.startSleepTimerEndOfTrack()
                            dismiss()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 14))
                                Text(Loc.endOfTrack)
                                    .font(.custom(Loc.fontBold, size: 16))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                        }
                        .buttonStyle(.glass)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                }

                Spacer()
            }
            .navigationTitle(Loc.sleepTimer)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Loc.done) { dismiss() }
                        .font(.custom(Loc.fontMedium, size: 15))
                }
            }
        }
    }

    private func formatRemaining(_ time: TimeInterval) -> String {
        let m = Int(time) / 60
        let s = Int(time) % 60
        return String(format: "%d:%02d", m, s)
    }
}

