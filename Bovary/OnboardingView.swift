import SwiftUI
import StoreKit

/// One page of the onboarding. The list below is the whole flow, in order.
enum OnboardingStep {
    case welcome
    /// `noneOption` adds a last row that stands for "none of the above" and clears the others.
    case choice(title: String, subtitle: String?, options: [String], multiple: Bool, noneOption: String?)
    case art(image: String, title: String)
    case name
    case yearly
    case streak
    case notifications
    case icon
    case theme
    case voice
    case wordCard
    case text(String)
    case offer
    case widgets
    case gift
    case reminder
    case splash
    case loading
    case profile
    case rating
    case account

    static func single(_ title: String, _ options: [String]) -> OnboardingStep {
        .choice(title: title, subtitle: nil, options: options, multiple: false, noneOption: nil)
    }

    static func multi(_ title: String, _ options: [String], subtitle: String? = nil,
                      noneOption: String? = nil) -> OnboardingStep {
        .choice(title: title, subtitle: subtitle, options: options, multiple: true, noneOption: noneOption)
    }

    static let flow: [OnboardingStep] = [
        .welcome,
        .art(image: "level", title: "Tailor your word recommendations"),
        .single("How old are you?", ["13 to 17", "18 to 24", "25 to 34", "35 to 44", "45 to 54", "55+"]),
        .single("Which option represents you best?", ["Female", "Male", "Other", "Prefer not to say"]),
        .name,
        .single("How many words do you want to learn per week?",
                ["10 words a week", "30 words a week", "50 words a week"]),
        .yearly,
        .streak,
        .multi("What would help make learning a daily habit?",
               ["Getting regular reminders", "Tracking my progress", "A home/lock screen widget",
                "Personalized quizzes and games"]),
        .widgets,
        .notifications,
        .icon,
        .theme,
        .voice,
        .multi("Which topics are you interested in?", ["Society", "Human body", "Emotions", "Business", "Other"]),
        .multi("What drives your curiosity?",
               ["Breaking out of my bubble", "Knowing more than others", "I'm a lifelong learner"]),
        .wordCard,
        .single("What's your vocabulary level?", ["Beginner", "Intermediate", "Advanced"]),
        .single("Do you often encounter words you don't know?", ["Daily", "Occasionally", "Never"]),
        .single("How would you describe your vocabulary?",
                ["Struggle to find the right words", "Get by but want to improve",
                 "Comfortable in most situations"]),
        .multi("Where does your vocabulary feel weakest?",
               ["At work", "In social conversations", "I always feel confident", "When reading", "When writing"]),
        .text("Amazing! Let's test how many words you know..."),
        .multi("Beginner words", ["Genuine", "Metal", "Squint", "Whisper", "Jumble", "Borrow"],
               subtitle: "Select all the ones you know", noneOption: "None of these"),
        .multi("Intermediate words", ["Morose", "Impeccable", "Squander", "Whet", "Pervasive", "Deportment"],
               subtitle: "Select all the ones you know", noneOption: "None of these"),
        .multi("Advanced words",
               ["Lucubration", "Quixotic", "Numinous", "Superincumbent", "Callipygian", "Logophile"],
               subtitle: "Select all the ones you know", noneOption: "None of these"),
        .loading,
        .profile,
        .rating,
        .account,
        .gift,
        .reminder,
        .offer,
        .splash
    ]
}

/// Runs the flow. Pages cross-fade with a slight rise; there is no swipe.
/// Every page change fires a soft haptic.
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var index = 0
    @State private var answers: [Int: Set<Int>] = [:]
    @State private var name = ""

    private let steps = OnboardingStep.flow

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            VStack(spacing: 0) {
                // The offer fills the whole screen, so it has no bar above it.
                if !isOffer {
                    ProgressView(value: Double(index), total: Double(max(steps.count - 1, 1)))
                        .tint(Color.brandBlue)
                        .padding(.horizontal, 24)
                        .padding(.top, 6)
                        .opacity(index == 0 || index == steps.count - 1 ? 0 : 1)
                }
                ZStack {
                    page(steps[index])
                        .id(index)
                        .transition(.opacity.combined(with: .offset(x: 0, y: 14)))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .animation(.easeInOut(duration: 0.38), value: index)
        .foregroundStyle(Color.ink)
    }

    private var isOffer: Bool {
        if case .offer = steps[index] { return true }
        return false
    }

    private func next() {
        Haptics.page()
        save(steps[index])
        if index + 1 < steps.count {
            index += 1
        } else {
            onFinish()
        }
    }

    /// Keep what the member answered on the page they are leaving.
    private func save(_ step: OnboardingStep) {
        switch step {
        case let .choice(title, _, options, _, noneOption):
            let chosen = (answers[index] ?? []).sorted().compactMap {
                $0 < options.count ? options[$0] : noneOption
            }
            if !chosen.isEmpty {
                UserStore.shared.setOnboarding(title, answers: chosen)
            }
        case .name:
            if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                UserStore.shared.setName(name)
            }
        case .icon:
            AppIcon.apply(character: UserDefaults.standard.integer(forKey: "iconCharacter"),
                          background: UserDefaults.standard.integer(forKey: "iconBackground"))
        default:
            break
        }
    }

    @ViewBuilder
    private func page(_ step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            WelcomePage(next: next)
        case let .choice(title, subtitle, options, multiple, noneOption):
            ChoicePage(title: title, image: OnboardingArt.image(for: title), subtitle: subtitle,
                       options: options + (noneOption.map { [$0] } ?? []), multiple: multiple,
                       exclusiveLast: noneOption != nil, selection: selection(for: index), next: next)
        case let .art(image, title):
            Scaffold(title: nil, cta: "Continue", next: next) {
                VStack(spacing: 44) {
                    FloatingArt(name: image, size: 270)
                    Text(title)
                        .font(.serif(28))
                        .multilineTextAlignment(.center)
                        .rise(0.15)
                }
                .padding(.top, 40)
            }
        case .name:
            Scaffold(title: "What do you want to be called?", cta: "Continue",
                     ctaEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty, next: next) {
                FloatingArt(name: "onb_name", size: 120)
                TextField("Your name", text: $name)
                    .textContentType(.givenName)
                    .submitLabel(.done)
                    .padding(.horizontal, 20)
                    .frame(height: 56)
                    .background(Capsule().fill(Color.white))
                    .overlay(Capsule().strokeBorder(Color.line, lineWidth: 1.5))
            }
        case .yearly:
            YearPage(next: next)
        case .streak:
            StreakPage(next: next)
        case .notifications:
            Scaffold(title: "Get words throughout the day", cta: "Allow and Save",
                     next: { Notifications.requestPermission(then: next) }) {
                VStack(spacing: 18) {
                    Text("Allow notifications to get daily words").font(.system(size: 15))
                    NotificationStack()
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                    ReminderSettings()
                }
            }
        case .icon:
            Scaffold(title: "Which icon style do you like the most?", cta: "Continue", next: next) {
                IconPicker()
            }
        case .theme:
            Scaffold(title: "Which theme would you like to start with?", cta: "Continue", next: next) {
                ThemeGrid()
                    .padding(.top, 30)
            }
        case .voice:
            Scaffold(title: "Choose a voice to pronounce words", cta: "Save voice selection", next: next) {
                VoiceList()
            }
        case .wordCard:
            DeckPage(next: next)
        case let .text(message):
            Scaffold(title: nil, cta: "Continue", next: next) {
                VStack(spacing: 36) {
                    if let image = OnboardingArt.image(for: message) {
                        FloatingArt(name: image, size: 220)
                    }
                    Text(message)
                        .font(.serif(28))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .rise(0.15)
                }
                .padding(.top, 50)
            }
        case .loading:
            LoadingPage(next: next)
        case .profile:
            ProfilePage(next: next)
        case .rating:
            RatingPage(next: next)
        case .account:
            AccountPage(next: next)
        case .offer:
            OfferView(onContinue: next)
        case .widgets:
            WidgetPage(next: next)
        case .gift:
            GiftPage(next: next)
        case .reminder:
            ReminderPage(next: next)
        case .splash:
            Text("Welcome to Bovary")
                .font(.serif(32))
                .task {
                    try? await Task.sleep(nanoseconds: 1_300_000_000)
                    next()
                }
        }
    }

    private func selection(for step: Int) -> Binding<Set<Int>> {
        Binding(
            get: { answers[step] ?? [] },
            set: { answers[step] = $0 }
        )
    }
}

// MARK: - Page frame

/// Title on top, content in the middle, the main button pinned at the bottom.
private struct Scaffold<Content: View>: View {
    let title: String?
    let cta: String
    var ctaEnabled: Bool = true
    var secondary: String? = nil
    let next: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    if let title {
                        Text(title)
                            .font(.serif(28))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 4)
                            .rise()
                    }
                    content()
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 28)
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(spacing: 6) {
                PrimaryButton(title: cta, enabled: ctaEnabled, action: next)
                if let secondary {
                    Button(secondary) { next() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.ink)
                        .frame(height: 48)
                }
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

// MARK: - Pages

/// Asks for an App Store rating. The button opens Apple's own rating prompt,
/// which iOS may decide not to show; either way the flow moves on.
private struct RatingPage: View {
    let next: () -> Void
    @Environment(\.requestReview) private var requestReview

    private let proof = SocialProof.current
    private let gold = Color(hex: 0xF2B01E)

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        ForEach(0..<5, id: \.self) { star in
                            Image(systemName: "star.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(gold)
                                .modifier(Pop(delay: Double(star) * 0.09))
                        }
                    }
                    .accessibilityLabel("Five stars")
                    Image("mascot_rate")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 210, height: 210)
                        .modifier(Pop(delay: 0.45))
                    Text("One tap. Two seconds. It means the world.")
                        .font(.serif(30))
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                        .rise(0.55)
                    Text("We're a small team up against big apps. Your rating helps more than you know.")
                        .font(.system(size: 16))
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                        .rise(0.65)
                    if let proof {
                        HStack(spacing: 12) {
                            Image(systemName: "laurel.leading")
                                .font(.system(size: 46))
                                .foregroundStyle(gold)
                            VStack(spacing: 2) {
                                Text(proof.rating).font(.serif(34))
                                HStack(spacing: 2) {
                                    ForEach(0..<5, id: \.self) { _ in
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 11))
                                            .foregroundStyle(gold)
                                    }
                                }
                                Text("average rating")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.muted)
                            }
                            VStack(spacing: 6) {
                                HStack(spacing: -10) {
                                    IconTile(character: 2, background: 2).frame(width: 36, height: 36)
                                    IconTile(character: 3, background: 3).frame(width: 36, height: 36)
                                    IconTile(character: 6, background: 7).frame(width: 36, height: 36)
                                }
                                Text("\(proof.users) users")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            Image(systemName: "laurel.trailing")
                                .font(.system(size: 46))
                                .foregroundStyle(gold)
                        }
                        .padding(.top, 22)
                        .rise(0.75)

                        Text("What our users are saying")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 26)
                            .rise(0.85)
                        ForEach(Array(proof.reviews.enumerated()), id: \.element.id) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.element.title)
                                    .font(.system(size: 16, weight: .semibold))
                                Text(item.element.text)
                                    .font(.system(size: 15))
                                HStack(spacing: 6) {
                                    Text(item.element.author)
                                        .font(.system(size: 14, weight: .medium))
                                    HStack(spacing: 1) {
                                        ForEach(0..<5, id: \.self) { _ in
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 9))
                                                .foregroundStyle(gold)
                                        }
                                    }
                                    Spacer()
                                    Text(item.element.date)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.muted)
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .card()
                            .padding(.top, 10)
                            .rise(0.95 + Double(item.offset) * 0.1)
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
            PrimaryButton(title: "Yes, I'll help!") {
                requestReview()
                next()
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}

/// Offers to keep progress under an account, and always lets the member go on without one.
private struct AccountPage: View {
    let next: () -> Void
    @State private var notReady = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            HStack(spacing: -22) {
                IconTile(character: 2, background: 2).frame(width: 96, height: 96)
                IconTile(character: 1, background: 0).frame(width: 96, height: 96)
                IconTile(character: 4, background: 3).frame(width: 96, height: 96)
            }
            Text("Save your progress")
                .font(.serif(30))
                .padding(.top, 34)
            Text("Keep your words, streak and favorites safe, and find them on all your devices.")
                .font(.system(size: 16))
                .multilineTextAlignment(.center)
                .padding(.top, 12)
            Spacer(minLength: 12)
            VStack(spacing: 10) {
                Button {
                    Haptics.tap()
                    notReady = true
                } label: {
                    Text("Continue with Apple")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(Capsule().fill(Color.ink))
                }
                Button {
                    Haptics.tap()
                    notReady = true
                } label: {
                    Text("Continue with Google")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(Capsule().fill(Color.white))
                        .overlay(Capsule().strokeBorder(Color.line, lineWidth: 1.5))
                }
                Button("Continue without an account") {
                    next()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.ink)
                .frame(height: 48)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        // Sign in with Apple and Google need the app identifier and the providers
        // set up first. Until then both buttons say so and the flow carries on.
        .alert("Sign-in is not set up yet", isPresented: $notReady) {
            Button("Continue without an account") { next() }
        } message: {
            Text("Your progress is still saved on this device.")
        }
    }
}

private struct ChoicePage: View {
    let title: String
    let image: String?
    let subtitle: String?
    let options: [String]
    let multiple: Bool
    /// The last option means "none of the above": choosing it clears the others.
    let exclusiveLast: Bool
    @Binding var selection: Set<Int>
    let next: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 10) {
                    if let image {
                        FloatingArt(name: image, size: 110)
                            .padding(.bottom, 8)
                    }
                    Text(title)
                        .font(.serif(28))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                        .rise(0.05)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 15))
                            .padding(.bottom, 8)
                    }
                    ForEach(options.indices, id: \.self) { index in
                        row(index)
                            .rise(0.12 + Double(index) * 0.05)
                    }
                }
                .padding(.top, 28)
            }
            .scrollBounceBehavior(.basedOnSize)
            // An answer is always needed, and it is always confirmed with the button.
            PrimaryButton(title: "Continue", enabled: !selection.isEmpty, action: next)
                .padding(.top, 8)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func row(_ index: Int) -> some View {
        let on = selection.contains(index)
        return Button {
            Haptics.select()
            let none = exclusiveLast ? options.count - 1 : -1
            if !multiple || index == none {
                selection = on && multiple ? [] : [index]
            } else {
                selection.remove(none)
                if on {
                    selection.remove(index)
                } else {
                    selection.insert(index)
                }
            }
        } label: {
            HStack {
                Text(options[index]).font(.system(size: 16, weight: .medium))
                Spacer()
                Image(systemName: on ? (multiple ? "checkmark.circle.fill" : "largecircle.fill.circle") : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(on ? Color.brandBlue : Color(hex: 0x8A8390))
            }
            .foregroundStyle(Color.ink)
            .padding(.leading, 20)
            .padding(.trailing, 16)
            .frame(height: 56)
            .background(Capsule().fill(on ? Color.blueTint : Color.white))
            // Drawn inside the edge: a stroke centred on it is cut off by the scroll view.
            .overlay(Capsule().strokeBorder(on ? Color.brandBlue : Color.line, lineWidth: on ? 2 : 1.5))
        }
    }
}

/// The streak page plays itself: the flame, the title and the week arrive one
/// after the other, then the first day unlocks and the flame catches. Only then
/// does "Tap to continue" appear; there is no button.
private struct StreakPage: View {
    let next: () -> Void
    @State private var phase = 0

    private var finished: Bool { phase >= 5 }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            VStack(spacing: 28) {
                FlameView(day: 1, lit: phase >= 4)
                    .frame(width: 200, height: 200)
                    .reveal(phase >= 1)
                Text("Create a consistent daily learning routine")
                    .font(.serif(28))
                    .multilineTextAlignment(.center)
                    .reveal(phase >= 2)
                VStack(spacing: 12) {
                    WeekRow(items: phase >= 4 ? WeekRow.firstDay : WeekRow.notStarted)
                    Text("Build a streak, one day at a time").font(.system(size: 14))
                }
                .padding(14)
                .card()
                .reveal(phase >= 3)
            }
            Spacer(minLength: 12)
            TapToContinue(shown: finished, action: next)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            if finished { next() }
        }
        .task {
            for (step, delay) in [0.2, 0.6, 0.6, 0.9, 1.1].enumerated() {
                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } catch {
                    return
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    phase = step + 1
                }
                if step + 1 == 4 {
                    Haptics.success()
                } else {
                    Haptics.tap()
                }
            }
        }
    }
}
