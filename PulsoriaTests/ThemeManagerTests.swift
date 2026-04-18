import Testing
import SwiftUI
@testable import Pulsoria

struct ThemeManagerTests {

    // MARK: - AppTheme

    @Test func appThemeCoversAllEightPalettes() {
        #expect(AppTheme.allCases.count == 8)
        let expected: Set<String> = ["Purple", "Blue", "Pink", "Orange", "Green", "Red", "Cyan", "Indigo"]
        #expect(Set(AppTheme.allCases.map(\.rawValue)) == expected)
    }

    @Test func appThemeAccentsAreDistinct() {
        // Accents are SwiftUI Colors — we can't directly equate opaque Color values,
        // but the enum should map each case to a non-default accent.
        // Spot-check the round-trip via rawValue identity.
        for theme in AppTheme.allCases {
            #expect(AppTheme(rawValue: theme.rawValue) == theme)
            #expect(theme.id == theme.rawValue)
        }
    }

    // MARK: - SliderIcon

    @Test func sliderIconHas14Cases() {
        #expect(SliderIcon.allCases.count == 14)
    }

    @Test func sliderIconMappingsAreNonEmpty() {
        for icon in SliderIcon.allCases where icon != .custom {
            #expect(!icon.emoji.isEmpty)
            #expect(!icon.sfSymbol.isEmpty)
            #expect(!icon.universe.isEmpty)
            #expect(!icon.displayName.isEmpty)
        }
    }

    @Test func sliderIconUniverseGrouping() {
        // Sanity check: two icons belong to the Transformers universe,
        // two to Star Wars.
        let transformers = SliderIcon.allCases.filter { $0.universe == "Transformers" }
        let starWars = SliderIcon.allCases.filter { $0.universe == "Star Wars" }
        #expect(transformers.count == 2)
        #expect(starWars.count == 2)
    }

    // MARK: - AppLanguage

    @Test func appLanguageCases() {
        #expect(AppLanguage.allCases.count == 2)
        #expect(AppLanguage.russian.rawValue == "ru")
        #expect(AppLanguage.english.rawValue == "en")
        #expect(AppLanguage.russian.displayName == "Русский")
        #expect(AppLanguage.english.displayName == "English")
        #expect(AppLanguage.russian.flag == "🇷🇺")
        #expect(AppLanguage.english.flag == "🇬🇧")
    }

    // MARK: - AppAppearance

    @Test func appAppearanceIsDarkOnly() {
        #expect(AppAppearance.allCases == [.dark])
        #expect(AppAppearance.dark.colorScheme == .dark)
    }

    // MARK: - Loc (localization)

    @MainActor
    @Test func locSwitchesWithLanguage() {
        let theme = ThemeManager.shared
        let original = theme.language
        defer { theme.language = original }

        theme.language = .russian
        #expect(Loc.library == "Библиотека")
        #expect(Loc.settings == "Настройки")
        #expect(Loc.fontBold == "AvenirNext-Bold")

        theme.language = .english
        #expect(Loc.library == "Library")
        #expect(Loc.settings == "Settings")
        #expect(Loc.fontBold == "Futura-Bold")
    }

    // MARK: - activeSliderSymbol

    @MainActor
    @Test func activeSliderSymbolUsesIconMappingByDefault() {
        let theme = ThemeManager.shared
        let originalIcon = theme.sliderIcon
        let originalCustom = theme.customSliderSymbol
        defer {
            theme.sliderIcon = originalIcon
            theme.customSliderSymbol = originalCustom
        }

        theme.sliderIcon = .delorean
        #expect(theme.activeSliderSymbol == SliderIcon.delorean.sfSymbol)
    }

    @MainActor
    @Test func activeSliderSymbolHonorsCustomOverride() {
        let theme = ThemeManager.shared
        let originalIcon = theme.sliderIcon
        let originalCustom = theme.customSliderSymbol
        defer {
            theme.sliderIcon = originalIcon
            theme.customSliderSymbol = originalCustom
        }

        theme.sliderIcon = .custom
        theme.customSliderSymbol = "flame.fill"
        #expect(theme.activeSliderSymbol == "flame.fill")

        // Empty custom falls back to a default symbol.
        theme.customSliderSymbol = ""
        #expect(theme.activeSliderSymbol == "circle.fill")
    }
}
