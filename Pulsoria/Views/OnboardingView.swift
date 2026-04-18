import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @ObservedObject var theme = ThemeManager.shared
    @State private var currentPage = 0
    @Namespace private var glassNamespace

    private let totalPages = 5

    var body: some View {
        ZStack {
            // Animated background gradient
            backgroundGradient
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: currentPage)

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    libraryPage.tag(1)
                    wavePage.tag(2)
                    shopPage.tag(3)
                    customizePage.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Bottom section: indicators + button
                VStack(spacing: 20) {
                    // Page indicators
                    GlassEffectContainer(spacing: 6) {
                        HStack(spacing: 8) {
                            ForEach(0..<totalPages, id: \.self) { index in
                                Capsule()
                                    .frame(
                                        width: index == currentPage ? 24 : 8,
                                        height: 8
                                    )
                                    .glassEffect(
                                        index == currentPage
                                            ? .regular.tint(pageAccent(for: currentPage))
                                            : .regular,
                                        in: .capsule
                                    )
                            }
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentPage)
                    }

                    // Action button
                    Button {
                        if currentPage < totalPages - 1 {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                currentPage += 1
                            }
                        } else {
                            completeOnboarding()
                        }
                    } label: {
                        Text(currentPage == totalPages - 1 ? Loc.getStarted : Loc.next)
                            .font(.custom(Loc.fontBold, size: 17))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .glassEffect(
                                .regular.tint(pageAccent(for: currentPage)).interactive(),
                                in: .capsule
                            )
                    }
                    .padding(.horizontal, 40)
                    .sensoryFeedback(.impact, trigger: currentPage)
                }
                .padding(.bottom, 50)
            }
        }
    }

    // MARK: - Complete Onboarding

    private func completeOnboarding() {
        withAnimation(.easeInOut) {
            hasCompletedOnboarding = true
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        let accent = pageAccent(for: currentPage)
        return LinearGradient(
            colors: [
                accent.opacity(0.3),
                accent.opacity(0.1),
                Color(.systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func pageAccent(for page: Int) -> Color {
        switch page {
        case 0: return .purple
        case 1: return theme.currentTheme.accent
        case 2: return .cyan
        case 3: return .orange
        case 4: return .pink
        default: return .purple
        }
    }

    // MARK: - Page 0: Welcome

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            // App logo
            Image("NotLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
                .clipShape(Circle())
                .shadow(color: .purple.opacity(0.4), radius: 30, y: 10)

            // Full logo with name
            Image("FullLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 44)

            Text(Loc.welcomeDesc)
                .font(.custom(Loc.fontMedium, size: 17))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Page 1: Library

    private var libraryPage: some View {
        OnboardingFeaturePage(
            icon: "music.note.list",
            title: Loc.yourMusic,
            subtitle: Loc.yourMusicDesc,
            accentColor: theme.currentTheme.accent,
            features: [
                (icon: "folder.badge.plus", text: Loc.yourMusicFeature1),
                (icon: "heart.text.clipboard", text: Loc.yourMusicFeature2),
                (icon: "list.bullet", text: Loc.yourMusicFeature3)
            ]
        )
    }

    // MARK: - Page 2: Wave

    private var wavePage: some View {
        OnboardingFeaturePage(
            icon: "waveform.path",
            title: Loc.pulseWave,
            subtitle: Loc.pulseWaveDesc,
            accentColor: .cyan,
            features: [
                (icon: "waveform", text: Loc.pulseWaveFeature1),
                (icon: "circle.grid.3x3.fill", text: Loc.pulseWaveFeature2),
                (icon: "music.note", text: Loc.pulseWaveFeature3)
            ]
        )
    }

    // MARK: - Page 3: Shop

    private var shopPage: some View {
        OnboardingFeaturePage(
            icon: "bag.fill",
            title: Loc.beatShop,
            subtitle: Loc.beatShopDesc,
            accentColor: .orange,
            features: [
                (icon: "line.3.horizontal.decrease.circle", text: Loc.beatShopFeature1),
                (icon: "play.circle", text: Loc.beatShopFeature2),
                (icon: "square.and.arrow.up", text: Loc.beatShopFeature3)
            ]
        )
    }

    // MARK: - Page 4: Customize

    private var customizePage: some View {
        OnboardingFeaturePage(
            icon: "paintpalette.fill",
            title: Loc.makeItYours,
            subtitle: Loc.makeItYoursDesc,
            accentColor: .pink,
            features: [
                (icon: "swatchpalette", text: Loc.makeItYoursFeature1),
                (icon: "circle.lefthalf.filled", text: Loc.makeItYoursFeature2),
                (icon: "globe", text: Loc.makeItYoursFeature3)
            ]
        )
    }
}

// MARK: - Feature Page

struct OnboardingFeaturePage: View {
    let icon: String
    let title: String
    let subtitle: String
    let accentColor: Color
    let features: [(icon: String, text: String)]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: icon)
                .font(.system(size: 70, weight: .thin))
                .foregroundStyle(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: accentColor.opacity(0.4), radius: 20)

            // Title & subtitle
            VStack(spacing: 10) {
                Text(title)
                    .font(.custom(Loc.fontBold, size: 32))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.custom(Loc.fontMedium, size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }

            // Feature list with glass cards
            VStack(spacing: 12) {
                ForEach(features.indices, id: \.self) { index in
                    HStack(spacing: 14) {
                        Image(systemName: features[index].icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(accentColor)
                            .frame(width: 36, height: 36)
                            .glassEffect(.regular.tint(accentColor), in: .circle)

                        Text(features[index].text)
                            .font(.custom(Loc.fontMedium, size: 15))
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)

            Spacer()
            Spacer()
        }
    }
}
