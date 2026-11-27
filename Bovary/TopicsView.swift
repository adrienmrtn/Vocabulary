import SwiftUI

struct TopicsView: View {
    @State private var query = ""

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    private let shortcuts: [(title: String, symbol: String)] = [
        ("Favorites", "heart.fill"),
        ("Collections", "bookmark"),
        ("Your own words", "pencil.line"),
        ("History", "clock")
    ]

    private var topics: [Topic] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return Topic.all }
        return Topic.all.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ScreenHeader(title: "Explore topics")
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.muted)
                        TextField("Search", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(Capsule().fill(Color(hex: 0xF3EAE4)))
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(shortcuts, id: \.title) { shortcut in
                            NavigationLink {
                                destination(for: shortcut.title)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: shortcut.symbol)
                                        .font(.system(size: 20))
                                        .foregroundStyle(Color.brandBlue)
                                        .frame(width: 26)
                                    Text(shortcut.title)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(Color.ink)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 14)
                                .frame(height: 62)
                                .card()
                            }
                        }
                    }

                    Text("About ourselves")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(topics) { topic in
                            NavigationLink {
                                TopicScreen(topic: topic)
                            } label: {
                                TopicTile(topic: topic)
                            }
                        }
                    }
                }
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .tabRoot()
        }
    }
}

extension TopicsView {
    @ViewBuilder
    func destination(for title: String) -> some View {
        switch title {
        case "Favorites": FavoritesScreen()
        case "Collections": CollectionsScreen()
        case "Your own words": OwnWordsScreen()
        default: HistoryScreen()
        }
    }
}

struct TopicTile: View {
    let topic: Topic

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FillImage(name: topic.image)
                .frame(height: 124)
            Text(topic.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.ink)
                .padding(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

/// Stand-in for screens that are not designed yet. Keeps navigation real.
struct PlaceholderScreen: View {
    let title: String

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            Text("Coming soon")
                .font(.serif(22, weight: .medium))
                .foregroundStyle(Color.muted)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Haptics.page() }
    }
}
