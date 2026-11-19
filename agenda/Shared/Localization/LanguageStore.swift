import Foundation
import Observation
import SwiftUI

/// The language chosen in Settings, else the Mac's own, and the locale Dayloom draws in.
///
/// Choosing one switches the windows at once (`appLanguage()` redraws them in the new locale and
/// `AppLocalization.shared` resolves the strings built in code), and writes the app's
/// `AppleLanguages` so the menus AppKit draws itself follow from the next launch.
@Observable
final class LanguageStore {
    /// The unit-test host keeps the development language, whatever the Mac speaks.
    static let shared = LanguageStore(appliesOnInit: !PlannerSchema.isRunningTests)

    /// Where the choice is saved; absent until a flag is picked.
    static let defaultsKey = "appLanguage"

    /// The flag picked in Settings, or `nil` to follow the Mac's language.
    private(set) var choice: AppLanguage?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let systemLocale: Locale
    @ObservationIgnored private let localization: AppLocalization

    /// - Parameters:
    ///   - systemLocale: The Mac's locale, whose language is followed until a flag is picked.
    ///   - localization: The bundle and locale pointed at the effective language.
    ///   - appliesOnInit: Whether `localization` is pointed at the effective language right away.
    init(defaults: UserDefaults = .standard, systemLocale: Locale = .current,
         localization: AppLocalization = .shared, appliesOnInit: Bool = true) {
        self.defaults = defaults
        self.systemLocale = systemLocale
        self.localization = localization
        choice = defaults.string(forKey: Self.defaultsKey).flatMap(AppLanguage.init(rawValue:))
        if appliesOnInit {
            localization.apply(language, locale: locale)
        }
    }

    /// The language Dayloom draws in: the choice, else the Mac's.
    var language: AppLanguage {
        choice ?? AppLanguage.matching(systemLocale)
    }

    /// The locale of the windows, the strings built in code and every formatted date.
    var locale: Locale {
        language.locale(preferring: systemLocale)
    }

    /// Switches Dayloom to `language`.
    func select(_ language: AppLanguage) {
        guard language != choice else { return }
        defaults.set(language.rawValue, forKey: Self.defaultsKey)
        // Bundle.main and AppKit read this at launch, so the system-drawn menus follow next time.
        defaults.set([language.rawValue], forKey: "AppleLanguages")
        // Before `choice` changes, so the redraw it triggers already reads the new strings.
        localization.apply(language, locale: language.locale(preferring: systemLocale))
        choice = language
    }
}

/// Draws the content in the app language, and redraws all of it when the language changes.
private struct AppLanguageModifier: ViewModifier {
    private let store = LanguageStore.shared

    func body(content: Content) -> some View {
        content
            .environment(\.locale, store.locale)
            // Text built in code (titles, dates) is read when a view's body runs, so a new
            // identity makes every body run again in the new language. Model state lives in
            // the environment and survives; only transient view state (scroll, hover) resets.
            .id(store.language)
    }
}

extension View {
    /// Follows the language chosen in Settings.
    func appLanguage() -> some View {
        modifier(AppLanguageModifier())
    }
}
