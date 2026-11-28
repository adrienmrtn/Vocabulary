import SwiftUI

/// The languages the app teaches. One choice sets the word catalogue and the
/// interface together: a member who learns French words reads the app in French.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case french = "fr"
    case spanish = "es"
    case italian = "it"
    case german = "de"
    case portugueseBrazil = "pt-BR"
    case portuguesePortugal = "pt-PT"
    case dutch = "nl"
    case swedish = "sv"
    case danish = "da"
    case norwegian = "nb"
    case finnish = "fi"
    case polish = "pl"
    case czech = "cs"
    case slovak = "sk"
    case slovenian = "sl"
    case croatian = "hr"
    case hungarian = "hu"
    case romanian = "ro"
    case greek = "el"
    case russian = "ru"
    case turkish = "tr"
    case arabic = "ar"
    case hebrew = "he"
    case japanese = "ja"

    var id: String { rawValue }

    /// The language's own name (never translated), its flag, and the voice used
    /// until the member picks one.
    private var details: (name: String, flag: String, voice: String) {
        switch self {
        case .english: return ("English", "🇬🇧", "en-US")
        case .french: return ("Français", "🇫🇷", "fr-FR")
        case .spanish: return ("Español", "🇪🇸", "es-ES")
        case .italian: return ("Italiano", "🇮🇹", "it-IT")
        case .german: return ("Deutsch", "🇩🇪", "de-DE")
        case .portugueseBrazil: return ("Português (Brasil)", "🇧🇷", "pt-BR")
        case .portuguesePortugal: return ("Português (Portugal)", "🇵🇹", "pt-PT")
        case .dutch: return ("Nederlands", "🇳🇱", "nl-NL")
        case .swedish: return ("Svenska", "🇸🇪", "sv-SE")
        case .danish: return ("Dansk", "🇩🇰", "da-DK")
        case .norwegian: return ("Norsk", "🇳🇴", "nb-NO")
        case .finnish: return ("Suomi", "🇫🇮", "fi-FI")
        case .polish: return ("Polski", "🇵🇱", "pl-PL")
        case .czech: return ("Čeština", "🇨🇿", "cs-CZ")
        case .slovak: return ("Slovenčina", "🇸🇰", "sk-SK")
        case .slovenian: return ("Slovenščina", "🇸🇮", "sl-SI")
        case .croatian: return ("Hrvatski", "🇭🇷", "hr-HR")
        case .hungarian: return ("Magyar", "🇭🇺", "hu-HU")
        case .romanian: return ("Română", "🇷🇴", "ro-RO")
        case .greek: return ("Ελληνικά", "🇬🇷", "el-GR")
        case .russian: return ("Русский", "🇷🇺", "ru-RU")
        case .turkish: return ("Türkçe", "🇹🇷", "tr-TR")
        case .arabic: return ("العربية", "🇸🇦", "ar-SA")
        case .hebrew: return ("עברית", "🇮🇱", "he-IL")
        case .japanese: return ("日本語", "🇯🇵", "ja-JP")
        }
    }

    var name: String { details.name }
    var flag: String { details.flag }
    var defaultVoice: String { details.voice }

    /// Arabic and Hebrew are laid out from right to left.
    var isRightToLeft: Bool { self == .arabic || self == .hebrew }

    /// What the device is set to, when the app teaches that language.
    static var device: AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("pt") {
            return preferred.contains("PT") ? .portuguesePortugal : .portugueseBrazil
        }
        if preferred.hasPrefix("no") || preferred.hasPrefix("nn") {
            return .norwegian
        }
        if preferred.hasPrefix("iw") {
            return .hebrew
        }
        return AppLanguage(rawValue: String(preferred.prefix(2))) ?? .english
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
