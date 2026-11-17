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

    @Test(arguments: [(AppearanceMode.system, nil as String?), (.light, "NSAppearanceNameAqua"), (.dark, "NSAppearanceNameDarkAqua")])
    func appearanceMapsToTheWindowAppearance(mode: AppearanceMode, expected: String?) {
        #expect(mode.appearanceName?.rawValue == expected)
    }
}
