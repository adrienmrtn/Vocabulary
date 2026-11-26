import SwiftUI

/// One page of the onboarding. The list below is the whole flow, in order.
enum OnboardingStep {
    case welcome
    case choice(title: String, subtitle: String?, options: [String], multiple: Bool, skippable: Bool)
    case art(image: String, title: String)
    case name
    case streak
    case notifications
    case icon
    case theme
    case voice
    case wordCard
    case text(String)
    case offer
    case widget
    case splash

    static func single(_ title: String, _ options: [String], skippable: Bool = true) -> OnboardingStep {
        .choice(title: title, subtitle: nil, options: options, multiple: false, skippable: skippable)
    }

    static func multi(_ title: String, _ options: [String], subtitle: String? = nil,
                      skippable: Bool = true) -> OnboardingStep {
        .choice(title: title, subtitle: subtitle, options: options, multiple: true, skippable: skippable)
    }

    static let flow: [OnboardingStep] = [
        .welcome,
        .single("How did you hear about Flaub?",
                ["Facebook", "Instagram", "Friend/family", "Web search", "TikTok", "App Store", "Other"],
                skippable: false),
        .art(image: "level", title: "Tailor your word recommendations"),
        .single("How old are you?", ["13 to 17", "18 to 24", "25 to 34", "35 to 44", "45 to 54", "55+"]),
        .single("Which option represents you best?", ["Female", "Male", "Other", "Prefer not to say"]),
        .name,
        .art(image: "tile_themes", title: "Customize the app to improve your experience"),
        .single("How many words do you want to learn per week?",
                ["10 words a week", "30 words a week", "50 words a week"]),
        .streak,
        .multi("What would help make learning a daily habit?",
               ["Getting regular reminders", "Tracking my progress", "A home/lock screen widget",
                "Personalized quizzes and games"]),
        .art(image: "tile_widgets", title: "With widgets, you learn words without even opening the app"),
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
               subtitle: "Select all the ones you know", skippable: false),
        .multi("Intermediate words", ["Morose", "Impeccable", "Squander", "Whet", "Pervasive", "Deportment"],
               subtitle: "Select all the ones you know", skippable: false),
        .multi("Advanced words",
               ["Lucubration", "Quixotic", "Numinous", "Superincumbent", "Callipygian", "Logophile"],
               subtitle: "Select all the ones you know", skippable: false),
        .art(image: "result", title: "Great! A personalized level assessment is waiting for you in the app"),
        .text("Become more articulate in just 1 minute a day, without even opening the app"),
        .text("You get unlimited free access to everything for 3 days"),
        .text("Before your trial ends, we'll check in with you to let you know"),
        .offer,
        .widget,
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
            page(steps[index])
                .id(index)
                .transition(.opacity.combined(with: .offset(x: 0, y: 14)))
        }
        .animation(.easeInOut(duration: 0.38), value: index)
        .foregroundStyle(Color.ink)
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
        case let .choice(title, _, options, _, _):
            let chosen = (answers[index] ?? []).sorted().map { options[$0] }
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
        case let .choice(title, subtitle, options, multiple, skippable):
            ChoicePage(title: title, subtitle: subtitle, options: options, multiple: multiple,
                       skippable: skippable, selection: selection(for: index), next: next)
        case let .art(image, title):
            Scaffold(title: nil, cta: "Continue", next: next) {
                VStack(spacing: 44) {
                    FillImage(name: image)
                        .frame(width: 270, height: 270)
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    Text(title)
                        .font(.serif(28))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
            }
        case .name:
            Scaffold(title: "What do you want to be called?", skippable: true, cta: "Continue",
                     ctaEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty, next: next) {
                TextField("Your name", text: $name)
                    .textContentType(.givenName)
                    .submitLabel(.done)
                    .padding(.horizontal, 20)
                    .frame(height: 56)
                    .background(Capsule().fill(Color.white))
                    .overlay(Capsule().stroke(Color.line, lineWidth: 1.5))
            }
        case .streak:
            Scaffold(title: nil, cta: "Continue", next: next) {
                VStack(spacing: 28) {
                    FlameView(day: 1)
                        .frame(width: 200, height: 200)
                    Text("Create a consistent daily learning routine")
                        .font(.serif(28))
                        .multilineTextAlignment(.center)
                    VStack(spacing: 12) {
                        WeekRow(items: WeekRow.firstDay)
                        Text("Build a streak, one day at a time").font(.system(size: 14))
                    }
                    .padding(14)
                    .card()
                }
                .padding(.top, 20)
            }
        case .notifications:
            Scaffold(title: "Get words throughout the day", cta: "Allow and Save",
                     next: { Notifications.requestPermission(then: next) }) {
                VStack(spacing: 18) {
                    Text("Allow notifications to get daily words").font(.system(size: 15))
                    HStack(spacing: 12) {
                        IconTile(character: 0, background: 0).frame(width: 38, height: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("Flaub").font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text("Now").font(.system(size: 13)).foregroundStyle(Color.muted)
                            }
                            Text("Salubrious (adj.) – clean, conducive to health").font(.system(size: 13))
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
                    .shadow(color: Color.ink.opacity(0.1), radius: 9, y: 6)
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
            Scaffold(title: "Get deeper insight into each word you learn", cta: "Continue", next: next) {
                WordCard(word: Catalog.featured)
            }
        case let .text(message):
            Scaffold(title: nil, cta: "Continue", next: next) {
                Text(message)
                    .font(.serif(28))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .frame(maxHeight: .infinity)
            }
        case .offer:
            OfferView(onContinue: next)
        case .widget:
            Scaffold(title: "Add a widget to your Home Screen", cta: "Install widget",
                     secondary: "Remind me later", next: next) {
                VStack(spacing: 22) {
                    Text("On your phone's Home Screen, touch and hold an empty area, then tap Edit")
                        .font(.system(size: 15))
                        .multilineTextAlignment(.center)
                    VStack(spacing: 4) {
                        Text("ameliorate").font(.serif(24))
                        Text("(v.) To improve").font(.serif(16, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 108)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.flaubBlue))
                    .padding(.horizontal, 30)
                }
            }
        case .splash:
            Text("Welcome to Flaub")
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
    var skippable: Bool = false
    let cta: String
    var ctaEnabled: Bool = true
    var secondary: String? = nil
    let next: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip") { next() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.ink)
                    .frame(height: 44)
                    .opacity(skippable ? 1 : 0)
                    .disabled(!skippable)
            }
            ScrollView {
                VStack(spacing: 18) {
                    if let title {
                        Text(title)
                            .font(.serif(28))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 4)
                    }
                    content()
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
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

private struct WelcomePage: View {
    let next: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            FillImage(name: "hero")
                .frame(width: 290, height: 290)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            Text("Expand your vocabulary in 1 minute a day")
                .font(.serif(32))
                .multilineTextAlignment(.center)
                .padding(.top, 30)
            Text("Learn new words with a daily habit that takes just 1 minute")
                .font(.system(size: 16))
                .multilineTextAlignment(.center)
                .padding(.top, 12)
            Spacer(minLength: 12)
            PrimaryButton(title: "Get started", action: next)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }
}

private struct ChoicePage: View {
    let title: String
    let subtitle: String?
    let options: [String]
    let multiple: Bool
    let skippable: Bool
    @Binding var selection: Set<Int>
    let next: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip") { next() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.ink)
                    .frame(height: 44)
                    .opacity(skippable ? 1 : 0)
                    .disabled(!skippable)
            }
            ScrollView {
                VStack(spacing: 10) {
                    Text(title)
                        .font(.serif(28))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 15))
                            .padding(.bottom, 8)
                    }
                    ForEach(options.indices, id: \.self) { index in
                        row(index)
                    }
                }
                .padding(.top, 8)
            }
            .scrollBounceBehavior(.basedOnSize)
            if multiple {
                PrimaryButton(title: "Continue", action: next)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func row(_ index: Int) -> some View {
        let on = selection.contains(index)
        return Button {
            Haptics.select()
            if multiple {
                if on {
                    selection.remove(index)
                } else {
                    selection.insert(index)
                }
            } else {
                selection = [index]
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    next()
                }
            }
        } label: {
            HStack {
                Text(options[index]).font(.system(size: 16, weight: .medium))
                Spacer()
                Image(systemName: on ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(on ? Color.flaubBlue : Color(hex: 0x8A8390))
            }
            .foregroundStyle(Color.ink)
            .padding(.leading, 20)
            .padding(.trailing, 16)
            .frame(height: 56)
            .background(Capsule().fill(on ? Color.blueTint : Color.white))
            .overlay(Capsule().stroke(on ? Color.flaubBlue : Color.line, lineWidth: 1.5))
        }
    }
}

private struct WordCard: View {
    let word: Word

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
                .frame(maxWidth: .infinity)
            label("Example")
            Text(word.example).font(.system(size: 15))
            label("Synonyms")
                .opacity(word.synonyms.isEmpty ? 0 : 1)
            HStack(spacing: 6) {
                ForEach(word.synonyms, id: \.self) { synonym in
                    Text(synonym)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: 0x0A3FB3))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.blueTint))
                }
            }
            label("Origin")
            Text(word.origin).font(.system(size: 15))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 24)
        .padding(.horizontal, 12)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Color.muted)
            .padding(.top, 10)
    }
}

/// The trial offer. Prices are placeholders until StoreKit products exist.
struct OfferView: View {
    let onContinue: () -> Void
    @AppStorage("trialReminder") private var reminder = false

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            VStack(spacing: 14) {
                Spacer()
                Text("Try 3 days for free, then [PRICE] per year")
                    .font(.serif(30))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                Spacer()
                Toggle("Reminder before trial ends", isOn: $reminder)
                    .font(.system(size: 15, weight: .medium))
                    .padding(.horizontal, 18)
                    .frame(height: 58)
                    .background(Capsule().fill(Color.white))
                    .onChange(of: reminder) { _, _ in Haptics.select() }
                PrimaryButton(title: "Try for $0.00", action: onContinue)
                HStack {
                    Button("Restore") {}
                    Spacer()
                    Button("Terms & Conditions") {}
                    Spacer()
                    Button("Privacy Policy") {}
                }
                .font(.system(size: 12))
                .foregroundStyle(Color.ink)
                .frame(height: 44)
            }
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
}
