import SwiftUI
import Foundation
import UIKit

struct WordCollection: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var words: [String]
}

struct CustomWord: Identifiable, Codable, Hashable {
    var id: String
    var word: String
    var partOfSpeech: String
    var definition: String

    enum CodingKeys: String, CodingKey {
        case id, word, definition
        case partOfSpeech = "part_of_speech"
    }
}

struct HistoryEntry: Codable, Hashable {
    var lemma: String
    var seenAt: String

    enum CodingKeys: String, CodingKey {
        case lemma
        case seenAt = "seen_at"
    }
}

/// Everything the member owns, in the shape the database functions
/// `sync_user_state` and `get_user_state` exchange.
struct UserState: Codable {
    var displayName = ""
    var onboarding: [String: [String]] = [:]
    var theme = 0
    var iconCharacter = 0
    var iconBackground = 0
    var favorites: [String] = []
    var collections: [WordCollection] = []
    var customWords: [CustomWord] = []
    var history: [HistoryEntry] = []
    var review: [String: Int] = [:]
    var activityDays: [String] = []

    enum CodingKeys: String, CodingKey {
        case onboarding, theme, favorites, collections, history, review
        case displayName = "display_name"
        case iconCharacter = "icon_character"
        case iconBackground = "icon_background"
        case customWords = "custom_words"
        case activityDays = "activity_days"
    }

    var isEmpty: Bool {
        favorites.isEmpty && collections.isEmpty && customWords.isEmpty && history.isEmpty
            && review.isEmpty && onboarding.isEmpty && activityDays.isEmpty
    }
}

/// The member's data. It lives on the device first, so the app works offline
/// and without an account; every change is then sent to Supabase when signed in.
final class UserStore: ObservableObject {
    static let shared = UserStore()

    private static let storageKey = "userState"
    static let savedCollectionName = "Saved"

    @Published private(set) var state: UserState

    private init() {
        if let data = UserDefaults.standard.data(forKey: UserStore.storageKey),
           let saved = try? JSONDecoder().decode(UserState.self, from: data) {
            state = saved
        } else {
            state = UserState()
        }
    }

    private func commit() {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: UserStore.storageKey)
        }
        Backend.shared.scheduleSync()
    }

    // MARK: Favorites

    func isFavorite(_ lemma: String) -> Bool {
        state.favorites.contains(lemma)
    }

    func toggleFavorite(_ lemma: String) {
        if let index = state.favorites.firstIndex(of: lemma) {
            state.favorites.remove(at: index)
        } else {
            state.favorites.insert(lemma, at: 0)
        }
        commit()
    }

    // MARK: Collections

    func isSaved(_ lemma: String) -> Bool {
        state.collections.contains { $0.words.contains(lemma) }
    }

    /// The bookmark button: adds to the "Saved" collection, or removes from every collection.
    func toggleSaved(_ lemma: String) {
        if isSaved(lemma) {
            for index in state.collections.indices {
                state.collections[index].words.removeAll { $0 == lemma }
            }
        } else {
            if !state.collections.contains(where: { $0.name == UserStore.savedCollectionName }) {
                state.collections.insert(
                    WordCollection(id: UUID().uuidString.lowercased(), name: UserStore.savedCollectionName, words: []),
                    at: 0
                )
            }
            if let index = state.collections.firstIndex(where: { $0.name == UserStore.savedCollectionName }) {
                state.collections[index].words.insert(lemma, at: 0)
            }
        }
        commit()
    }

    func addCollection(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        state.collections.append(WordCollection(id: UUID().uuidString.lowercased(), name: trimmed, words: []))
        commit()
    }

    func deleteCollection(_ id: String) {
        state.collections.removeAll { $0.id == id }
        commit()
    }

    func remove(_ lemma: String, fromCollection id: String) {
        guard let index = state.collections.firstIndex(where: { $0.id == id }) else { return }
        state.collections[index].words.removeAll { $0 == lemma }
        commit()
    }

    // MARK: Own words

    func addCustomWord(_ word: String, partOfSpeech: String, definition: String) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        state.customWords.insert(
            CustomWord(id: UUID().uuidString.lowercased(), word: trimmed, partOfSpeech: partOfSpeech,
                       definition: definition.trimmingCharacters(in: .whitespacesAndNewlines)),
            at: 0
        )
        commit()
    }

    func deleteCustomWord(_ id: String) {
        state.customWords.removeAll { $0.id == id }
        commit()
    }

    // MARK: History and streak

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func dayString(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    /// Records that a word was shown, and that the member was active today.
    func markSeen(_ lemma: String) {
        let now = ISO8601DateFormatter().string(from: Date())
        state.history.removeAll { $0.lemma == lemma }
        state.history.insert(HistoryEntry(lemma: lemma, seenAt: now), at: 0)
        if state.history.count > 500 {
            state.history = Array(state.history.prefix(500))
        }
        addToday()
        commit()
    }

    func markActive() {
        addToday()
        commit()
    }

    private func addToday() {
        let today = UserStore.dayString(Date())
        if !state.activityDays.contains(today) {
            state.activityDays.append(today)
        }
    }

    func wasActive(on date: Date) -> Bool {
        state.activityDays.contains(UserStore.dayString(date))
    }

    /// Consecutive active days, counting back from today (or from yesterday if
    /// today has not started yet).
    var streak: Int {
        let calendar = Calendar.current
        var day = Date()
        if !wasActive(on: day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day), wasActive(on: yesterday) else {
                return 0
            }
            day = yesterday
        }
        var count = 0
        while wasActive(on: day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    /// The last seven days, oldest first, for the streak row.
    var week: [(label: String, done: Bool)] {
        let calendar = Calendar.current
        let symbols = calendar.shortWeekdaySymbols
        return (0..<7).reversed().compactMap { offset -> (label: String, done: Bool)? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            let weekday = calendar.component(.weekday, from: date)
            return (String(symbols[weekday - 1].prefix(2)), wasActive(on: date))
        }
    }

    // MARK: Profile

    func setName(_ name: String) {
        state.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        commit()
    }

    func setOnboarding(_ question: String, answers: [String]) {
        state.onboarding[question] = answers
        commit()
    }

    func reviewChanged() {
        addToday()
        commit()
    }

    // MARK: Sync

    /// The full state to send: what this store holds plus the settings kept elsewhere.
    func snapshot() -> UserState {
        var copy = state
        copy.theme = UserDefaults.standard.integer(forKey: "theme")
        copy.iconCharacter = UserDefaults.standard.integer(forKey: "iconCharacter")
        copy.iconBackground = UserDefaults.standard.integer(forKey: "iconBackground")
        copy.review = ReviewStore.shared.allBoxes
        return copy
    }

    /// Replace the local state with the one stored on the server (fresh install, same account).
    func adopt(_ remote: UserState) {
        state = remote
        UserDefaults.standard.set(remote.theme, forKey: "theme")
        UserDefaults.standard.set(remote.iconCharacter, forKey: "iconCharacter")
        UserDefaults.standard.set(remote.iconBackground, forKey: "iconBackground")
        ReviewStore.shared.replace(with: remote.review)
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: UserStore.storageKey)
        }
    }
}

/// Switches the real Home Screen icon. Each character and background pair is an
/// alternate icon set in the asset catalogue, named "Icon-<character>-<background>".
enum AppIcon {
    static func name(character: Int, background: Int) -> String? {
        character == 0 && background == 0 ? nil : "Icon-\(character)-\(background)"
    }

    static func apply(character: Int, background: Int) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let wanted = name(character: character, background: background)
        guard UIApplication.shared.alternateIconName != wanted else { return }
        UIApplication.shared.setAlternateIconName(wanted) { _ in }
        Backend.shared.scheduleSync()
    }
}
