import SwiftUI

/// The home tab: one word per screen, in a vertical feed that pages like a
/// deck of cards. The word under the finger follows it, the next one rises
/// into place, and each landing gives a soft tap.
struct WordsView: View {
    @State private var current: String?
    @State private var detail: Word?
    @State private var showThemes = false
    @ObservedObject private var store = UserStore.shared
    @AppStorage("theme") private var themeIndex = 0

    private let words = Word.samples

    var body: some View {
        let theme = AppTheme.at(themeIndex)

        ZStack(alignment: .topTrailing) {
            feed(theme)
            Button {
                Haptics.tap()
                showThemes = true
            } label: {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.text)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(theme.text.opacity(0.1)))
                    .overlay(Circle().stroke(theme.text.opacity(0.25), lineWidth: 1.5))
            }
            .accessibilityLabel("Change theme")
            .padding(.trailing, 16)
            .padding(.top, 8)
        }
        .onChange(of: current) { _, landed in
            guard let landed else { return }
            Haptics.page()
            store.markSeen(landed)
        }
        .onAppear {
            if let first = words.first {
                store.markSeen(current ?? first.text)
            }
        }
        .sheet(item: $detail) { word in
            WordDetailView(word: word)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showThemes) {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Choose a theme")
                        .font(.serif(26))
                        .foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ThemeGrid()
                }
                .padding(20)
            }
            .background(Color.cream)
            .presentationDetents([.medium, .large])
        }
    }

    private func feed(_ theme: AppTheme) -> some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(words) { word in
                        page(word, theme: theme)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .scrollTransition(.interactive, axis: .vertical) { content, phase in
                                content
                                    .opacity(phase.isIdentity ? 1 : 0.25)
                                    .scaleEffect(phase.isIdentity ? 1 : 0.9)
                                    .blur(radius: phase.isIdentity ? 0 : 3)
                            }
                            .id(word.text)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $current)
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(theme.ground)
        .ignoresSafeArea()
    }

    private func page(_ word: Word, theme: AppTheme) -> some View {
        let liked = store.isFavorite(word.text)

        return VStack(spacing: 14) {
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

            Button {
                Haptics.tap()
                detail = word
            } label: {
                Text("Example, synonyms and origin")
                    .font(.system(size: 14, weight: .medium))
                    .underline()
                    .foregroundStyle(theme.text.opacity(0.75))
                    .frame(height: 44)
            }
            iconButton(liked ? "heart.fill" : "heart", label: "Favorite", tint: theme.text) {
                store.toggleFavorite(word.text)
            }
        }
        .foregroundStyle(theme.text)
        .padding(.horizontal, 28)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(word.text)
                        .font(.serif(40))
                    if !word.pronunciation.isEmpty {
                        Text("/\(word.pronunciation)/")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.muted)
                    }
                }
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
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 20)
        }
        .background(Color.cream)
    }

    private func detail(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 13)).foregroundStyle(Color.muted)
            Text(text).font(.system(size: 16))
        }
    }
}
