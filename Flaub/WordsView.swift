import SwiftUI

/// The home tab: one word, full screen. A vertical drag moves to the next or
/// previous word, but the change itself is a soft cross-fade, not a slide.
struct WordsView: View {
    @State private var index = 0
    @State private var liked: Set<String> = []
    @State private var saved: Set<String> = []
    @State private var showDetail = false

    private let words = Word.samples

    var body: some View {
        let word = words[index]

        ZStack {
            Color.cream.ignoresSafeArea()

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
                        Text(word.pronunciation)
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundStyle(Color.flaubBlue)
                    }
                    .font(.system(size: 16, weight: .medium))
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(Capsule().fill(Color.white))
                    .overlay(Capsule().stroke(Color.line, lineWidth: 1.5))
                }
                .accessibilityLabel("Listen to \(word.text)")

                Text(word.definition)
                    .font(.serif(22, weight: .medium))
                    .multilineTextAlignment(.center)

                HStack(spacing: 30) {
                    iconButton("info.circle", label: "More about this word") {
                        showDetail = true
                    }
                    ShareLink(item: "\(word.text): \(word.definition)") {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 28))
                            .frame(width: 48, height: 48)
                    }
                    iconButton(liked.contains(word.text) ? "heart.fill" : "heart", label: "Like",
                               tint: liked.contains(word.text) ? Color.flaubBlue : Color.ink) {
                        toggle(&liked, word.text)
                    }
                    iconButton(saved.contains(word.text) ? "bookmark.fill" : "bookmark", label: "Save to collection",
                               tint: saved.contains(word.text) ? Color.flaubBlue : Color.ink) {
                        toggle(&saved, word.text)
                    }
                }
                .padding(.top, 16)
            }
            .foregroundStyle(Color.ink)
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
    }

    private func go(_ delta: Int) {
        let next = index + delta
        guard words.indices.contains(next) else { return }
        Haptics.page()
        withAnimation(.easeInOut(duration: 0.35)) {
            index = next
        }
    }

    private func toggle(_ set: inout Set<String>, _ value: String) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
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
                    detail("Origin", word.origin)
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
