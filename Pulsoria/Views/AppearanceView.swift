import SwiftUI

struct AppearanceView: View {
    @ObservedObject var theme = ThemeManager.shared
    @State private var showSymbolPicker = false

    var body: some View {
        List {
            themeSection
            playerSection
            appIconSection
            sliderIconSection
        }
        .contentMargins(.bottom, 80, for: .scrollContent)
        .navigationTitle(Loc.appearance)
        .sheet(isPresented: $showSymbolPicker) {
            SFSymbolPickerSheet()
        }
    }

    // MARK: - Player Background

    private var playerSection: some View {
        Section {
            Toggle(isOn: $theme.useCoverGradient) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Loc.coverGradient)
                        .font(.custom(Loc.fontMedium, size: 15))
                    Text(Loc.coverGradientHint)
                        .font(.custom(Loc.fontMedium, size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .tint(theme.currentTheme.accent)
        }
    }

    // MARK: - Accent Color

    private var themeSection: some View {
        Section(Loc.accentColor) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
                ForEach(AppTheme.allCases) { t in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            theme.currentTheme = t
                        }
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [t.accent, t.secondary],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 48, height: 48)

                                if theme.currentTheme == t {
                                    Image(systemName: "checkmark")
                                        .font(.body.bold())
                                        .foregroundStyle(.white)
                                }
                            }

                            Text(t.rawValue)
                                .font(.custom(Loc.fontMedium, size: 11))
                                .foregroundStyle(
                                    theme.currentTheme == t
                                        ? theme.currentTheme.accent
                                        : .secondary
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)

            // Preview
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.currentTheme.accent.opacity(0.5),
                                theme.currentTheme.secondary.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(Loc.previewTrack)
                        .font(.custom(Loc.fontBold, size: 15))
                        .foregroundStyle(theme.currentTheme.accent)
                    Text(Loc.artistName)
                        .font(.custom(Loc.fontMedium, size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(theme.currentTheme.accent)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - App Icon

    private var appIconSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text(Loc.appIcon)
                } icon: {
                    Image(systemName: "app.fill")
                        .foregroundStyle(theme.currentTheme.accent)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(AppIconVariant.allCases) { variant in
                            Button {
                                withAnimation(.smooth(duration: 0.3)) {
                                    setAppIcon(variant)
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    Image(uiImage: variant.preview)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 64, height: 64)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .strokeBorder(
                                                    currentIconVariant == variant
                                                        ? theme.currentTheme.accent
                                                        : Color.clear,
                                                    lineWidth: 3
                                                )
                                        )
                                        .shadow(
                                            color: currentIconVariant == variant
                                                ? theme.currentTheme.accent.opacity(0.4)
                                                : .clear,
                                            radius: 8
                                        )

                                    Text(variant.displayName)
                                        .font(.custom(Loc.fontMedium, size: 11))
                                        .foregroundStyle(
                                            currentIconVariant == variant
                                                ? theme.currentTheme.accent
                                                : .secondary
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                            .sensoryFeedback(.selection, trigger: currentIconVariant)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var currentIconVariant: AppIconVariant {
        if let name = UIApplication.shared.alternateIconName,
           let variant = AppIconVariant.allCases.first(where: { $0.iconName == name }) {
            return variant
        }
        return .default_
    }

    private func setAppIcon(_ variant: AppIconVariant) {
        let name = variant == .default_ ? nil : variant.iconName
        guard UIApplication.shared.alternateIconName != name else { return }
        UIApplication.shared.setAlternateIconName(name)
    }

    // MARK: - Slider Icon

    private var sliderIconSection: some View {
        Section {
            Button {
                showSymbolPicker = true
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.currentTheme.accent.opacity(0.15))
                            .frame(width: 48, height: 48)

                        Image(systemName: theme.activeSliderSymbol)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(theme.currentTheme.accent)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(theme.customSliderSymbol.isEmpty ? "circle.fill" : theme.customSliderSymbol)
                            .font(.custom(Loc.fontBold, size: 16))
                            .foregroundStyle(.primary)
                        Text(Loc.sliderIconHint)
                            .font(.custom(Loc.fontMedium, size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(UIColor.tertiaryLabel))
                }
            }
            .padding(.vertical, 4)

            if theme.sliderIcon == .custom && !theme.customSliderSymbol.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        theme.sliderIcon = .defaultCircle
                        theme.customSliderSymbol = ""
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text(theme.language == .russian ? "Сбросить по умолчанию" : "Reset to default")
                    }
                    .font(.custom(Loc.fontMedium, size: 15))
                    .foregroundStyle(theme.currentTheme.accent)
                }
            }
        } header: {
            Text(Loc.sliderIcon)
        }
    }
}
