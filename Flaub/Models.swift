import SwiftUI
import Foundation

/// One entry of the catalogue, as stored in the bundled `words.json`.
struct Word: Identifiable, Hashable, Decodable {
    let text: String
    let level: Int
    let partOfSpeech: String
    let pronunciation: String
    let meaning: String
    let example: String
    let synonyms: [String]
    let origin: String
    /// A sentence from a public-domain book that uses the word, when one was found.
    let quote: String?
    let quoteSource: String?

    var id: String { text }

    /// The meaning with its part of speech, as shown under the word.
    var definition: String { "(\(partOfSpeech)) \(meaning)" }

    enum CodingKeys: String, CodingKey {
        case text = "lemma"
        case level
        case partOfSpeech = "part_of_speech"
        case pronunciation = "ipa"
        case meaning = "definition"
        case example
        case synonyms
        case origin
        case quote
        case quoteSource = "quote_source"
    }

    /// The words shown today in the feed and used by the quizzes.
    static var samples: [Word] { Catalog.feed }
}

/// The word catalogue, built by `content/build_catalog.py` and bundled with the app.
enum Catalog {
    static let all: [Word] = load()

    /// Twenty words for today. The selection changes each day, stays the same all
    /// day, and steps through the catalogue so that levels are mixed.
    static let feed: [Word] = {
        let count = all.count
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        var step = 37
        while greatestCommonDivisor(step, count) != 1 {
            step += 1
        }
        let start = (day * 20) % count
        return (0..<min(20, count)).map { all[(start + $0 * step) % count] }
    }()

    private static func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int {
        b == 0 ? a : greatestCommonDivisor(b, a % b)
    }

    /// The word used in the onboarding preview card.
    static var featured: Word {
        all.first { $0.text == "ephemeral" } ?? all[0]
    }

    private static func load() -> [Word] {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let words = try? JSONDecoder().decode([Word].self, from: data),
              !words.isEmpty else {
            return [fallback]
        }
        return words
    }

    /// Shown only if the bundled file is missing or unreadable.
    private static let fallback = Word(
        text: "ephemeral", level: 2, partOfSpeech: "adj.", pronunciation: "ɪˈfɛmɚəl",
        meaning: "Lasting for a very short time",
        example: "The beauty of cherry blossoms is ephemeral, gone within a week.",
        synonyms: ["fleeting", "transient", "brief"],
        origin: "From Greek ephēmeros, meaning “lasting only a day.”",
        quote: nil, quoteSource: nil
    )
}

struct Topic: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let image: String
    let locked: Bool

    static let all: [Topic] = [
        Topic(name: "Emotions", image: "topic_emotions", locked: false),
        Topic(name: "Persuasion", image: "topic_persuasion", locked: true),
        Topic(name: "Business", image: "topic_business", locked: true),
        Topic(name: "Literature", image: "topic_literature", locked: true),
        Topic(name: "Science", image: "topic_science", locked: true),
        Topic(name: "Travel", image: "topic_travel", locked: true),
        Topic(name: "Nature", image: "topic_nature", locked: true),
        Topic(name: "Debate", image: "topic_debate", locked: true)
    ]
}

/// The characters and backgrounds a member can combine into an app icon.
enum IconOptions {
    static let characters: [(name: String, image: String)] = [
        ("Gustave Flaubert", "char_flaubert"),
        ("George Sand", "char_sand"),
        ("Jane Austen", "char_austen"),
        ("Virginia Woolf", "char_woolf"),
        ("Mary Shelley", "char_shelley"),
        ("Emily Dickinson", "char_dickinson")
    ]

    static let backgrounds: [(name: String, color: Color)] = [
        ("Cream", Color(hex: 0xFFF8F4)),
        ("Blue", Color(hex: 0x0A5CFF)),
        ("Coral", Color(hex: 0xF54B40)),
        ("Mustard", Color(hex: 0xFAB128)),
        ("Lime", Color(hex: 0xE4F06A)),
        ("Purple", Color(hex: 0x762C89)),
        ("Teal", Color(hex: 0x1F8A8C)),
        ("Pink", Color(hex: 0xF9A8D4))
    ]
}

struct VoiceOption: Identifiable {
    let id: String
    let name: String

    static let all: [VoiceOption] = [
        VoiceOption(id: "en-US", name: "American"),
        VoiceOption(id: "en-GB", name: "British"),
        VoiceOption(id: "en-AU", name: "Australian")
    ]
}
