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

    var body: some View {
        ZStack {
            if hasOnboarded {
                MainTabView()
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
    }
}

struct MainTabView: View {
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            WordsView()
                .tabItem { Label("Words", systemImage: "house") }
                .tag(0)
            TopicsView()
                .tabItem { Label("Topics", systemImage: "square.grid.2x2") }
                .tag(1)
            PracticeView()
                .tabItem { Label("Practice", systemImage: "graduationcap") }
                .tag(2)
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
                .tag(3)
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person") }
                .tag(4)
        }
        .onChange(of: tab) { _, _ in
            Haptics.select()
        }
    }
}
