import SwiftUI

struct StatsView: View {
    @State private var showPaywall = false

    private let days = ["Tu", "We", "Th", "Fr", "Sa", "Su", "Mo"]
    private let counters: [(value: String, label: String, symbol: String)] = [
        ("8", "Read", "text.justify.left"),
        ("1", "Favorited", "heart.fill"),
        ("1", "Saved", "bookmark.fill")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    NavigationLink {
                        GameView(mode: .shuffle, title: "Level test")
                    } label: {
                        HStack(spacing: 14) {
                            Image("level")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Take a test").font(.system(size: 16, weight: .semibold))
                                Text("to see your current level").font(.system(size: 15))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.muted)
                        }
                        .foregroundStyle(Color.ink)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 76)
                        .card()
                    }

                    HStack(spacing: 16) {
                        FlameView(day: 1)
                            .frame(width: 72, height: 72)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your streak").font(.system(size: 16, weight: .semibold))
                            WeekRow(days: days, done: 1)
                        }
                    }
                    .padding(16)
                    .card()

                    HStack(spacing: 10) {
                        ForEach(counters, id: \.label) { counter in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(counter.value).font(.serif(24))
                                    Spacer()
                                    Image(systemName: counter.symbol)
                                        .foregroundStyle(Color.flaubBlue)
                                }
                                Text(counter.label)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.muted)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .card()
                        }
                    }

                    VStack(spacing: 12) {
                        Text("Get full access to stats")
                            .font(.serif(26))
                        Text("See how you're doing and compare yourself with the rest of learners")
                            .font(.system(size: 16))
                            .multilineTextAlignment(.center)
                        PrimaryButton(title: "See all stats") { showPaywall = true }
                            .padding(.top, 6)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .card(radius: 24)
                    .padding(.top, 10)
                }
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color.cream)
            .navigationTitle("Word stats")
            .sheet(isPresented: $showPaywall) {
                OfferView(onContinue: { showPaywall = false })
                    .presentationDetents([.large])
            }
        }
    }
}

struct WeekRow: View {
    let days: [String]
    let done: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { item in
                VStack(spacing: 6) {
                    Text(item.element)
                        .font(.system(size: 11, weight: item.offset < done ? .bold : .medium))
                        .foregroundStyle(item.offset < done ? Color.ink : Color.muted)
                    ZStack {
                        Circle().fill(item.offset < done ? Color.flaubBlue : Color.line)
                        if item.offset < done {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 28, height: 28)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// The streak flame. Two layers breathe against each other, forever.
struct FlameView: View {
    let day: Int
    @State private var lit = false

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: side * 0.16, style: .continuous)
                    .fill(Color(hex: 0x1B2637))
                Image(systemName: "flame.fill")
                    .font(.system(size: side * 0.62))
                    .foregroundStyle(Color(hex: 0xFF8A1F))
                    .scaleEffect(x: lit ? 1.05 : 0.96, y: lit ? 0.95 : 1.06, anchor: .bottom)
                    .rotationEffect(.degrees(lit ? 2.5 : -2.5), anchor: .bottom)
                Image(systemName: "flame.fill")
                    .font(.system(size: side * 0.34))
                    .foregroundStyle(Color(hex: 0xFFD84A))
                    .offset(y: side * 0.13)
                    .scaleEffect(x: lit ? 0.94 : 1.06, y: lit ? 1.08 : 0.94, anchor: .bottom)
                    .rotationEffect(.degrees(lit ? -3 : 3), anchor: .bottom)
                Text("\(day)")
                    .font(.serif(side * 0.2))
                    .foregroundStyle(Color(hex: 0x1B2637))
                    .offset(y: side * 0.2)
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Streak flame, day \(day)")
        .onAppear {
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                lit = true
            }
        }
    }
}
