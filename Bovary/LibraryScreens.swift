import SwiftUI

// MARK: - Themes

struct AppTheme {
    let name: String
    let ground: Color
    let text: Color

    static let all: [AppTheme] = [
        AppTheme(name: "Cream", ground: Color(hex: 0xFFF8F4), text: Color(hex: 0x1B1A2E)),
        AppTheme(name: "Night", ground: Color(hex: 0x1B1A2E), text: Color(hex: 0xFFF8F4)),
        AppTheme(name: "Blue", ground: Color(hex: 0x0A5CFF), text: .white),
        AppTheme(name: "Coral", ground: Color(hex: 0xF54B40), text: .white),
        AppTheme(name: "Teal", ground: Color(hex: 0x145E61), text: Color(hex: 0xE4F06A)),
        AppTheme(name: "Purple", ground: Color(hex: 0x762C89), text: Color(hex: 0xFFD84A))
    ]

    static func at(_ index: Int) -> AppTheme {
        all[min(max(index, 0), all.count - 1)]
    }
}

/// The six word-feed themes, as tappable cards. Used in onboarding and Profile.
struct ThemeGrid: View {
    @AppStorage("theme") private var theme = 0

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(AppTheme.all.indices, id: \.self) { index in
                Button {
                    Haptics.select()
                    theme = index
                    Backend.shared.scheduleSync()
                } label: {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.all[index].ground)
                        .frame(height: 162)
                        .overlay(Text(tr("Aa")).font(.serif(22)).foregroundStyle(AppTheme.all[index].text))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(index == theme ? Color.brandBlue : Color.line,
                                        lineWidth: index == theme ? 3 : 1.5)
                        )
                        .overlay(alignment: .topTrailing) {
                            if index == theme {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.brandBlue, .white)
                                    .padding(8)
                            }
                        }
                }
                .accessibilityLabel(tr("%@ theme", "\(AppTheme.all[index].name)"))
            }
        }
    }
}

struct ThemesScreen: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(tr("The theme colours the Words tab."))
                    .font(.system(size: 15))
                    .foregroundStyle(Color.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ThemeGrid()
            }
            .padding(20)
        }
        .background(Color.cream)
        .navigationTitle(tr("Themes"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Haptics.page() }
    }
}

// MARK: - Word lists

/// One catalogue word in a list: tap for the detail sheet, heart to favourite.
struct WordRow: View {
    let word: Word
    var caption: String? = nil

    @ObservedObject private var store = UserStore.shared
    @State private var showDetail = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                Haptics.tap()
                showDetail = true
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(word.text).font(.serif(22))
                    Text(word.definition)
                        .font(.system(size: 15))
                        .multilineTextAlignment(.leading)
                    if let caption {
                        Text(tr(caption))
                            .font(.system(size: 12))
                            .foregroundStyle(Color.muted)
                    }
                }
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                Haptics.tap()
                store.toggleFavorite(word.text)
            } label: {
                Image(systemName: store.isFavorite(word.text) ? "heart.fill" : "heart")
                    .font(.system(size: 20))
                    .foregroundStyle(store.isFavorite(word.text) ? Color.brandBlue : Color.ink)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(tr(store.isFavorite(word.text) ? "Remove from favorites" : "Add to favorites"))
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 12)
        .card()
        .sheet(isPresented: $showDetail) {
            WordDetailView(word: word)
                .presentationDetents([.medium, .large])
        }
    }
}

/// The frame shared by the list screens: cream ground, inline title, an empty message.
struct ListScreen<Content: View>: View {
    let title: String
    let isEmpty: Bool
    let emptyMessage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            if isEmpty {
                Text(tr(emptyMessage))
                    .font(.serif(20, weight: .medium))
                    .foregroundStyle(Color.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 120)
                    .frame(maxWidth: .infinity)
            } else {
                LazyVStack(spacing: 10) {
                    content()
                }
                .padding(16)
            }
        }
        .background(Color.cream)
        .navigationTitle(tr(title))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Haptics.page() }
    }
}

struct FavoritesScreen: View {
    @ObservedObject private var store = UserStore.shared

    var body: some View {
        let words = store.state.favorites.compactMap { Catalog.word(for: $0) }
        ListScreen(title: "Favorites", isEmpty: words.isEmpty,
                   emptyMessage: "Tap the heart on a word to keep it here.") {
            ForEach(words) { word in
                WordRow(word: word)
            }
        }
    }
}

struct HistoryScreen: View {
    @ObservedObject private var store = UserStore.shared

    private static let parser = ISO8601DateFormatter()
    private static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    var body: some View {
        let entries = store.state.history.filter { Catalog.word(for: $0.lemma) != nil }
        ListScreen(title: "History", isEmpty: entries.isEmpty,
                   emptyMessage: "The words you see will be listed here.") {
            ForEach(entries, id: \.lemma) { entry in
                if let word = Catalog.word(for: entry.lemma) {
                    WordRow(word: word, caption: when(entry.seenAt))
                }
            }
        }
    }

    private func when(_ stamp: String) -> String? {
        guard let date = HistoryScreen.parser.date(from: stamp) else { return nil }
        return HistoryScreen.relative.localizedString(for: date, relativeTo: Date())
    }
}

struct TopicScreen: View {
    let topic: Topic

    var body: some View {
        let words = topic.words
        ListScreen(title: topic.name, isEmpty: words.isEmpty,
                   emptyMessage: "No words in this topic yet.") {
            NavigationLink {
                GameView(mode: .shuffle, title: topic.name, pool: words)
            } label: {
                Text(tr("Practice these %@ words", "\(words.count)"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Capsule().fill(Color.brandBlue))
            }
            ForEach(words) { word in
                WordRow(word: word)
            }
        }
    }
}

// MARK: - Collections

struct CollectionsScreen: View {
    @ObservedObject private var store = UserStore.shared
    @State private var asking = false
    @State private var newName = ""

    var body: some View {
        ListScreen(title: "Collections", isEmpty: store.state.collections.isEmpty,
                   emptyMessage: "Group words your own way. Tap + to make your first collection.") {
            ForEach(store.state.collections) { collection in
                NavigationLink {
                    CollectionScreen(collectionID: collection.id)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tr(collection.name)).font(.serif(22))
                            Text(collection.words.count == 1 ? tr("1 word") : tr("%@ words", "\(collection.words.count)"))
                                .font(.system(size: 14))
                                .foregroundStyle(Color.muted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.muted)
                    }
                    .foregroundStyle(Color.ink)
                    .padding(16)
                    .card()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newName = ""
                    asking = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(tr("New collection"))
            }
        }
        .alert(tr("New collection"), isPresented: $asking) {
            TextField(tr("Name"), text: $newName)
            Button(tr("Create")) {
                store.addCollection(named: newName)
                Haptics.success()
            }
            Button(tr("Cancel"), role: .cancel) {}
        }
    }
}

struct CollectionScreen: View {
    let collectionID: String

    @ObservedObject private var store = UserStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let collection = store.state.collections.first { $0.id == collectionID }
        let words = (collection?.words ?? []).compactMap { Catalog.word(for: $0) }
        ListScreen(title: collection?.name ?? "Collection", isEmpty: words.isEmpty,
                   emptyMessage: "Tap the bookmark on a word to save it, or add words from any list.") {
            ForEach(words) { word in
                WordRow(word: word)
                    .contextMenu {
                        Button(tr("Remove from collection"), role: .destructive) {
                            store.remove(word.text, fromCollection: collectionID)
                        }
                    }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    store.deleteCollection(collectionID)
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel(tr("Delete collection"))
            }
        }
    }
}

// MARK: - Own words

struct OwnWordsScreen: View {
    @ObservedObject private var store = UserStore.shared
    @State private var adding = false

    var body: some View {
        ListScreen(title: "Your own words", isEmpty: store.state.customWords.isEmpty,
                   emptyMessage: "Met a word somewhere? Tap + to add it with your own definition.") {
            ForEach(store.state.customWords) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.word).font(.serif(22))
                    if !entry.definition.isEmpty {
                        Text(entry.partOfSpeech.isEmpty ? entry.definition : "(\(entry.partOfSpeech)) \(entry.definition)")
                            .font(.system(size: 15))
                    }
                }
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .card()
                .contextMenu {
                    Button(tr("Delete"), role: .destructive) {
                        store.deleteCustomWord(entry.id)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    adding = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(tr("Add a word"))
            }
        }
        .sheet(isPresented: $adding) {
            AddWordSheet()
                .presentationDetents([.medium])
        }
    }
}

struct AddWordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var word = ""
    @State private var definition = ""
    @State private var partOfSpeech = "n."

    private let parts = ["n.", "v.", "adj.", "adv."]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(tr("Word"), text: $word)
                        .textInputAutocapitalization(.never)
                    TextField(tr("Definition"), text: $definition, axis: .vertical)
                    Picker(tr("Part of speech"), selection: $partOfSpeech) {
                        ForEach(parts, id: \.self) { part in
                            Text(tr(part)).tag(part)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(tr("Add a word"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Save")) {
                        UserStore.shared.addCustomWord(word, partOfSpeech: partOfSpeech, definition: definition)
                        Haptics.success()
                        dismiss()
                    }
                    .disabled(word.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Settings

struct SettingsScreen: View {
    @ObservedObject private var store = UserStore.shared
    @AppStorage("hasOnboarded") private var hasOnboarded = true
    @ObservedObject private var language = LanguageStore.shared
    @State private var name = ""

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        Form {
            Section(tr("You")) {
                TextField(tr("Your name"), text: $name)
                    .onSubmit { store.setName(name) }
            }
            Section(tr("App")) {
                Picker(tr("Language"), selection: Binding(get: { language.language },
                                                          set: { language.choose($0) })) {
                    ForEach(AppLanguage.allCases) { option in
                        Text(option.name).tag(option)
                    }
                }
                NavigationLink(tr("Reminders")) { RemindersScreen() }
                NavigationLink(tr("Voices")) { VoiceScreen() }
                NavigationLink(tr("Themes")) { ThemesScreen() }
                NavigationLink(tr("App icon")) { IconScreen() }
            }
            Section {
                Text(tr(Backend.shared.signedIn
                     ? "Your progress is backed up."
                     : "Your progress is saved on this device only."))
                    .foregroundStyle(Color.muted)
            } header: {
                Text(tr("Account"))
            } footer: {
                Text(tr("Sign in with Apple or Google is coming, to keep your progress across devices."))
            }
            Section {
                Button(tr("Replay the onboarding")) {
                    Haptics.tap()
                    withAnimation(.easeInOut(duration: 0.5)) {
                        hasOnboarded = false
                    }
                }
            } footer: {
                Text(tr("Bovary %@", "\(version)"))
            }
        }
        .navigationTitle(tr("Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            name = store.state.displayName
            Haptics.page()
        }
        .onDisappear { store.setName(name) }
    }
}
