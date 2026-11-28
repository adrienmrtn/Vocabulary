import WidgetKit
import SwiftUI

/// The word of the day, on the Home Screen and on the Lock Screen.
///
/// The widget carries its own copy of the catalogue (`words.json`, written by
/// `content/build_catalog.py`) and picks the day's word with the same rule as
/// the first word of the app's daily feed, so it needs nothing from the app.
///
/// It cannot read the language chosen in the app, so it follows the device:
/// the words of the device's language when the app teaches it
/// (`words_<code>.json`), English otherwise.

struct DayWord: Decodable {
    let lemma: String
    let partOfSpeech: String
    let definition: String

    enum CodingKeys: String, CodingKey {
        case lemma
        case partOfSpeech = "part_of_speech"
        case definition
    }

    /// The meaning with its part of speech, as the app shows it.
    var meaning: String { "(\(partOfSpeech)) \(definition)" }
}

enum WidgetCatalog {
    /// name, description, and a word to show if the file cannot be read.
    private static let texts: [String: (name: String, summary: String, word: DayWord)] = [
        "en": ("Word of the day", "A new word every day, with its meaning.",
               DayWord(lemma: "ephemeral", partOfSpeech: "adj.", definition: "Lasting for a very short time")),
        "fr": ("Mot du jour", "Un nouveau mot chaque jour, avec son sens.",
               DayWord(lemma: "éphémère", partOfSpeech: "adj.", definition: "Qui ne dure que très peu de temps")),
        "es": ("Palabra del día", "Una palabra nueva cada día, con su significado.",
               DayWord(lemma: "efímero", partOfSpeech: "adj.", definition: "Que dura muy poco tiempo")),
        "it": ("Parola del giorno", "Una parola nuova ogni giorno, con il suo significato.",
               DayWord(lemma: "effimero", partOfSpeech: "agg.", definition: "Che dura pochissimo tempo")),
        "de": ("Wort des Tages", "Jeden Tag ein neues Wort mit seiner Bedeutung.",
               DayWord(lemma: "vergänglich", partOfSpeech: "Adj.", definition: "Nur von kurzer Dauer"))
    ]

    static let language: String = {
        let code = String((Locale.preferredLanguages.first ?? "en").prefix(2))
        return texts[code] == nil ? "en" : code
    }()

    static let displayName: String = texts[language]!.name
    static let heading: String = displayName.uppercased()
    static let summary: String = texts[language]!.summary

    static let all: [DayWord] = {
        guard let url = Bundle.main.url(forResource: language == "en" ? "words" : "words_\(language)",
                                        withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let words = try? JSONDecoder().decode([DayWord].self, from: data) else { return [] }
        return words
    }()

    static let fallback: DayWord = texts[language]!.word

    static func word(on date: Date) -> DayWord {
        guard !all.isEmpty else { return fallback }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return all[(day * 20) % all.count]
    }
}

struct WordEntry: TimelineEntry {
    let date: Date
    let word: DayWord
}

struct WordProvider: TimelineProvider {
    func placeholder(in context: Context) -> WordEntry {
        WordEntry(date: Date(), word: WidgetCatalog.fallback)
    }

    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) {
        completion(WordEntry(date: Date(), word: WidgetCatalog.word(on: Date())))
    }

    /// One entry per day for the coming week, each starting at midnight.
    func getTimeline(in context: Context, completion: @escaping (Timeline<WordEntry>) -> Void) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let entries = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
            .map { WordEntry(date: $0, word: WidgetCatalog.word(on: $0)) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct WordWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordEntry

    private let blue = Color(red: 10 / 255, green: 92 / 255, blue: 1)

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if family == .systemSmall || family == .systemMedium {
                    blue
                } else {
                    Color.clear
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Text("\(entry.word.lemma): \(entry.word.definition)")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.word.lemma)
                    .font(.system(.headline, design: .serif))
                    .widgetAccentable()
                Text(entry.word.meaning)
                    .font(.caption)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 6) {
                Text(WidgetCatalog.heading)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .opacity(0.8)
                Text(entry.word.lemma)
                    .font(.system(size: family == .systemMedium ? 30 : 24, weight: .bold, design: .serif))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(entry.word.meaning)
                    .font(.system(size: family == .systemMedium ? 15 : 13))
                    .lineLimit(family == .systemMedium ? 3 : 4)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct WordOfTheDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WordOfTheDay", provider: WordProvider()) { entry in
            WordWidgetView(entry: entry)
        }
        .configurationDisplayName(WidgetCatalog.displayName)
        .description(WidgetCatalog.summary)
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct BovaryWidgets: WidgetBundle {
    var body: some Widget {
        WordOfTheDayWidget()
    }
}
