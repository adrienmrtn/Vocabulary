import SwiftUI

/// The home tab: one word, full screen. A vertical drag moves to the next or
/// previous word, but the change itself is a soft cross-fade, not a slide.
struct WordsView: View {
    @State private var index = 0
    @State private var showDetail = false
    @ObservedObject private var store = UserStore.shared
    @AppStorage("theme") private var themeIndex = 0

    private let words = Word.samples

    var body: some View {
        let word = words[index]
        let theme = AppTheme.at(themeIndex)
        let liked = store.isFavorite(word.text)
        let saved = store.isSaved(word.text)

        ZStack {
            theme.ground.ignoresSafeArea()

            VStack(spacing: 14) {
                Text(word.text)
                    .font(.serif(52))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Button {
                    Haptics.tap()
                    Speaker.shared.say(word.text)
                } label: {
                    HStack(spacing: 10) {
                        Text(word.pronunciation.isEmpty ? "Listen" : word.pronunciation)
                        Image(systemName: "speaker.wave.2.fill")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(theme.text)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(Capsule().fill(theme.text.opacity(0.08)))
                    .overlay(Capsule().stroke(theme.text.opacity(0.25), lineWidth: 1.5))
                }
                .accessibilityLabel("Listen to \(word.text)")

                Text(word.definition)
                    .font(.serif(22, weight: .medium))
                    .multilineTextAlignment(.center)

                HStack(spacing: 30) {
                    iconButton("info.circle", label: "More about this word", tint: theme.text) {
                        showDetail = true
                    }
                    ShareLink(item: "\(word.text): \(word.definition)") {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 28))
                            .foregroundStyle(theme.text)
                            .frame(width: 48, height: 48)
                    }
                    iconButton(liked ? "heart.fill" : "heart", label: "Like", tint: theme.text) {
                        store.toggleFavorite(word.text)
                    }
                    iconButton(saved ? "bookmark.fill" : "bookmark", label: "Save to collection", tint: theme.text) {
                        store.toggleSaved(word.text)
                    }
                }
                .padding(.top, 16)
            }
            .foregroundStyle(theme.text)
            .padding(.horizontal, 28)
            .id(index)
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24).onEnded { value in
                if value.translation.height < -50 {
                    go(1)
                } else if value.translation.height > 50 {
                    go(-1)
                }
            }
        )
        .sheet(isPresented: $showDetail) {
            WordDetailView(word: word)
                .presentationDetents([.medium, .large])
        }
        .onAppear {
            store.markSeen(word.text)
        }
    }

    private func go(_ delta: Int) {
        let next = index + delta
        guard words.indices.contains(next) else { return }
        Haptics.page()
        withAnimation(.easeInOut(duration: 0.35)) {
            index = next
        }
        store.markSeen(words[next].text)
    }

    private func iconButton(_ symbol: String, label: String, tint: Color = Color.ink,
                            action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 28))
                .foregroundStyle(tint)
                .frame(width: 48, height: 48)
        }
        .accessibilityLabel(label)
    }
}

struct WordDetailView: View {
    let word: Word

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(word.definition)
                        .font(.serif(22, weight: .medium))
                    detail("Example", word.example)
                    if let quote = word.quote, !quote.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("In literature").font(.system(size: 13)).foregroundStyle(Color.muted)
                            Text(quote).font(.serif(18, weight: .medium))
                            if let source = word.quoteSource, !source.isEmpty {
                                Text("— \(source)").font(.system(size: 14)).foregroundStyle(Color.muted)
                            }
                        }
                    }
                    if !word.synonyms.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Synonyms").font(.system(size: 13)).foregroundStyle(Color.muted)
                            HStack(spacing: 6) {
                                ForEach(word.synonyms, id: \.self) { synonym in
                                    Text(synonym)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color(hex: 0x0A3FB3))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(Color.blueTint))
                                }
                            }
                        }
                    }
                    if !word.origin.isEmpty {
                        detail("Origin", word.origin)
                    }
                }
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(Color.cream)
            .navigationTitle(word.text)
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func detail(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 13)).foregroundStyle(Color.muted)
            Text(text).font(.system(size: 16))
        }
    }
}
