import SwiftUI

/// The languages the app teaches. One choice sets the word catalogue and the
/// interface together: a member who learns French words reads the app in French.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case french = "fr"

    var id: String { rawValue }

    /// The language's own name, never translated.
    var name: String {
        switch self {
        case .english: return "English"
        case .french: return "Français"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇬🇧"
        case .french: return "🇫🇷"
        }
    }

    /// The voice used until the member picks one.
    var defaultVoice: String {
        switch self {
        case .english: return "en-US"
        case .french: return "fr-FR"
        }
    }

    /// What the device is set to, when the app teaches that language.
    static var device: AppLanguage {
        (Locale.preferredLanguages.first ?? "en").hasPrefix("fr") ? .french : .english
    }
}

/// The interface texts. The code is written in English; every other language
/// has a file "strings_<code>.json" that maps each English text to its
/// translation. A text with no translation is shown in English.
enum Translations {
    static let storageKey = "appLanguage"

    private(set) static var language: AppLanguage = {
        UserDefaults.standard.string(forKey: storageKey).flatMap(AppLanguage.init(rawValue:)) ?? .device
    }()

    private static var table: [String: String] = read(language)

    static func load(_ new: AppLanguage) {
        language = new
        table = read(new)
    }

    static func text(_ key: String) -> String {
        table[key] ?? key
    }

    private static func read(_ language: AppLanguage) -> [String: String] {
        guard language != .english,
              let url = Bundle.main.url(forResource: "strings_\(language.rawValue)", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let table = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return table
    }
}

/// The text in the member's language.
func tr(_ key: String) -> String {
    Translations.text(key)
}

/// The same, for a text with values in it: each "%@" takes the next value.
func tr(_ key: String, _ values: String...) -> String {
    String(format: Translations.text(key), arguments: values)
}

/// Holds the member's choice and tells the views when it changes.
final class LanguageStore: ObservableObject {
    static let shared = LanguageStore()

    @Published private(set) var language: AppLanguage = Translations.language

    private init() {}

    func choose(_ new: AppLanguage) {
        UserDefaults.standard.set(new.rawValue, forKey: Translations.storageKey)
        // A voice of another language would mispronounce every word.
        let voice = UserDefaults.standard.string(forKey: "voiceLanguage")
        if voice?.hasPrefix(new.rawValue) != true {
            UserDefaults.standard.set(new.defaultVoice, forKey: "voiceLanguage")
        }
        guard new != language else { return }
        Translations.load(new)
        Catalog.reload()
        language = new
        Backend.shared.languageChanged()
    }
}
