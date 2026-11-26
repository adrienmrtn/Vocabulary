import SwiftUI
import UIKit

@main
struct FlaubApp: App {
    init() {
        Fonts.register()
        Self.configureBars()
        Backend.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }

    /// Native navigation and tab bars, tinted to the cream ground with serif titles.
    private static func configureBars() {
        let cream = UIColor(Color.cream)
        let ink = UIColor(Color.ink)

        func serif(_ size: CGFloat) -> UIFont {
            Fonts.uiFont(size)
        }

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = cream
        nav.shadowColor = .clear
        nav.largeTitleTextAttributes = [.font: serif(34), .foregroundColor: ink]
        nav.titleTextAttributes = [.font: serif(18), .foregroundColor: ink]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = .white
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
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
        .tint(Color.flaubBlue)
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
