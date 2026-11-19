import Foundation
import Testing
@testable import agenda

/// The compiled string catalog in the app: every language carries every string, and each
/// translation keeps the placeholders its English text fills in.
@Suite("Localization catalog")
struct LocalizationCatalogTests {
    /// Each language's keys: plain strings and plural rules together.
    private func keys(for language: AppLanguage) throws -> [String: Any] {
        let folder = try #require(Bundle.main.url(forResource: language.rawValue, withExtension: "lproj"),
                                  "missing \(language.rawValue).lproj")
        var keys: [String: Any] = [:]
        for file in ["Localizable.strings", "Localizable.stringsdict"] {
            let url = folder.appending(path: file)
            guard let dictionary = NSDictionary(contentsOf: url) as? [String: Any] else { continue }
            keys.merge(dictionary) { current, _ in current }
        }
        return keys
    }

    /// The placeholders a format string fills in, by type and in argument order.
    private func placeholders(in text: String) -> [String] {
        let pattern = /%(?:(\d+)\$)?(@|lld)/
        let matches = text.matches(of: pattern)
        let ordered = matches.enumerated().map { index, match in
            (position: match.output.1.flatMap { Int($0) } ?? index + 1, type: String(match.output.2))
        }
        return ordered.sorted { $0.position < $1.position }.map(\.type)
    }

    /// English only compiles its plural rules (every other key is its own English text), so the
    /// translations are checked against each other: a string any language has, all of them have.
    @Test func everyLanguageCarriesEveryString() throws {
        let translations = AppLanguage.allCases.filter { $0 != .english }
        let all = try translations.reduce(into: Set<String>()) { $0.formUnion(try keys(for: $1).keys) }
        #expect(all.count > 300)
        for language in translations {
            let missing = all.subtracting(try keys(for: language).keys)
            #expect(missing.isEmpty, "\(language.rawValue) is missing \(missing.sorted())")
        }
    }

    @Test func translationsKeepTheirPlaceholders() throws {
        for language in AppLanguage.allCases {
            for (key, value) in try keys(for: language) {
                guard let text = value as? String else { continue } // plural rules are checked by the formatter
                #expect(placeholders(in: text) == placeholders(in: key), "\(language.rawValue): \(key) → \(text)")
            }
        }
    }

    @Test("Strings resolve in each language", arguments: AppLanguage.allCases)
    func resolvesInEachLanguage(language: AppLanguage) {
        let bundle = AppLocalization.bundle(for: language)
        let title = String(appLocalized: "Language", bundle: bundle, locale: language.locale)
        let expected = ["en": "Language", "es": "Idioma", "fr": "Langue", "de": "Sprache", "it": "Lingua",
                        "pt-PT": "Idioma", "ja": "言語", "ko": "언어", "zh-Hans": "语言"]
        #expect(title == expected[language.rawValue])
    }

    @Test func pluralsFollowTheCount() {
        let english = AppLocalization.bundle(for: .english)
        #expect(String(appLocalized: "\(1) open tasks", bundle: english) == "1 open task")
        #expect(String(appLocalized: "\(3) open tasks", bundle: english) == "3 open tasks")
        let spanish = AppLocalization.bundle(for: .spanish)
        let one = String(appLocalized: "\(1) open tasks", bundle: spanish, locale: AppLanguage.spanish.locale)
        let three = String(appLocalized: "\(3) open tasks", bundle: spanish, locale: AppLanguage.spanish.locale)
        #expect(one != three)
        #expect(one.hasPrefix("1 ") && three.hasPrefix("3 "))
    }

    /// keys.toml explains each action in English whatever the app language, like the names it explains.
    @Test func keysTomlStaysInEnglish() {
        #expect(ShortcutAction.newTask.summary(bundle: AppLocalization.bundle(for: .english)) == "New task")
        #expect(ShortcutAction.newTask.summary(bundle: AppLocalization.bundle(for: .german)) != "New task")
        #expect(ShortcutConfig.defaultFileText().contains("# New task"))
    }
}
