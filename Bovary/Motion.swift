import SwiftUI

// MARK: - Entrances

/// Fades a view in while it rises a little. Use increasing delays to stagger a list.
struct Rise: ViewModifier {
    let delay: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(delay)) {
                    shown = true
                }
            }
    }
}

/// Pops a view in with a small overshoot.
struct Pop: ViewModifier {
    let delay: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(shown ? 1 : 0.2)
            .opacity(shown ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.55).delay(delay)) {
                    shown = true
                }
            }
    }
}

extension View {
    func rise(_ delay: Double = 0) -> some View {
        modifier(Rise(delay: delay))
    }

    /// Shows or hides a block in place, so the layout does not jump when it
    /// arrives. Change `shown` inside `withAnimation` to animate it.
    func reveal(_ shown: Bool) -> some View {
        self
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 18)
            .scaleEffect(shown ? 1 : 0.96)
            .accessibilityHidden(!shown)
    }
}

/// The line that ends a page that plays itself. It pulses once it is shown.
struct TapToContinue: View {
    let shown: Bool
    let action: () -> Void
    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            Text("Tap to continue")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.muted)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
        }
        .opacity(shown ? (pulse ? 1 : 0.45) : 0)
        .disabled(!shown)
        .onChange(of: shown) { _, now in
            guard now else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

/// An illustration that pops in, then floats gently for as long as it is on screen.
struct FloatingArt: View {
    let name: String
    let size: CGFloat

    @State private var shown = false
    @State private var lifted = false

    var body: some View {
        FillImage(name: name)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.13, style: .continuous))
            .shadow(color: Color.ink.opacity(0.12), radius: 14, y: 10)
            .rotationEffect(.degrees(lifted ? 1.5 : -1.5))
            .offset(y: lifted ? -5 : 5)
            .scaleEffect(shown ? 1 : 0.7)
            .opacity(shown ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) {
                    shown = true
                }
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    lifted = true
                }
            }
            .accessibilityHidden(true)
    }
}

/// Which illustration goes with which onboarding question or message.
enum OnboardingArt {
    private static let byText: [String: String] = [
        "How old are you?": "onb_age",
        "Which option represents you best?": "onb_people",
        "How many words do you want to learn per week?": "onb_goal",
        "What would help make learning a daily habit?": "onb_habit",
        "Which topics are you interested in?": "tile_topics",
        "What drives your curiosity?": "onb_curiosity",
        "What's your vocabulary level?": "level",
        "Do you often encounter words you don't know?": "onb_test",
        "How would you describe your vocabulary?": "onb_voice",
        "Where does your vocabulary feel weakest?": "topic_debate",
        "Amazing! Let's test how many words you know...": "onb_test",
        "Become more articulate in just 1 minute a day, without even opening the app": "onb_voice",
        "You get unlimited free access to everything for 3 days": "onb_trial",
        "Before your trial ends, we'll check in with you to let you know": "tile_reminders"
    ]

    static func image(for text: String) -> String? {
        byText[text]
    }
}

// MARK: - Tab headers

/// The large serif title at the top of a tab, with room for a button on the right.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.serif(34))
                .foregroundStyle(Color.ink)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.top, 8)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title, trailing: { EmptyView() })
    }
}

extension View {
    /// For the first screen of a tab: the title is drawn in the content, so the
    /// system bar is hidden, and the status bar area stays cream while scrolling.
    func tabRoot() -> some View {
        self
            .background(Color.cream)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear
                    .frame(height: 0)
                    .background(Color.cream)
            }
    }
}

// MARK: - Social proof

struct SocialProof {
    struct Review: Identifiable {
        let id = UUID()
        let title: String
        let text: String
        let author: String
        let date: String
    }

    let rating: String
    let users: String
    let reviews: [Review]

    /// The figures and reviews shown on the rating page.
    ///
    /// What is here now is PLACEHOLDER content, written only to lay the page out.
    /// It appears in debug builds and in TestFlight builds, and never in a build
    /// downloaded from the App Store. Before shipping, replace `placeholder` with
    /// the real App Store rating, user count and reviews, then return them for
    /// every build.
    static var current: SocialProof? {
        #if DEBUG
        return placeholder
        #else
        // TestFlight builds carry a sandbox receipt; App Store builds do not.
        let testBuild = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        return testBuild ? placeholder : nil
        #endif
    }

    private static let placeholder = SocialProof(
        rating: "4.8",
        users: "100K+",
        reviews: [
            Review(title: "It finally sticks",
                   text: "I used three of this week's words in a client email without thinking about it. One minute a day really does add up.",
                   author: "Camille R.", date: "Jan 12, 2026"),
            Review(title: "My favorite widget",
                   text: "A new word on my Home Screen every morning. I have learned more this month than in a year of meaning to read more.",
                   author: "Jordan P.", date: "Feb 3, 2026"),
            Review(title: "Short and smart",
                   text: "The quizzes take two minutes and the words actually come back when I need them. The origins are my favorite part.",
                   author: "Priya S.", date: "Mar 21, 2026"),
            Review(title: "Beautiful to use",
                   text: "Calm design, no clutter, and the streak keeps me honest. I open it with my coffee every morning.",
                   author: "Marcus L.", date: "Apr 9, 2026")
        ]
    )
}
