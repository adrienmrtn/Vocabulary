import SwiftUI

struct Word: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let pronunciation: String
    let definition: String
    let example: String
    let synonyms: [String]
    let origin: String

    /// Sample content. Replace with the real word source.
    static let samples: [Word] = [
        Word(text: "ephemeral", pronunciation: "ɪˈfem.ər.əl", definition: "(adj.) Lasting for a very short time",
             example: "The beauty of cherry blossoms is ephemeral, gone within a week.",
             synonyms: ["fleeting", "transient", "short-lived"],
             origin: "From Greek ephēmeros, meaning “lasting only a day.”"),
        Word(text: "tenacious", pronunciation: "təˈneɪ.ʃəs", definition: "(adj.) Not giving up easily; very determined",
             example: "She was tenacious in the negotiation and got the deal signed.",
             synonyms: ["persistent", "dogged", "resolute"],
             origin: "From Latin tenere, “to hold.”"),
        Word(text: "serendipity", pronunciation: "ˌser.ənˈdɪp.ə.ti", definition: "(n.) Finding something good by happy accident",
             example: "Meeting her at that conference was pure serendipity.",
             synonyms: ["fluke", "chance", "windfall"],
             origin: "Coined by Horace Walpole in 1754, after the tale of the three princes of Serendip."),
        Word(text: "eloquent", pronunciation: "ˈel.ə.kwənt", definition: "(adj.) Able to express ideas clearly and well",
             example: "He gave an eloquent speech that moved the whole room.",
             synonyms: ["articulate", "fluent", "expressive"],
             origin: "From Latin eloqui, “to speak out.”"),
        Word(text: "resilient", pronunciation: "rɪˈzɪl.i.ənt", definition: "(adj.) Able to recover quickly from difficulty",
             example: "Children are often more resilient than adults expect.",
             synonyms: ["tough", "hardy", "adaptable"],
             origin: "From Latin resilire, “to leap back.”")
    ]
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
