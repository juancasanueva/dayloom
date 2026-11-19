import AppKit
import Foundation
import Observation

/// Light, dark, or following the system.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: String(appLocalized: "System")
        case .light: String(appLocalized: "Light")
        case .dark: String(appLocalized: "Dark")
        }
    }

    /// The window appearance to force, or `nil` to follow the system.
    var appearanceName: NSAppearance.Name? {
        switch self {
        case .system: nil
        case .light: .aqua
        case .dark: .darkAqua
        }
    }
}

/// One color theme: the surfaces a screen is built from, and an optional accent.
struct ThemePalette: Identifiable, Equatable {
    let id: String
    let name: String
    let isDark: Bool
    /// Window background behind the content panel.
    let canvas: UInt32
    /// The rounded panel that holds a screen's content.
    let panel: UInt32
    /// Resting surface of a card.
    let card: UInt32
    /// Card surface under the pointer.
    let cardHover: UInt32
    /// Accent color; `nil` uses the accent chosen in System Settings.
    let accent: UInt32?

    static let charcoal = ThemePalette(id: "charcoal", name: "Charcoal", isDark: true, canvas: 0x151617, panel: 0x1E1F22, card: 0x292A2E, cardHover: 0x303135, accent: nil)
    static let linen = ThemePalette(id: "linen", name: "Linen", isDark: false, canvas: 0xE8E4DD, panel: 0xFBF9F6, card: 0xF1EDE7, cardHover: 0xEAE5DD, accent: nil)

    /// Dark themes, the default first.
    static let dark: [ThemePalette] = [
        charcoal,
        ThemePalette(id: "ink", name: "Ink", isDark: true, canvas: 0x0F1320, panel: 0x171C2B, card: 0x212839, cardHover: 0x283048, accent: 0x7AA2F7),
        ThemePalette(id: "moss", name: "Moss", isDark: true, canvas: 0x121612, panel: 0x1A201A, card: 0x242C23, cardHover: 0x2B352A, accent: 0x8FC28A),
        ThemePalette(id: "plum", name: "Plum", isDark: true, canvas: 0x17131C, panel: 0x201A27, card: 0x2B2333, cardHover: 0x33293D, accent: 0xC49BE8),
        ThemePalette(id: "ember", name: "Ember", isDark: true, canvas: 0x1A1512, panel: 0x241D19, card: 0x2F2621, cardHover: 0x382D27, accent: 0xF0A35E),
        ThemePalette(id: "midnight", name: "Midnight", isDark: true, canvas: 0x000000, panel: 0x0C0C0D, card: 0x17171A, cardHover: 0x1F1F23, accent: 0x5E9EFF),
        // Well-known color schemes, from each one's published palette (all MIT licensed).
        ThemePalette(id: "catppuccin-mocha", name: "Catppuccin Mocha", isDark: true, canvas: 0x11111B, panel: 0x1E1E2E, card: 0x313244, cardHover: 0x45475A, accent: 0xCBA6F7),
        ThemePalette(id: "catppuccin-macchiato", name: "Catppuccin Macchiato", isDark: true, canvas: 0x181926, panel: 0x24273A, card: 0x363A4F, cardHover: 0x494D64, accent: 0xC6A0F6),
        ThemePalette(id: "catppuccin-frappe", name: "Catppuccin Frappé", isDark: true, canvas: 0x232634, panel: 0x303446, card: 0x414559, cardHover: 0x51576D, accent: 0xCA9EE6),
        ThemePalette(id: "nord", name: "Nord", isDark: true, canvas: 0x2E3440, panel: 0x3B4252, card: 0x434C5E, cardHover: 0x4C566A, accent: 0x88C0D0),
        ThemePalette(id: "dracula", name: "Dracula", isDark: true, canvas: 0x21222C, panel: 0x282A36, card: 0x343746, cardHover: 0x44475A, accent: 0xBD93F9),
        ThemePalette(id: "solarized-dark", name: "Solarized Dark", isDark: true, canvas: 0x00212B, panel: 0x002B36, card: 0x073642, cardHover: 0x0B3F4B, accent: 0x268BD2),
        ThemePalette(id: "gruvbox-dark", name: "Gruvbox Dark", isDark: true, canvas: 0x1D2021, panel: 0x282828, card: 0x3C3836, cardHover: 0x504945, accent: 0xFE8019),
        ThemePalette(id: "tokyo-night", name: "Tokyo Night", isDark: true, canvas: 0x16161E, panel: 0x1A1B26, card: 0x292E42, cardHover: 0x2F3549, accent: 0x7AA2F7),
        ThemePalette(id: "rose-pine", name: "Rosé Pine", isDark: true, canvas: 0x191724, panel: 0x1F1D2E, card: 0x26233A, cardHover: 0x403D52, accent: 0xC4A7E7),
    ]

    /// Light themes, the default first.
    static let light: [ThemePalette] = [
        linen,
        ThemePalette(id: "paper", name: "Paper", isDark: false, canvas: 0xE9EAEC, panel: 0xFFFFFF, card: 0xF3F4F6, cardHover: 0xECEDF0, accent: 0x2F6FEB),
        ThemePalette(id: "sage", name: "Sage", isDark: false, canvas: 0xDFE5DC, panel: 0xF6F9F4, card: 0xEAF0E6, cardHover: 0xE1E8DC, accent: 0x3E8A5B),
        ThemePalette(id: "blush", name: "Blush", isDark: false, canvas: 0xEDE2E2, panel: 0xFBF6F6, card: 0xF3EAEA, cardHover: 0xECE1E1, accent: 0xC2577A),
        // Well-known color schemes, from each one's published palette (all MIT licensed).
        ThemePalette(id: "catppuccin-latte", name: "Catppuccin Latte", isDark: false, canvas: 0xDCE0E8, panel: 0xEFF1F5, card: 0xE6E9EF, cardHover: 0xDCE0E8, accent: 0x8839EF),
        ThemePalette(id: "nord-light", name: "Nord Light", isDark: false, canvas: 0xD8DEE9, panel: 0xECEFF4, card: 0xE5E9F0, cardHover: 0xD8DEE9, accent: 0x5E81AC),
        ThemePalette(id: "solarized-light", name: "Solarized Light", isDark: false, canvas: 0xEEE8D5, panel: 0xFDF6E3, card: 0xF5EFDC, cardHover: 0xEEE8D5, accent: 0x268BD2),
        ThemePalette(id: "gruvbox-light", name: "Gruvbox Light", isDark: false, canvas: 0xEBDBB2, panel: 0xF9F5D7, card: 0xFBF1C7, cardHover: 0xF2E5BC, accent: 0xAF3A03),
        ThemePalette(id: "rose-pine-dawn", name: "Rosé Pine Dawn", isDark: false, canvas: 0xF2E9E1, panel: 0xFFFAF3, card: 0xFAF4ED, cardHover: 0xF2E9E1, accent: 0x907AA9),
    ]
}

/// The chosen appearance and themes, remembered across launches. The app uses the dark theme
/// when it appears dark and the light theme otherwise.
@Observable
final class ThemeStore {
    static let shared = ThemeStore()

    static let appearanceKey = "themeAppearance"
    static let darkKey = "themeDark"
    static let lightKey = "themeLight"

    @ObservationIgnored private let defaults: UserDefaults

    var appearance: AppearanceMode {
        didSet { defaults.set(appearance.rawValue, forKey: Self.appearanceKey) }
    }
    private(set) var darkPalette: ThemePalette
    private(set) var lightPalette: ThemePalette

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = defaults.string(forKey: Self.appearanceKey).flatMap(AppearanceMode.init(rawValue:)) ?? .system
        darkPalette = ThemePalette.dark.first { $0.id == defaults.string(forKey: Self.darkKey) } ?? .charcoal
        lightPalette = ThemePalette.light.first { $0.id == defaults.string(forKey: Self.lightKey) } ?? .linen
    }

    /// Makes `palette` the theme for its kind (dark or light).
    func select(_ palette: ThemePalette) {
        if palette.isDark {
            darkPalette = palette
            defaults.set(palette.id, forKey: Self.darkKey)
        } else {
            lightPalette = palette
            defaults.set(palette.id, forKey: Self.lightKey)
        }
    }
}
