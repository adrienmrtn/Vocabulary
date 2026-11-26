import SwiftUI

struct PracticeView: View {
    private let challenges: [(mode: GameMode, image: String)] = [
        (.sprint, "ch_sprint"),
        (.rush, "ch_rush"),
        (.perfection, "ch_perfection")
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
                                GameView(mode: .shuffle, title: "Level test")
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
                        HistoryScreen()
                    } label: {
                        ImageRow(title: "Your history", image: "history")
                    }

                    SectionLabel(text: "Challenges")
                    HStack(spacing: 10) {
                        ForEach(challenges, id: \.image) { challenge in
                            NavigationLink {
                                GameView(mode: challenge.mode)
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    FillImage(name: challenge.image)
                                        .frame(height: 76)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    Text(challenge.mode.title)
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

                    NavigationLink {
                        GameView(mode: .shuffle)
                    } label: {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Try Game shuffle")
                                    .font(.system(size: 17, weight: .semibold))
                                Text(GameMode.shuffle.rule)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.muted)
                            }
                            .foregroundStyle(Color.ink)
                            Spacer(minLength: 0)
                            Image(systemName: "shuffle")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Color.flaubBlue)
                        }
                        .padding(16)
                        .card()
                    }

                    SectionLabel(text: "Categories")
                    ForEach(categories) { topic in
                        NavigationLink {
                            GameView(mode: .shuffle, title: topic.name, pool: topic.words)
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
