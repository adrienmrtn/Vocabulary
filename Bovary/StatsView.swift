import SwiftUI

struct StatsView: View {
    @ObservedObject private var store = UserStore.shared

    private var counters: [(value: String, label: String, symbol: String)] {
        let saved = Set(store.state.collections.flatMap(\.words)).count
        return [
            ("\(store.state.history.count)", "Read", "text.justify.left"),
            ("\(store.state.favorites.count)", "Favorited", "heart.fill"),
            ("\(saved)", "Saved", "bookmark.fill")
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ScreenHeader(title: "Word stats")
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
                        FlameView(day: store.streak)
                            .frame(width: 72, height: 72)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your streak").font(.system(size: 16, weight: .semibold))
                            WeekRow(items: store.week)
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
                                        .foregroundStyle(Color.brandBlue)
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
                }
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .tabRoot()
        }
    }
}

struct WeekRow: View {
    /// Seven days, oldest first, each with a two-letter label and whether it was active.
    let items: [(label: String, done: Bool)]

    /// The row shown in onboarding: a first day done, the week ahead.
    static let firstDay: [(label: String, done: Bool)] =
        ["Tu", "We", "Th", "Fr", "Sa", "Su", "Mo"].enumerated().map { (label: $0.element, done: $0.offset == 0) }

    /// The same week before anything is done.
    static let notStarted: [(label: String, done: Bool)] = firstDay.map { (label: $0.label, done: false) }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { item in
                VStack(spacing: 6) {
                    Text(item.element.label)
                        .font(.system(size: 11, weight: item.element.done ? .bold : .medium))
                        .foregroundStyle(item.element.done ? Color.ink : Color.muted)
                    ZStack {
                        Circle().fill(item.element.done ? Color.brandBlue : Color.line)
                        if item.element.done {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .transition(.scale(scale: 0.2).combined(with: .opacity))
                        }
                    }
                    .frame(width: 28, height: 28)
                    .scaleEffect(item.element.done ? 1 : 0.92)
                    .animation(.spring(response: 0.4, dampingFraction: 0.45), value: item.element.done)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// The streak flame. Three layers flicker out of step with each other, a glow
/// breathes behind them and sparks rise. With `lit` false it is a cold grey
/// flame; turning `lit` on makes it catch.
struct FlameView: View {
    let day: Int
    var lit: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let night = Color(hex: 0x1B2637)

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: side * 0.16, style: .continuous)
                    .fill(night)
                Image(systemName: "flame.fill")
                    .font(.system(size: side * 0.62))
                    .foregroundStyle(Color(hex: 0x3A4658))
                    .opacity(lit ? 0 : 1)
                TimelineView(.animation(paused: reduceMotion || !lit)) { context in
                    burning(side: side, time: context.date.timeIntervalSinceReferenceDate)
                }
                .opacity(lit ? 1 : 0)
                .scaleEffect(lit ? 1 : 0.35, anchor: .bottom)
                Text("\(day)")
                    .font(.serif(side * 0.24))
                    .foregroundStyle(lit ? Color.white : Color(hex: 0xA9B4C6))
                    .shadow(color: Color(hex: 0x9A2E00).opacity(lit ? 0.9 : 0), radius: 0, x: 0, y: side * 0.012)
                    .shadow(color: night.opacity(0.35), radius: side * 0.03)
                    .offset(y: side * 0.2)
            }
            .frame(width: side, height: side)
            .animation(.spring(response: 0.55, dampingFraction: 0.5), value: lit)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Streak flame, day \(day)")
    }

    private func burning(side: CGFloat, time: Double) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xFF8A1F).opacity(0.5), .clear],
                                     center: .center, startRadius: 0, endRadius: side * 0.46))
                .scaleEffect(1 + 0.07 * sin(time * 3.1))
            ForEach(0..<6, id: \.self) { spark in
                let progress = (time * 0.55 + Double(spark) / 6).truncatingRemainder(dividingBy: 1)
                Circle()
                    .fill(Color(hex: 0xFFD84A))
                    .frame(width: side * 0.03, height: side * 0.03)
                    .offset(x: sin(Double(spark) * 2.4 + progress * 5) * side * 0.16,
                            y: side * 0.05 - progress * side * 0.42)
                    .opacity(1 - progress)
            }
            layer(side: side, size: 0.62, lift: 0, time: time, phase: 0,
                  colors: [Color(hex: 0xFF4E1A), Color(hex: 0xFF9A1F)])
            layer(side: side, size: 0.44, lift: 0.08, time: time, phase: 1.7,
                  colors: [Color(hex: 0xFF9A1F), Color(hex: 0xFFC93C)])
            layer(side: side, size: 0.26, lift: 0.16, time: time, phase: 3.1,
                  colors: [Color(hex: 0xFFD84A), Color(hex: 0xFFF3B0)])
        }
        .frame(width: side, height: side)
    }

    /// One tongue of the flame. Two sine waves of unrelated speeds are mixed so
    /// the movement never looks like a loop.
    private func layer(side: CGFloat, size: CGFloat, lift: CGFloat, time: Double, phase: Double,
                       colors: [Color]) -> some View {
        let sway = sin(time * 4.3 + phase) * 0.6 + sin(time * 7.9 + phase * 2) * 0.4
        let stretch = sin(time * 6.1 + phase) * 0.6 + sin(time * 11.3 + phase) * 0.4
        return Image(systemName: "flame.fill")
            .font(.system(size: side * size))
            .foregroundStyle(LinearGradient(colors: colors, startPoint: .bottom, endPoint: .top))
            .scaleEffect(x: 1 - 0.05 * stretch, y: 1 + 0.07 * stretch, anchor: .bottom)
            .rotationEffect(.degrees(3 * sway), anchor: .bottom)
            .offset(y: side * lift)
    }
}
