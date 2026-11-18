import AppKit
import Foundation
import Testing
@testable import agenda

@MainActor
@Suite("Themes")
struct ThemeStoreTests {
    private func makeDefaults() -> UserDefaults {
        let name = "ThemeStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func startsWithTheSystemAppearanceAndTheOriginalLook() {
        let store = ThemeStore(defaults: makeDefaults())

        #expect(store.appearance == .system)
        #expect(store.darkPalette == ThemePalette.charcoal)
        #expect(store.lightPalette == ThemePalette.linen)
    }

    @Test func choicesAreRememberedAcrossLaunches() {
        let defaults = makeDefaults()
        let store = ThemeStore(defaults: defaults)
        store.appearance = .dark
        store.select(ThemePalette.dark[2])
        store.select(ThemePalette.light[1])

        let reopened = ThemeStore(defaults: defaults)

        #expect(reopened.appearance == .dark)
        #expect(reopened.darkPalette == ThemePalette.dark[2])
        #expect(reopened.lightPalette == ThemePalette.light[1])
    }

    @Test func selectingADarkThemeKeepsTheLightOne() {
        let store = ThemeStore(defaults: makeDefaults())
        store.select(ThemePalette.light[1])

        store.select(ThemePalette.dark[1])

        #expect(store.darkPalette == ThemePalette.dark[1])
        #expect(store.lightPalette == ThemePalette.light[1])
    }

    @Test func anUnknownSavedThemeFallsBackToTheDefault() {
        let defaults = makeDefaults()
        defaults.set("retired-theme", forKey: ThemeStore.darkKey)
        defaults.set("also-gone", forKey: ThemeStore.lightKey)
        defaults.set("sepia", forKey: ThemeStore.appearanceKey)

        let store = ThemeStore(defaults: defaults)

        #expect(store.darkPalette == ThemePalette.charcoal)
        #expect(store.lightPalette == ThemePalette.linen)
        #expect(store.appearance == .system)
    }

    @Test func everyThemeHasAUniqueIDAndSitsInTheRightList() {
        let all = ThemePalette.dark + ThemePalette.light
        #expect(Set(all.map(\.id)).count == all.count)
        let darkKinds = ThemePalette.dark.map(\.isDark)
        let lightKinds = ThemePalette.light.map(\.isDark)
        #expect(!darkKinds.contains(false))
        #expect(!lightKinds.contains(true))
        #expect(ThemePalette.dark.first == ThemePalette.charcoal)
        #expect(ThemePalette.light.first == ThemePalette.linen)
    }

    @Test func knownColorSchemesAreOffered() {
        let all = Dictionary(uniqueKeysWithValues: (ThemePalette.dark + ThemePalette.light).map { ($0.id, $0) })
        let expected = [
            "catppuccin-mocha", "catppuccin-macchiato", "catppuccin-frappe", "catppuccin-latte",
            "nord", "nord-light", "dracula", "solarized-dark", "solarized-light",
            "gruvbox-dark", "gruvbox-light", "tokyo-night", "rose-pine", "rose-pine-dawn",
        ]
        for id in expected { #expect(all[id] != nil, "missing \(id)") }

        // Spot checks against each scheme's published colors.
        #expect(all["catppuccin-mocha"]?.panel == 0x1E1E2E)
        #expect(all["catppuccin-mocha"]?.accent == 0xCBA6F7)
        #expect(all["catppuccin-latte"]?.panel == 0xEFF1F5)
        #expect(all["nord"]?.canvas == 0x2E3440)
        #expect(all["nord"]?.accent == 0x88C0D0)
        #expect(all["dracula"]?.panel == 0x282A36)
        #expect(all["dracula"]?.accent == 0xBD93F9)
        #expect(all["solarized-light"]?.panel == 0xFDF6E3)
        #expect(all["gruvbox-dark"]?.panel == 0x282828)
        #expect(all["rose-pine"]?.canvas == 0x191724)
    }

    @Test func darkThemesLookDarkAndLightThemesLookLight() {
        func luminance(_ hex: UInt32) -> Double {
            let r = Double((hex >> 16) & 0xFF), g = Double((hex >> 8) & 0xFF), b = Double(hex & 0xFF)
            return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
        }
        for palette in ThemePalette.dark {
            #expect(luminance(palette.panel) < 0.35, "\(palette.name) panel is too light for a dark theme")
        }
        for palette in ThemePalette.light {
            #expect(luminance(palette.panel) > 0.75, "\(palette.name) panel is too dark for a light theme")
        }
        for palette in ThemePalette.dark + ThemePalette.light {
            #expect(palette.card != palette.panel, "\(palette.name) cards would vanish into the panel")
            #expect(palette.cardHover != palette.card, "\(palette.name) hover wouldn't show")
        }
    }

    @Test(arguments: [(AppearanceMode.system, nil as String?), (.light, "NSAppearanceNameAqua"), (.dark, "NSAppearanceNameDarkAqua")])
    func appearanceMapsToTheWindowAppearance(mode: AppearanceMode, expected: String?) {
        #expect(mode.appearanceName?.rawValue == expected)
    }
}
