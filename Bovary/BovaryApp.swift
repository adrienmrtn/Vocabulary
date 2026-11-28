import SwiftUI
import UIKit

@main
struct BovaryApp: App {
    init() {
        Fonts.register()
        Backend.shared.start()
        Subscriptions.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Shows the onboarding once, then the tabbed app. The hand-off is a soft cross-fade.
struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @ObservedObject private var language = LanguageStore.shared

    var body: some View {
        ZStack {
            if hasOnboarded {
                // A new language rebuilds the tabs, so every text is read again.
                MainTabView()
                    .id(language.language)
                    .transition(.opacity)
            } else {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        hasOnboarded = true
                    }
                }
                .transition(.opacity)
            }
        }
        .tint(Color.brandBlue)
        .preferredColorScheme(.light)
        .environment(\.locale, Locale(identifier: language.language.rawValue))
        .environment(\.layoutDirection, language.language.isRightToLeft ? .rightToLeft : .leftToRight)
    }
}

struct MainTabView: View {
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            WordsView()
                .tabItem { Label(tr("Words"), systemImage: "house") }
                .tag(0)
            TopicsView()
                .tabItem { Label(tr("Topics"), systemImage: "square.grid.2x2") }
                .tag(1)
            PracticeView()
                .tabItem { Label(tr("Practice"), systemImage: "graduationcap") }
                .tag(2)
            StatsView()
                .tabItem { Label(tr("Stats"), systemImage: "chart.bar") }
                .tag(3)
            ProfileView()
                .tabItem { Label(tr("Profile"), systemImage: "person") }
                .tag(4)
        }
        .onChange(of: tab) { _, _ in
            Haptics.select()
        }
    }
}
