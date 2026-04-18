import SwiftUI
import UIKit

enum AppIconVariant: String, CaseIterable, Identifiable {
    case default_ = "Default"
    case dark = "Dark"
    case ocean = "Ocean"
    case sunset = "Sunset"
    case neon = "Neon"
    case mint = "Mint"

    var id: String { rawValue }

    var iconName: String? {
        switch self {
        case .default_: return nil
        default: return "AppIcon-\(rawValue)"
        }
    }

    var displayName: String {
        let ru = ThemeManager.shared.language == .russian
        switch self {
        case .default_: return Loc.defaultIcon
        case .dark: return ru ? "Тёмная" : "Dark"
        case .ocean: return ru ? "Океан" : "Ocean"
        case .sunset: return ru ? "Закат" : "Sunset"
        case .neon: return ru ? "Неон" : "Neon"
        case .mint: return ru ? "Мята" : "Mint"
        }
    }

    var preview: UIImage {
        let name: String
        switch self {
        case .default_: name = "AppIcon-Default"
        default: name = "AppIcon-\(rawValue)"
        }
        // Load from bundle (not asset catalog)
        if let img = UIImage(named: "\(name)@3x.png")
            ?? UIImage(named: "\(name)@3x")
            ?? UIImage(named: name) {
            return img
        }
        // Fallback: load from the bundle path directly
        if let path = Bundle.main.path(forResource: "\(name)@3x", ofType: "png"),
           let img = UIImage(contentsOfFile: path) {
            return img
        }
        return UIImage(systemName: "app.fill") ?? UIImage()
    }
}
