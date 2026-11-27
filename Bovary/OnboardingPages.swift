import SwiftUI

// The onboarding pages that play an animation of their own. `OnboardingView`
// decides their order; each one calls `next` when it is done.

/// Waits, then runs `body`. Returns false when the page was left meanwhile.
private func pause(_ seconds: Double) async -> Bool {
    do {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        return true
    } catch {
        return false
    }
}

// MARK: - Welcome

/// The first page: words of the day dealt one after the other, each with a tap.
struct WelcomePage: View {
    let next: () -> Void
    @State private var step = 0

    private let words = Array(Catalog.feed.prefix(8))

    private var visible: [(word: Word, depth: Int)] {
        guard words.count >= 4 else { return [] }
        return (0..<3).map { (word: words[(step + $0) % words.count], depth: $0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            ZStack {
                ForEach(visible, id: \.word.text) { item in
                    DayCard(word: item.word)
                        .scaleEffect(1 - CGFloat(item.depth) * 0.07)
                        .offset(y: CGFloat(item.depth) * 20)
                        .rotationEffect(.degrees(item.depth == 0 ? 0 : (item.depth == 1 ? 2.5 : -2.5)))
                        .zIndex(Double(3 - item.depth))
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.8)),
                            removal: .offset(x: -460, y: -70).combined(with: .opacity)))
                }
            }
            .frame(height: 300)
            .accessibilityHidden(true)
            Text("Expand your vocabulary in 1 minute a day")
                .font(.serif(32))
                .multilineTextAlignment(.center)
                .padding(.top, 34)
                .rise(0.2)
            Text("Learn new words with a daily habit that takes just 1 minute")
                .font(.system(size: 16))
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .rise(0.3)
            Spacer(minLength: 12)
            PrimaryButton(title: "Get started", action: next)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .task {
            while await pause(2.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.76)) {
                    step += 1
                }
                Haptics.tap()
            }
        }
    }
}

private struct DayCard: View {
    let word: Word

    var body: some View {
        VStack(spacing: 10) {
            Text("WORD OF THE DAY")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(Color.brandBlue)
            Text(word.text)
                .font(.serif(40))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if !word.pronunciation.isEmpty {
                Text("/\(word.pronunciation)/")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.muted)
            }
            Text(word.definition)
                .font(.serif(19, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.top, 4)
        }
        .foregroundStyle(Color.ink)
        .padding(24)
        .frame(maxWidth: .infinity)
        .frame(height: 250)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.line, lineWidth: 1.5))
        .shadow(color: Color.ink.opacity(0.1), radius: 16, y: 10)
    }
}

// MARK: - A year of words

/// Turns the weekly goal into a year: a number that counts up and a field of
/// squares that fills, one square for twenty words.
struct YearPage: View {
    let next: () -> Void
    @State private var filled = 0
    @State private var finished = false

    private let weekly: Int = {
        let answer = UserStore.shared.state.onboarding["How many words do you want to learn per week?"]?.first ?? ""
        return Int(answer.prefix { $0.isNumber }) ?? 30
    }()

    private var total: Int { weekly * 52 }
    private var squares: Int { total / 20 }
    private var perDay: String {
        let daily = Double(weekly) / 7
        return daily < 2 ? "more than one new word" : "about \(Int(daily.rounded())) new words"
    }

    private let columns = Array(repeating: GridItem(.fixed(16), spacing: 5), count: 13)

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    Text("In one year, you'll know")
                        .font(.serif(26))
                        .rise()
                    Text("\(min(filled * 20, total).formatted())")
                        .font(.serif(64))
                        .foregroundStyle(Color.brandBlue)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("more words")
                        .font(.serif(26))
                        .rise(0.1)
                    LazyVGrid(columns: columns, spacing: 5) {
                        ForEach(0..<squares, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(index < filled ? Color.brandBlue : Color.line)
                                .frame(width: 16, height: 16)
                                .scaleEffect(index < filled ? 1 : 0.7)
                        }
                    }
                    .padding(.top, 14)
                    .accessibilityHidden(true)
                    VStack(spacing: 6) {
                        Text("Each square is 20 words you don't know yet.")
                        Text("That's \(perDay) every day, with your goal of \(weekly) words a week.")
                    }
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .reveal(finished)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 28)
            }
            .scrollBounceBehavior(.basedOnSize)
            PrimaryButton(title: "Continue", enabled: finished, action: next)
                .padding(.top, 8)
                .reveal(finished)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .task {
            guard await pause(0.5) else { return }
            // The whole field fills in about two and a half seconds, whatever its size.
            let stride = max(1, squares / 26)
            while filled < squares {
                guard await pause(0.09) else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    filled = min(squares, filled + stride)
                }
                Haptics.select()
            }
            guard await pause(0.3) else { return }
            Haptics.success()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                finished = true
            }
        }
    }
}

// MARK: - Widgets

/// An iPhone drawn in the page: first the Home Screen with the widget, then,
/// after a tap, the Lock Screen with the word of the day.
struct WidgetPage: View {
    let next: () -> Void
    @State private var lockScreen = false
    @State private var ready = false

    private let word = Catalog.featured

    var body: some View {
        VStack(spacing: 0) {
            Text(lockScreen
                 ? "Your word of the day, right on your Lock Screen"
                 : "With widgets, you learn words without even opening the app")
                .font(.serif(26))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.top, 28)
                .frame(minHeight: 110, alignment: .top)
                .id(lockScreen)
                .transition(.opacity)
            Spacer(minLength: 8)
            PhoneFrame {
                ZStack {
                    if lockScreen {
                        LockScreenArt(word: word)
                            .transition(.opacity.combined(with: .scale(scale: 1.06)))
                    } else {
                        HomeScreenArt(word: word)
                            .transition(.opacity.combined(with: .scale(scale: 0.94)))
                    }
                }
            }
            .modifier(Pop(delay: 0.1))
            .accessibilityHidden(true)
            Spacer(minLength: 8)
            TapToContinue(shown: ready, action: advance)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            if ready { advance() }
        }
        .task(id: lockScreen) {
            guard await pause(1.4) else { return }
            ready = true
        }
    }

    private func advance() {
        if lockScreen {
            next()
        } else {
            Haptics.page()
            ready = false
            withAnimation(.easeInOut(duration: 0.5)) {
                lockScreen = true
            }
        }
    }
}

private struct PhoneFrame<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(width: 226, height: 462)
            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).stroke(Color.ink, lineWidth: 7))
            .overlay(alignment: .top) {
                Capsule().fill(Color.ink).frame(width: 66, height: 19).padding(.top, 15)
            }
            .shadow(color: Color.ink.opacity(0.18), radius: 22, y: 14)
    }
}

private struct HomeScreenArt: View {
    let word: Word

    private let apps: [UInt32] = [0xF54B40, 0x145E61, 0xFFD84A, 0x762C89, 0x0A5CFF, 0xFF8A1F, 0x1B1A2E, 0x5FB37C]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xCFE0FF), Color(hex: 0xFFE9DC)], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WORD OF THE DAY")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .opacity(0.8)
                    Text(word.text)
                        .font(.serif(24))
                    Text(word.definition)
                        .font(.system(size: 10.5))
                        .lineLimit(2)
                }
                .foregroundStyle(.white)
                .padding(14)
                .frame(width: 186, height: 96, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.brandBlue))
                .shadow(color: Color.brandBlue.opacity(0.35), radius: 10, y: 6)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(36), spacing: 14), count: 4), spacing: 16) {
                    ForEach(apps.indices, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(hex: apps[index]).opacity(0.85))
                            .frame(width: 36, height: 36)
                    }
                }
                Spacer(minLength: 0)
                HStack(spacing: 14) {
                    ForEach(0..<4, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 36, height: 36)
                            .overlay(Circle().fill(Color(hex: apps[index])).frame(width: 14, height: 14))
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.45)))
            }
            .padding(.top, 56)
            .padding(.bottom, 16)
        }
    }
}

private struct LockScreenArt: View {
    let word: Word

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1B1A2E), Color(hex: 0x34306B)], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 2) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13))
                    .padding(.bottom, 6)
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.system(size: 12, weight: .medium))
                Text("9:41")
                    .font(.system(size: 62, weight: .semibold, design: .rounded))
                VStack(alignment: .leading, spacing: 3) {
                    Text("WORD OF THE DAY")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .opacity(0.75)
                    Text(word.text)
                        .font(.serif(20))
                    Text(word.definition)
                        .font(.system(size: 10.5))
                        .lineLimit(2)
                }
                .padding(12)
                .frame(width: 186, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.16)))
                .padding(.top, 10)
                Spacer(minLength: 0)
                HStack {
                    Circle().fill(Color.white.opacity(0.18)).frame(width: 34, height: 34)
                        .overlay(Image(systemName: "flashlight.off.fill").font(.system(size: 14)))
                    Spacer()
                    Circle().fill(Color.white.opacity(0.18)).frame(width: 34, height: 34)
                        .overlay(Image(systemName: "camera.fill").font(.system(size: 13)))
                }
                .padding(.horizontal, 26)
            }
            .foregroundStyle(.white)
            .padding(.top, 52)
            .padding(.bottom, 22)
        }
    }
}

// MARK: - The deck

/// A pile of word cards. The top one fills in block by block; on "Tap to
/// continue" the cards leave one after the other until the pile is gone.
struct DeckPage: View {
    let next: () -> Void
    @State private var phase = 0
    @State private var gone = 0
    @State private var leaving = false

    private let words: [Word] = {
        let first = Catalog.featured
        return [first] + Catalog.feed.filter { $0.text != first.text }.prefix(3)
    }()

    private var finished: Bool { phase >= 6 && !leaving }

    var body: some View {
        VStack(spacing: 0) {
            Text("Get deeper insight into each word you learn")
                .font(.serif(28))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.top, 28)
                .reveal(phase >= 1)
            Spacer(minLength: 10)
            ZStack {
                ForEach(Array(words.enumerated()), id: \.element.text) { item in
                    if item.offset >= gone {
                        let depth = item.offset - gone
                        DeckCard(word: item.element, phase: item.offset == 0 ? phase : 99)
                            .scaleEffect(1 - CGFloat(depth) * 0.05)
                            .offset(y: CGFloat(depth) * 14)
                            .rotationEffect(.degrees(depth == 0 ? 0 : (depth.isMultiple(of: 2) ? -2 : 2)))
                            .zIndex(Double(words.count - item.offset))
                            .transition(.asymmetric(
                                insertion: .identity,
                                removal: .offset(x: item.offset.isMultiple(of: 2) ? -480 : 480, y: -50)
                                    .combined(with: .opacity)))
                    }
                }
            }
            .reveal(phase >= 2)
            Spacer(minLength: 10)
            TapToContinue(shown: finished, action: deal)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            if finished { deal() }
        }
        .task {
            for (step, delay) in [0.2, 0.6, 0.7, 0.7, 0.7, 0.9].enumerated() {
                guard await pause(delay) else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    phase = step + 1
                }
                Haptics.tap()
            }
        }
    }

    /// Sends the cards away one by one, then moves on.
    private func deal() {
        leaving = true
        Task {
            for _ in words {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    gone += 1
                }
                Haptics.select()
                guard await pause(0.32) else { return }
            }
            next()
        }
    }
}

/// One card of the pile: the word, then its example, synonyms and origin, each
/// shown from a given phase on. Every card has the same height so the pile is even.
private struct DeckCard: View {
    let word: Word
    let phase: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(word.text)
                .font(.serif(32))
                .frame(maxWidth: .infinity)
            Text("/\(word.pronunciation)/")
                .font(.system(size: 14))
                .frame(maxWidth: .infinity)
            Text(word.definition)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 6) {
                label("Example")
                Text(word.example).font(.system(size: 15)).lineLimit(3)
            }
            .reveal(phase >= 3)
            VStack(alignment: .leading, spacing: 6) {
                label("Synonyms")
                HStack(spacing: 6) {
                    ForEach(word.synonyms, id: \.self) { synonym in
                        Text(synonym)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(hex: 0x0A3FB3))
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.blueTint))
                    }
                }
            }
            .reveal(phase >= 4 && !word.synonyms.isEmpty)
            VStack(alignment: .leading, spacing: 6) {
                label("Origin")
                Text(word.origin).font(.system(size: 15)).lineLimit(4)
            }
            .reveal(phase >= 5)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.ink)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 410, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.line, lineWidth: 1.5))
        .shadow(color: Color.ink.opacity(0.08), radius: 12, y: 8)
        .padding(.horizontal, 12)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Color.muted)
            .padding(.top, 8)
    }
}

// MARK: - Loading

/// A short wait between the questions and the profile. Nothing is computed
/// here: the bar fills on a timer and names three steps, then a button appears.
struct LoadingPage: View {
    let next: () -> Void
    @State private var progress = 0.0
    @State private var done = 0
    @State private var ready = false

    private let steps = ["Reading your answers", "Estimating your level", "Building your word plan"]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            FloatingArt(name: "result", size: 190)
            Text(ready ? "Your profile is ready" : "Creating your profile")
                .font(.serif(30))
                .multilineTextAlignment(.center)
                .padding(.top, 34)
                .rise(0.15)
            Text("\(Int(progress * 100))%")
                .font(.serif(44))
                .foregroundStyle(Color.brandBlue)
                .contentTransition(.numericText())
                .monospacedDigit()
                .padding(.top, 14)
            ProgressView(value: progress)
                .tint(Color.brandBlue)
                .scaleEffect(y: 2.2)
                .padding(.horizontal, 40)
                .padding(.top, 10)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(steps.indices, id: \.self) { index in
                    HStack(spacing: 12) {
                        Image(systemName: index < done ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(index < done ? Color.brandBlue : Color.line)
                            .contentTransition(.symbolEffect(.replace))
                        Text(steps[index])
                            .font(.system(size: 16, weight: index < done ? .semibold : .regular))
                            .foregroundStyle(index <= done ? Color.ink : Color.muted)
                    }
                }
            }
            .padding(.top, 34)
            Spacer(minLength: 12)
            PrimaryButton(title: "See my profile", enabled: ready, action: next)
                .reveal(ready)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .task {
            // 40 small steps over about four seconds, with a tick as each line completes.
            for tick in 1...40 {
                guard await pause(0.1) else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    progress = Double(tick) / 40
                }
                let finished = tick * steps.count / 40
                if finished != done {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        done = finished
                    }
                    Haptics.tap()
                }
            }
            guard await pause(0.4) else { return }
            Haptics.success()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                ready = true
            }
        }
    }
}

// MARK: - Profile

/// What the answers add up to: the member's character, a level dial, the plan
/// for the year, the topics they picked and the first words they will meet.
struct ProfilePage: View {
    let next: () -> Void
    @State private var phase = 0

    private let answers = UserStore.shared.state.onboarding
    private let name = UserStore.shared.state.displayName
    private let character = UserDefaults.standard.integer(forKey: "iconCharacter")
    private let background = UserDefaults.standard.integer(forKey: "iconBackground")

    private static let topicArt = [
        "Society": "tile_topics", "Human body": "topic_science", "Emotions": "topic_emotions",
        "Business": "topic_business", "Other": "topic_literature"
    ]

    /// Words ticked in the three tests, out of 18. Harder words weigh more.
    private var known: (count: Int, score: Int) {
        var count = 0
        var score = 0
        for (weight, title) in ["Beginner words", "Intermediate words", "Advanced words"].enumerated() {
            let ticked = (answers[title] ?? []).filter { $0 != "None of these" }.count
            count += ticked
            score += ticked * (weight + 1)
        }
        return (count, score)
    }

    /// 0 beginner, 1 intermediate, 2 advanced. The score runs from 0 to 36.
    private var level: Int {
        known.score < 10 ? 0 : (known.score < 22 ? 1 : 2)
    }

    private var weekly: Int {
        let answer = answers["How many words do you want to learn per week?"]?.first ?? ""
        return Int(answer.prefix { $0.isNumber }) ?? 30
    }

    private var topics: [String] { answers["Which topics are you interested in?"] ?? [] }
    private var focus: [String] { answers["Where does your vocabulary feel weakest?"] ?? [] }

    /// Three words of the member's level, as a taste of what comes first.
    private var firstWords: [Word] {
        let match = Catalog.feed.filter { $0.level == level + 1 }
        return Array((match.isEmpty ? Catalog.feed : match).prefix(3))
    }

    private let last = 6

    var body: some View {
        let levels = ["Beginner", "Intermediate", "Advanced"]

        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        IconTile(character: character, background: background)
                            .frame(width: 92, height: 92)
                            .shadow(color: Color.ink.opacity(0.12), radius: 12, y: 8)
                        Text(name.isEmpty ? "Your word profile" : "\(name)'s word profile")
                            .font(.serif(30))
                            .multilineTextAlignment(.center)
                    }
                    .reveal(phase >= 1)

                    VStack(spacing: 6) {
                        LevelDial(fraction: phase >= 2 ? max(0.08, Double(known.score) / 36) : 0)
                        Text(levels[level])
                            .font(.serif(32))
                            .foregroundStyle(Color.brandBlue)
                            .padding(.top, -34)
                        Text("You knew \(known.count) of the 18 test words")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.muted)
                    }
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .card(radius: 24)
                    .reveal(phase >= 2)

                    HStack(spacing: 14) {
                        FillImage(name: "onb_goal")
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your plan")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.muted)
                            Text("\(weekly) words a week")
                                .font(.serif(22))
                            Text("\((weekly * 52).formatted()) new words in a year")
                                .font(.system(size: 14))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .card(radius: 20)
                    .reveal(phase >= 3)

                    if !topics.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("What you'll read about")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.muted)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(topics, id: \.self) { topic in
                                        VStack(alignment: .leading, spacing: 0) {
                                            FillImage(name: Self.topicArt[topic] ?? "tile_topics")
                                                .frame(width: 104, height: 70)
                                            Text(topic)
                                                .font(.system(size: 13, weight: .semibold))
                                                .padding(8)
                                        }
                                        .frame(width: 104, alignment: .leading)
                                        .card(radius: 14)
                                    }
                                }
                            }
                        }
                        .reveal(phase >= 4)
                    }

                    if !focus.isEmpty {
                        HStack(spacing: 14) {
                            FillImage(name: "onb_voice")
                                .frame(width: 56, height: 56)
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Where we'll help most")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.muted)
                                Text(focus.joined(separator: ", "))
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .card(radius: 20)
                        .reveal(phase >= 5)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your first words")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.muted)
                        ForEach(firstWords) { word in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(word.text).font(.serif(20))
                                Text(word.meaning)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.muted)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(radius: 20)
                    .reveal(phase >= last)
                }
                .padding(.top, 24)
                .padding(.bottom, 12)
            }
            .scrollBounceBehavior(.basedOnSize)
            PrimaryButton(title: "Continue", enabled: phase > last, action: next)
                .padding(.top, 8)
                .reveal(phase > last)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .task {
            for step in 1...(last + 1) {
                guard await pause(step == 1 ? 0.2 : 0.55) else { return }
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    phase = step
                }
                Haptics.tap()
            }
        }
    }
}

/// A half-circle dial that fills from the left up to `fraction` of its length.
private struct LevelDial: View {
    let fraction: Double

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.5)
                .stroke(Color.line, style: StrokeStyle(lineWidth: 16, lineCap: .round))
            Circle()
                .trim(from: 0, to: 0.5 * min(max(fraction, 0), 1))
                .stroke(Color.brandBlue, style: StrokeStyle(lineWidth: 16, lineCap: .round))
        }
        .rotationEffect(.degrees(180))
        .frame(width: 190, height: 190)
        .frame(height: 112, alignment: .top)
        .clipped()
        .animation(.spring(response: 1.1, dampingFraction: 0.7), value: fraction)
        .accessibilityHidden(true)
    }
}

// MARK: - The gift

/// A present that opens very slowly, with a soft tick while the lid lifts.
struct GiftPage: View {
    let next: () -> Void
    @State private var open = 0.0
    @State private var wobble = false
    @State private var opened = false

    private let ribbon = Color(hex: 0xFFD84A)

    var body: some View {
        VStack(spacing: 0) {
            Text("We have a gift for you")
                .font(.serif(32))
                .multilineTextAlignment(.center)
                .padding(.top, 40)
                .rise()
            Spacer(minLength: 12)
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [ribbon.opacity(0.85), ribbon.opacity(0)],
                                         center: .center, startRadius: 0, endRadius: 160))
                    .frame(width: 320, height: 320)
                    .scaleEffect(0.5 + 0.6 * open)
                    .opacity(open)
                    .offset(y: -30)
                ForEach(0..<8, id: \.self) { index in
                    let angle = Double(index) / 8 * 2 * Double.pi
                    let across: Double = cos(angle) * 130 * open
                    let up: Double = -50 + sin(angle) * 110 * open - 30 * open
                    Image(systemName: "sparkle")
                        .font(.system(size: CGFloat(14 + (index % 3) * 7)))
                        .foregroundStyle(ribbon)
                        .offset(x: across, y: up)
                        .opacity(open)
                        .scaleEffect(0.3 + 0.7 * open)
                }
                VStack(spacing: 0) {
                    ZStack(alignment: .top) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(hex: 0x0848CC))
                            .frame(width: 196, height: 46)
                            .overlay(Rectangle().fill(ribbon).frame(width: 30))
                        HStack(spacing: -6) {
                            Ellipse().fill(ribbon).frame(width: 46, height: 30).rotationEffect(.degrees(-24))
                            Ellipse().fill(ribbon).frame(width: 46, height: 30).rotationEffect(.degrees(24))
                        }
                        .offset(y: -22)
                    }
                    .offset(y: -96 * open)
                    .rotationEffect(.degrees(-18 * open), anchor: .bottomLeading)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.brandBlue)
                        .frame(width: 172, height: 132)
                        .overlay(Rectangle().fill(ribbon).frame(width: 30))
                }
                .rotationEffect(.degrees(opened ? 0 : (wobble ? 2.5 : -2.5)), anchor: .bottom)
            }
            .frame(height: 340)
            .accessibilityHidden(true)
            Spacer(minLength: 12)
            TapToContinue(shown: opened, action: next)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            if opened { next() }
        }
        .task {
            withAnimation(.easeInOut(duration: 0.22).repeatCount(7, autoreverses: true)) {
                wobble = true
            }
            guard await pause(1.6) else { return }
            withAnimation(.easeInOut(duration: 4.6)) {
                open = 1
            }
            for _ in 0..<9 {
                Haptics.select()
                guard await pause(0.5) else { return }
            }
            Haptics.success()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                opened = true
            }
        }
    }
}

// MARK: - The reminder promise

/// The promise that goes with the trial, written out one word at a time. The
/// button only arrives once the sentence is complete.
struct ReminderPage: View {
    let next: () -> Void
    @State private var shown = 0
    @State private var finished = false

    private let words = "We'll send you a notification 1 day before your free trial ends."
        .split(separator: " ").map(String.init)

    private var sentence: Text {
        words.enumerated().reduce(Text("")) { text, item in
            text + Text(item.element + " ").foregroundColor(Color.ink.opacity(item.offset < shown ? 1 : 0))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            FloatingArt(name: "tile_reminders", size: 170)
            sentence
                .font(.serif(32))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.top, 36)
                .accessibilityLabel(words.joined(separator: " "))
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Color.brandBlue)
                Text("No commitment. Cancel anytime.")
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.top, 22)
            .reveal(finished)
            Spacer(minLength: 12)
            PrimaryButton(title: "Continue", enabled: finished, action: next)
                .reveal(finished)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .task {
            guard await pause(0.7) else { return }
            for index in words.indices {
                withAnimation(.easeOut(duration: 0.25)) {
                    shown = index + 1
                }
                Haptics.select()
                guard await pause(0.2) else { return }
            }
            guard await pause(0.4) else { return }
            Haptics.success()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                finished = true
            }
        }
    }
}
