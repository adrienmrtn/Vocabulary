import SwiftUI
import UserNotifications

struct ProfileView: View {
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    private let shortcuts: [(title: String, image: String)] = [
        ("Favorites", "topic_emotions"),
        ("Your words", "topic_literature"),
        ("Collections", "tile_topics"),
        ("History", "history")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    PremiumBanner(title: "Go Premium",
                                  subtitle: "Access all topics, words, themes, and remove ads!")

                    Text("Customize the app")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)

                    LazyVGrid(columns: columns, spacing: 10) {
                        NavigationLink { PlaceholderScreen(title: "Topics you follow") } label: {
                            ProfileTile(title: "Topics you follow", image: "tile_topics")
                        }
                        NavigationLink { RemindersScreen() } label: {
                            ProfileTile(title: "Reminders", image: "tile_reminders")
                        }
                        NavigationLink { VoiceScreen() } label: {
                            ProfileTile(title: "Voices", image: "tile_voices")
                        }
                        NavigationLink { PlaceholderScreen(title: "Home Screen widgets") } label: {
                            ProfileTile(title: "Home Screen widgets", image: "tile_widgets")
                        }
                        NavigationLink { PlaceholderScreen(title: "Themes") } label: {
                            ProfileTile(title: "Themes", image: "tile_themes")
                        }
                        NavigationLink { IconScreen() } label: {
                            ProfileTile(title: "App icon", image: "tile_appicon")
                        }
                    }

                    Text("Your Vocabulary")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(shortcuts, id: \.title) { shortcut in
                            NavigationLink {
                                PlaceholderScreen(title: shortcut.title)
                            } label: {
                                HStack(spacing: 12) {
                                    FillImage(name: shortcut.image)
                                        .frame(width: 48, height: 48)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    Text(shortcut.title)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(Color.ink)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 8)
                                .frame(height: 66)
                                .card()
                            }
                        }
                    }
                }
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color.cream)
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        PlaceholderScreen(title: "Settings")
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
        }
    }
}

struct ProfileTile: View {
    let title: String
    let image: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FillImage(name: image)
                .frame(height: 124)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

// MARK: - App icon

/// Character and background pickers, shared by onboarding and Profile.
struct IconPicker: View {
    @AppStorage("iconCharacter") private var character = 0
    @AppStorage("iconBackground") private var background = 0

    private var safeCharacter: Int { min(max(character, 0), IconOptions.characters.count - 1) }
    private var safeBackground: Int { min(max(background, 0), IconOptions.backgrounds.count - 1) }

    var body: some View {
        VStack(spacing: 20) {
            IconTile(character: safeCharacter, background: safeBackground)
                .frame(width: 132, height: 132)
                .shadow(color: Color.ink.opacity(0.14), radius: 12, y: 10)

            VStack(spacing: 8) {
                SectionLabel(text: "Character")
                HStack(spacing: 8) {
                    ForEach(IconOptions.characters.indices, id: \.self) { index in
                        Button {
                            Haptics.select()
                            character = index
                        } label: {
                            IconTile(character: index, background: safeBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.flaubBlue, lineWidth: index == safeCharacter ? 3 : 0)
                                )
                        }
                        .accessibilityLabel(IconOptions.characters[index].name)
                    }
                }
                Text(IconOptions.characters[safeCharacter].name)
                    .font(.system(size: 15, weight: .semibold))
            }

            VStack(spacing: 8) {
                SectionLabel(text: "Background")
                HStack(spacing: 6) {
                    ForEach(IconOptions.backgrounds.indices, id: \.self) { index in
                        Button {
                            Haptics.select()
                            background = index
                        } label: {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(IconOptions.backgrounds[index].color)
                                .frame(height: 44)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(index == safeBackground ? Color.flaubBlue : Color.line,
                                                lineWidth: index == safeBackground ? 3 : 1.5)
                                )
                        }
                        .accessibilityLabel("\(IconOptions.backgrounds[index].name) background")
                    }
                }
            }
        }
        .foregroundStyle(Color.ink)
    }
}

struct IconTile: View {
    let character: Int
    let background: Int

    var body: some View {
        GeometryReader { proxy in
            let radius = proxy.size.width * 0.23
            IconOptions.backgrounds[background].color
                .overlay(Image(IconOptions.characters[character].image).resizable().scaledToFit())
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(Color.line, lineWidth: 1.5)
                )
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct IconScreen: View {
    var body: some View {
        ScrollView {
            IconPicker()
                .padding(20)
        }
        .background(Color.cream)
        .navigationTitle("App icon")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Haptics.page() }
    }
}

// MARK: - Voice

struct VoiceList: View {
    @AppStorage("voiceLanguage") private var voice = "en-US"

    var body: some View {
        VStack(spacing: 10) {
            ForEach(VoiceOption.all) { option in
                Button {
                    Haptics.select()
                    voice = option.id
                    Speaker.shared.say("Flaubert searched for the right word.", language: option.id)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "play.fill")
                        Text(option.name).font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Image(systemName: voice == option.id ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(voice == option.id ? Color.flaubBlue : Color.muted)
                    }
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 18)
                    .frame(height: 58)
                    .background(Capsule().fill(voice == option.id ? Color.blueTint : Color.white))
                    .overlay(Capsule().stroke(voice == option.id ? Color.flaubBlue : Color.line, lineWidth: 1.5))
                }
            }
        }
    }
}

struct VoiceScreen: View {
    var body: some View {
        ScrollView {
            VoiceList()
                .padding(20)
        }
        .background(Color.cream)
        .navigationTitle("Voices")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Haptics.page() }
    }
}

// MARK: - Reminders

struct ReminderSettings: View {
    @AppStorage("remindersPerDay") private var perDay = 10
    @AppStorage("reminderStart") private var startMinutes = 9 * 60
    @AppStorage("reminderEnd") private var endMinutes = 22 * 60

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("How many").font(.system(size: 16, weight: .medium))
                Spacer()
                Stepper("\(perDay)x", value: $perDay, in: 1...30)
                    .fixedSize()
                    .onChange(of: perDay) { _, _ in Haptics.select() }
            }
            .padding(.horizontal, 18)
            .frame(height: 58)
            .card(radius: 29)

            VStack(spacing: 0) {
                DatePicker("Start at", selection: binding($startMinutes), displayedComponents: .hourAndMinute)
                    .padding(.horizontal, 18)
                    .frame(height: 58)
                Divider().overlay(Color.line)
                DatePicker("End at", selection: binding($endMinutes), displayedComponents: .hourAndMinute)
                    .padding(.horizontal, 18)
                    .frame(height: 58)
            }
            .font(.system(size: 16, weight: .medium))
            .card(radius: 20)
        }
        .foregroundStyle(Color.ink)
    }

    /// Stores a time of day as minutes since midnight.
    private func binding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding<Date>(
            get: {
                Calendar.current.date(bySettingHour: minutes.wrappedValue / 60,
                                      minute: minutes.wrappedValue % 60,
                                      second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }
}

enum Notifications {
    /// Asks iOS for permission. Scheduling the daily words comes later.
    static func requestPermission(then completion: @escaping () -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}

struct RemindersScreen: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ReminderSettings()
                PrimaryButton(title: "Allow and Save") {
                    Notifications.requestPermission { Haptics.success() }
                }
            }
            .padding(20)
        }
        .background(Color.cream)
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Haptics.page() }
    }
}
