import SwiftUI

struct PracticeView: View {
    private let challenges: [(name: String, image: String)] = [
        ("Sprint", "ch_sprint"),
        ("Rush", "ch_rush"),
        ("Perfection", "ch_perfection")
    ]
    private let categories = Array(Topic.all.prefix(4))

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    PremiumBanner(title: "Unlock everything",
                                  subtitle: "Access all games, topics, words, themes, and remove ads!")

                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("What's your level?")
                                .font(.system(size: 17, weight: .semibold))
                            Text("See how much you currently know")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.muted)
                            NavigationLink {
                                QuizView(title: "Level test")
                            } label: {
                                Text("Take free test")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color(hex: 0x0A4FDB))
                                    .padding(.horizontal, 16)
                                    .frame(height: 44)
                                    .background(Capsule().fill(Color.blueTint))
                            }
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image("level")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 92, height: 92)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(16)
                    .card()

                    SectionLabel(text: "For you")
                    NavigationLink {
                        PlaceholderScreen(title: "Your history")
                    } label: {
                        ImageRow(title: "Your history", image: "history")
                    }

                    SectionLabel(text: "Challenges")
                    HStack(spacing: 10) {
                        ForEach(challenges, id: \.name) { challenge in
                            NavigationLink {
                                QuizView(title: challenge.name)
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    FillImage(name: challenge.image)
                                        .frame(height: 76)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    Text(challenge.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color.ink)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .card()
                            }
                        }
                    }

                    SectionLabel(text: "Categories")
                    ForEach(categories) { topic in
                        NavigationLink {
                            QuizView(title: topic.name)
                        } label: {
                            ImageRow(title: topic.name, image: topic.image)
                        }
                    }
                }
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color.cream)
            .navigationTitle("Practice")
        }
    }
}

struct ImageRow: View {
    let title: String
    let image: String

    var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.ink)
                .padding(.leading, 18)
            Spacer(minLength: 0)
            FillImage(name: image)
                .frame(width: 110, height: 78)
        }
        .frame(height: 78)
        .card()
    }
}

/// A small fill-the-gap quiz over the sample words, one question per page.
struct QuizView: View {
    let title: String

    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var picked: String?
    @State private var score = 0

    private let words = Array(Word.samples.prefix(8))

    private var finished: Bool { index >= words.count }

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            if finished {
                VStack(spacing: 16) {
                    Text("\(score) / \(words.count)")
                        .font(.serif(56))
                    Text("Nice work. Come back tomorrow for new words.")
                        .font(.system(size: 16))
                        .multilineTextAlignment(.center)
                    PrimaryButton(title: "Done") { dismiss() }
                        .padding(.top, 12)
                }
                .foregroundStyle(Color.ink)
                .padding(24)
                .transition(.opacity)
            } else {
                question(words[index])
                    .id(index)
                    .transition(.opacity.combined(with: .offset(x: 0, y: 12)))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: index)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func question(_ word: Word) -> some View {
        let options = optionList(for: word)
        return VStack(spacing: 14) {
            ProgressView(value: Double(index), total: Double(words.count))
                .tint(Color.flaubBlue)
            Text("Which word means this?")
                .font(.system(size: 13, weight: .semibold))
                .kerning(1)
                .foregroundStyle(Color.muted)
                .padding(.top, 12)
            Text(word.definition)
                .font(.serif(26))
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)
            ForEach(options, id: \.self) { option in
                Button {
                    choose(option, correct: word.text)
                } label: {
                    HStack {
                        Text(option).font(.system(size: 17, weight: .medium))
                        Spacer()
                        if picked == option {
                            Image(systemName: option == word.text ? "checkmark.circle.fill" : "xmark.circle.fill")
                        }
                    }
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 20)
                    .frame(height: 56)
                    .background(Capsule().fill(picked == option ? Color.blueTint : Color.white))
                    .overlay(Capsule().stroke(picked == option ? Color.flaubBlue : Color.line, lineWidth: 1.5))
                }
                .disabled(picked != nil)
            }
            Spacer()
        }
        .foregroundStyle(Color.ink)
        .padding(20)
    }

    private func optionList(for word: Word) -> [String] {
        let position = words.firstIndex(of: word) ?? 0
        // Wrong answers come from the rest of today's words.
        let pool = Word.samples.filter { $0 != word }
        guard pool.count >= 3 else { return [word.text] }
        let others = [1, 2, 3].map { pool[(position * 3 + $0) % pool.count].text }
        var list = others
        list.insert(word.text, at: position % (others.count + 1))
        return list
    }

    private func choose(_ option: String, correct: String) {
        picked = option
        if option == correct {
            score += 1
            Haptics.success()
        } else {
            Haptics.tap()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            picked = nil
            index += 1
            Haptics.page()
        }
    }
}
