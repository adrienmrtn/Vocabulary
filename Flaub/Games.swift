import SwiftUI
import Foundation
import Combine

// MARK: - Rules

/// A mode is a set of rules laid over the same questions.
enum GameMode: String, Identifiable {
    case sprint, rush, perfection, shuffle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sprint: return "Sprint"
        case .rush: return "Rush"
        case .perfection: return "Perfection"
        case .shuffle: return "Game shuffle"
        }
    }

    var rule: String {
        switch self {
        case .sprint: return "Ten questions, as fast as you can"
        case .rush: return "As many right answers as you can in 60 seconds"
        case .perfection: return "Keep going until your first mistake"
        case .shuffle: return "Ten questions, a mix of all games"
        }
    }

    var kinds: [QuestionKind] {
        switch self {
        case .sprint: return [.meaning, .gap, .synonym]
        case .rush: return [.trueFalse, .meaning]
        case .perfection: return [.meaning, .gap, .synonym]
        case .shuffle: return [.meaning, .gap, .synonym, .trueFalse, .listen]
        }
    }

    /// The number of questions, for modes that end after a fixed count.
    var questionLimit: Int? {
        switch self {
        case .sprint, .shuffle: return 10
        case .rush, .perfection: return nil
        }
    }

    /// The length in seconds, for modes played against the clock.
    var timeLimit: Double? {
        self == .rush ? 60 : nil
    }
}

enum QuestionKind {
    case meaning, gap, synonym, trueFalse, listen
}

struct Question: Identifiable {
    let id = UUID()
    let kind: QuestionKind
    let word: Word
    let caption: String
    let prompt: String
    let options: [String]
    let answer: String
}

// MARK: - Questions

/// Builds every question from the catalogue entry alone: no extra content needed.
enum QuestionFactory {
    static func make(_ kind: QuestionKind, for word: Word) -> Question {
        switch kind {
        case .gap:
            if let question = gap(word) { return question }
        case .synonym:
            if let question = synonym(word) { return question }
        case .trueFalse:
            return trueFalse(word)
        case .listen:
            return Question(kind: .listen, word: word, caption: "Which word did you hear?",
                            prompt: "", options: wordOptions(word), answer: word.text)
        case .meaning:
            break
        }
        return Question(kind: .meaning, word: word, caption: "Which word means this?",
                        prompt: word.meaning, options: wordOptions(word), answer: word.text)
    }

    /// Wrong answers: same part of speech and a close level, never a synonym of the right one.
    private static func distractors(_ word: Word, count: Int) -> [Word] {
        let others = Catalog.all.filter { $0 != word && !word.synonyms.contains($0.text) }
        let close = others.filter { $0.partOfSpeech == word.partOfSpeech && abs($0.level - word.level) <= 1 }
        let pool = close.count >= count ? close : others
        return Array(pool.shuffled().prefix(count))
    }

    private static func wordOptions(_ word: Word) -> [String] {
        (distractors(word, count: 3).map(\.text) + [word.text]).shuffled()
    }

    private static func gap(_ word: Word) -> Question? {
        var stem = word.text
        if stem.count > 4 && (stem.hasSuffix("e") || stem.hasSuffix("y")) {
            stem = String(stem.dropLast())
        }
        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: stem) + "\\w*"
        guard let range = word.example.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }
        let blanked = word.example.replacingCharacters(in: range, with: "_____")
        return Question(kind: .gap, word: word, caption: "Fill the gap", prompt: blanked,
                        options: wordOptions(word), answer: word.text)
    }

    private static func synonym(_ word: Word) -> Question? {
        guard let target = word.synonyms.first else { return nil }
        var wrong: [String] = []
        for other in Catalog.all.shuffled() where other != word {
            guard let candidate = other.synonyms.first else { continue }
            if candidate != word.text && !word.synonyms.contains(candidate) && !wrong.contains(candidate) {
                wrong.append(candidate)
            }
            if wrong.count == 3 { break }
        }
        guard wrong.count == 3 else { return nil }
        return Question(kind: .synonym, word: word, caption: "Closest in meaning to",
                        prompt: word.text, options: (wrong + [target]).shuffled(), answer: target)
    }

    private static func trueFalse(_ word: Word) -> Question {
        let other = distractors(word, count: 1).first
        let shown = (Bool.random() ? nil : other) ?? word
        return Question(kind: .trueFalse, word: word, caption: "True or false?",
                        prompt: "“\(word.text)” means: \(shown.meaning)",
                        options: ["True", "False"], answer: shown == word ? "True" : "False")
    }
}

// MARK: - Review

/// Spaced review, the simple way: each word sits in a box from 0 to 5. A right
/// answer moves it up, a wrong one sends it back to 0, and low boxes come back first.
final class ReviewStore {
    static let shared = ReviewStore()

    private static let key = "reviewBoxes"
    private var boxes: [String: Int]

    private init() {
        boxes = UserDefaults.standard.dictionary(forKey: ReviewStore.key) as? [String: Int] ?? [:]
    }

    func record(_ lemma: String, correct: Bool) {
        boxes[lemma] = correct ? min((boxes[lemma] ?? 0) + 1, 5) : 0
        UserDefaults.standard.set(boxes, forKey: ReviewStore.key)
    }

    /// Words to ask next: missed ones first, then today's words, then the rest.
    func pick(count: Int) -> [Word] {
        let missed = Catalog.all.filter { boxes[$0.text] == 0 }.shuffled()
        let today = Catalog.feed.shuffled()
        let rest = Catalog.all.shuffled().sorted { (boxes[$0.text] ?? 1) < (boxes[$1.text] ?? 1) }
        var picked: [Word] = []
        for word in missed + today + rest where !picked.contains(word) {
            picked.append(word)
            if picked.count == count { break }
        }
        return picked
    }

    func best(for mode: GameMode) -> Int {
        UserDefaults.standard.integer(forKey: "best_\(mode.rawValue)")
    }

    func saveBest(_ score: Int, for mode: GameMode) {
        if score > best(for: mode) {
            UserDefaults.standard.set(score, forKey: "best_\(mode.rawValue)")
        }
    }
}

// MARK: - Screen

struct GameView: View {
    let mode: GameMode
    var title: String? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var question: Question?
    @State private var queue: [Word] = []
    @State private var asked = 0
    @State private var correct = 0
    @State private var picked: String?
    @State private var elapsed: Double = 0
    @State private var finished = false
    @State private var best = 0

    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    private let good = Color(hex: 0x1F8A5B)
    private let bad = Color(hex: 0xD93A30)

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            if finished {
                results
                    .transition(.opacity)
            } else if let question {
                VStack(spacing: 14) {
                    status
                    card(question)
                }
                .padding(20)
            }
        }
        .foregroundStyle(Color.ink)
        .animation(.easeInOut(duration: 0.3), value: finished)
        .navigationTitle(title ?? mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            if question == nil && !finished {
                start()
            }
        }
        .onReceive(ticker) { _ in
            guard !finished, question != nil else { return }
            elapsed += 0.1
            if let limit = mode.timeLimit, elapsed >= limit {
                finish()
            }
        }
    }

    // MARK: Pieces

    private var status: some View {
        VStack(spacing: 8) {
            HStack {
                Text(leftStatus).font(.system(size: 15, weight: .semibold))
                Spacer()
                Text(rightStatus)
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.muted)
            }
            ProgressView(value: progress)
                .tint(Color.flaubBlue)
        }
    }

    private var leftStatus: String {
        if let limit = mode.questionLimit {
            return "\(min(asked + 1, limit)) / \(limit)"
        }
        return mode == .rush ? "\(correct) correct" : "Streak \(correct)"
    }

    private var rightStatus: String {
        if let limit = mode.timeLimit {
            return "\(Int(max(limit - elapsed, 0).rounded(.up))) s"
        }
        return mode == .sprint ? String(format: "%.1f s", elapsed) : ""
    }

    private var progress: Double {
        if let limit = mode.timeLimit {
            return min(max(1 - elapsed / limit, 0), 1)
        }
        if let limit = mode.questionLimit {
            return min(Double(asked) / Double(limit), 1)
        }
        return min(Double(correct % 10) / 10, 1)
    }

    private func card(_ question: Question) -> some View {
        VStack(spacing: 14) {
            Text(question.caption.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .kerning(1)
                .foregroundStyle(Color.muted)
                .padding(.top, 12)

            if question.kind == .listen {
                Button {
                    Haptics.tap()
                    Speaker.shared.say(question.word.text)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.white)
                        .frame(width: 96, height: 96)
                        .background(Circle().fill(Color.flaubBlue))
                }
                .accessibilityLabel("Play the word again")
                .padding(.vertical, 12)
            } else {
                Text(question.prompt)
                    .font(.serif(question.kind == .synonym ? 40 : 26))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .padding(.bottom, 12)
            }

            ForEach(question.options, id: \.self) { option in
                Button {
                    choose(option)
                } label: {
                    HStack {
                        Text(option).font(.system(size: 17, weight: .medium))
                        Spacer()
                        if picked != nil && option == question.answer {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(good)
                        } else if picked == option {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(bad)
                        }
                    }
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 20)
                    .frame(height: 56)
                    .background(Capsule().fill(fill(for: option, in: question)))
                    .overlay(Capsule().stroke(stroke(for: option, in: question), lineWidth: 1.5))
                }
                .disabled(picked != nil)
            }
            Spacer(minLength: 0)
        }
        .id(question.id)
        .transition(.opacity.combined(with: .offset(x: 0, y: 12)))
    }

    private func fill(for option: String, in question: Question) -> Color {
        guard picked != nil else { return .white }
        if option == question.answer { return Color(hex: 0xDDF3EC) }
        return picked == option ? Color(hex: 0xFDE3E0) : .white
    }

    private func stroke(for option: String, in question: Question) -> Color {
        guard picked != nil else { return Color.line }
        if option == question.answer { return good }
        return picked == option ? bad : Color.line
    }

    private var results: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("\(correct)")
                .font(.serif(84))
            Text(resultLine)
                .font(.system(size: 17))
                .multilineTextAlignment(.center)
            Text("Best: \(best)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.muted)
            Spacer()
            PrimaryButton(title: "Play again") { start() }
            Button("Done") { dismiss() }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.ink)
                .frame(height: 48)
        }
        .padding(24)
    }

    private var resultLine: String {
        switch mode {
        case .sprint: return "right out of \(asked), in " + String(format: "%.1f", elapsed) + " seconds"
        case .rush: return "right answers in 60 seconds"
        case .perfection: return "in a row before your first mistake"
        case .shuffle: return "right out of \(asked)"
        }
    }

    // MARK: Flow

    private func start() {
        asked = 0
        correct = 0
        elapsed = 0
        picked = nil
        finished = false
        best = ReviewStore.shared.best(for: mode)
        queue = ReviewStore.shared.pick(count: 40)
        next()
    }

    private func next() {
        if let limit = mode.questionLimit, asked >= limit {
            finish()
            return
        }
        if queue.isEmpty {
            queue = ReviewStore.shared.pick(count: 40)
        }
        guard !queue.isEmpty else {
            finish()
            return
        }
        let word = queue.removeFirst()
        let made = QuestionFactory.make(mode.kinds.randomElement() ?? .meaning, for: word)
        picked = nil
        withAnimation(.easeInOut(duration: 0.3)) {
            question = made
        }
        if made.kind == .listen {
            Speaker.shared.say(word.text)
        }
    }

    private func choose(_ option: String) {
        guard picked == nil, !finished, let current = question else { return }
        picked = option
        asked += 1
        let right = option == current.answer
        ReviewStore.shared.record(current.word.text, correct: right)
        if right {
            correct += 1
            Haptics.success()
        } else {
            Haptics.error()
        }
        let pause = mode == .rush ? 0.35 : 0.7
        DispatchQueue.main.asyncAfter(deadline: .now() + pause) {
            guard !finished else { return }
            if !right && mode == .perfection {
                finish()
            } else {
                next()
            }
        }
    }

    private func finish() {
        guard !finished else { return }
        ReviewStore.shared.saveBest(correct, for: mode)
        best = max(best, correct)
        finished = true
        Haptics.success()
    }
}
