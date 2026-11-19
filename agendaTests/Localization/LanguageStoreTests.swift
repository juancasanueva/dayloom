import Foundation
import Testing
@testable import agenda

/// The language picked in the Language tab: following the Mac until a flag is picked, saving the
/// pick, and pointing the strings built in code at it.
@MainActor
@Suite("Language store")
struct LanguageStoreTests {
    private func makeDefaults() -> UserDefaults {
        let name = "LanguageStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func makeStore(defaults: UserDefaults, system: String, localization: AppLocalization = AppLocalization()) -> LanguageStore {
        LanguageStore(defaults: defaults, systemLocale: Locale(identifier: system), localization: localization)
    }

    @Test func followsTheMacsLanguageUntilAFlagIsPicked() {
        let store = makeStore(defaults: makeDefaults(), system: "fr_CA")
        #expect(store.choice == nil)
        #expect(store.language == .french)
        #expect(store.locale == Locale(identifier: "fr_CA"))
    }

    @Test func aMacLanguageDayloomDoesNotShipFallsBackToEnglishKeepingTheRegion() {
        let store = makeStore(defaults: makeDefaults(), system: "nl_NL")
        #expect(store.language == .english)
        #expect(store.locale.language.languageCode?.identifier == "en")
        #expect(store.locale.region?.identifier == "NL")
    }

    @Test func pickingAFlagSwitchesTheLanguageAndTheStringsBuiltInCode() {
        let localization = AppLocalization()
        let store = makeStore(defaults: makeDefaults(), system: "en_GB", localization: localization)

        store.select(.spanish)

        #expect(store.choice == .spanish)
        #expect(store.language == .spanish)
        #expect(store.locale.language.languageCode?.identifier == "es")
        #expect(store.locale.region?.identifier == "GB")
        #expect(localization.bundle.bundlePath.hasSuffix("es.lproj"))
        #expect(localization.locale == store.locale)
        #expect(String(appLocalized: "Language", bundle: localization.bundle, locale: localization.locale) == "Idioma")
    }

    @Test func thePickIsSavedAndRestored() {
        let defaults = makeDefaults()
        makeStore(defaults: defaults, system: "en_US").select(.japanese)

        #expect(defaults.string(forKey: LanguageStore.defaultsKey) == "ja")
        // AppKit reads this at launch, so the menus macOS draws follow the pick next time.
        #expect(defaults.stringArray(forKey: "AppleLanguages") == ["ja"])

        let localization = AppLocalization()
        let restored = makeStore(defaults: defaults, system: "en_US", localization: localization)
        #expect(restored.language == .japanese)
        #expect(localization.bundle.bundlePath.hasSuffix("ja.lproj"))
    }

    @Test func aSavedValueDayloomDoesNotKnowFollowsTheMac() {
        let defaults = makeDefaults()
        defaults.set("xx", forKey: LanguageStore.defaultsKey)
        #expect(makeStore(defaults: defaults, system: "de_DE").language == .german)
    }
}
