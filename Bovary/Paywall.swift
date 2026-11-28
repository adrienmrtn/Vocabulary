import SwiftUI
import RevenueCat

/// The subscription offer: a plain page that explains how the free trial goes,
/// with a single yearly plan and a single button. Its blocks arrive one after
/// the other. The close button only shows after a few seconds; closing shows
/// the discount once, if there is one, and after that simply moves on.
struct OfferView: View {
    let onContinue: () -> Void

    @ObservedObject private var subscriptions = Subscriptions.shared
    @AppStorage("discountOffered") private var discountOffered = false
    @State private var phase = 0
    @State private var canClose = false
    @State private var busy = false
    @State private var message: String?
    @State private var showDiscount = false

    /// Always the yearly plan of the current offering.
    private var plan: Package? {
        subscriptions.main?.annual ?? subscriptions.main?.availablePackages.first
    }

    private var trialDays: Int? {
        guard let plan, subscriptions.trialEligible else { return nil }
        return plan.trialDays
    }

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            if showDiscount, let offer = subscriptions.discount {
                DiscountView(offer: offer, regular: plan, buy: buy, decline: onContinue)
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
            } else {
                page
            }
        }
        .foregroundStyle(Color.ink)
        .animation(.easeInOut(duration: 0.45), value: showDiscount)
        .disabled(busy)
        .overlay {
            if busy {
                ProgressView().controlSize(.large)
            }
        }
        .alert(tr("Subscription"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button(tr("OK")) {}
        } message: {
            Text(tr(message ?? ""))
        }
        .task { await subscriptions.refresh() }
        .task {
            for (step, delay) in [0.25, 0.6, 0.55, 0.55, 0.6].enumerated() {
                guard (try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))) != nil else { return }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                    phase = step + 1
                }
                Haptics.tap()
            }
        }
        .task {
            // The way out stays hidden for eight seconds.
            guard (try? await Task.sleep(nanoseconds: 8_000_000_000)) != nil else { return }
            withAnimation(.easeIn(duration: 0.4)) {
                canClose = true
            }
        }
    }

    private var page: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    Haptics.tap()
                    close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.muted)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(tr("Close"))
                .opacity(canClose || plan == nil ? 1 : 0)
                .disabled(!(canClose || plan == nil))
                Spacer()
            }
            if let plan {
                if let days = trialDays {
                    trialPage(plan, days: days)
                } else {
                    plainPage(plan)
                }
            } else {
                Spacer()
                Text(tr("Unlock all of Bovary"))
                    .font(.serif(30))
                Text(tr("Plans are not available right now."))
                    .font(.system(size: 15))
                    .foregroundStyle(Color.muted)
                    .padding(.top, 8)
                Spacer()
                PrimaryButton(title: "Continue", action: onContinue)
            }
            footer
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    /// The member can still have the trial: say what happens today, when the
    /// reminder comes and when the first payment is taken.
    @ViewBuilder
    private func trialPage(_ plan: Package, days: Int) -> some View {
        Text(tr("How your free trial works"))
            .font(.serif(30))
            .multilineTextAlignment(.center)
            .reveal(phase >= 1)
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(plan.zeroPrice)
                .font(.serif(46))
            Text(tr("today"))
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.muted)
        }
        .padding(.top, 10)
        .reveal(phase >= 1)

        VStack(alignment: .leading, spacing: 0) {
            TimelineRow(symbol: "lock.open.fill", when: "Today",
                        title: "You unlock everything",
                        detail: "Every word, topic and game in Bovary.", last: false)
                .reveal(phase >= 2)
            TimelineRow(symbol: "bell.fill", when: days - 1 <= 1 ? "Tomorrow" : tr("In %@ days", "\(days - 1)"),
                        title: "We send you a reminder",
                        detail: "A notification the day before your trial ends.", last: false)
                .reveal(phase >= 3)
            TimelineRow(symbol: "creditcard.fill", when: tr("In %@ days", "\(days)"),
                        title: "Your subscription starts",
                        detail: tr("You're charged %@ for the year, unless you cancel before.", "\(plan.price)"), last: true)
                .reveal(phase >= 4)
        }
        .padding(.top, 26)
        Spacer(minLength: 12)
        VStack(spacing: 10) {
            PrimaryButton(title: "Start my free trial") { buy(plan) }
            priceLines(plan, lead: tr("Free for %@ days, then %@ per %@", "\(days)", "\(plan.price)", plan.periodName))
        }
        .reveal(phase >= 5)
    }

    /// The trial was already used: the same plain page, without the timeline.
    @ViewBuilder
    private func plainPage(_ plan: Package) -> some View {
        Text(tr("Unlock all of Bovary"))
            .font(.serif(30))
            .multilineTextAlignment(.center)
            .reveal(phase >= 1)
        VStack(alignment: .leading, spacing: 0) {
            TimelineRow(symbol: "text.book.closed.fill", when: "Words",
                        title: "Every word of the catalogue",
                        detail: "With examples, synonyms and origins.", last: false)
                .reveal(phase >= 2)
            TimelineRow(symbol: "square.grid.2x2.fill", when: "Topics",
                        title: "Every topic",
                        detail: "From emotions to science and literature.", last: false)
                .reveal(phase >= 3)
            TimelineRow(symbol: "gamecontroller.fill", when: "Games",
                        title: "Every quiz",
                        detail: "Short games that make the words stick.", last: true)
                .reveal(phase >= 4)
        }
        .padding(.top, 26)
        Spacer(minLength: 12)
        VStack(spacing: 10) {
            PrimaryButton(title: "Subscribe") { buy(plan) }
            priceLines(plan, lead: tr("%@ per %@", "\(plan.price)", plan.periodName))
        }
        .reveal(phase >= 5)
    }

    /// Under the button: what is billed, then the same amount per month, larger.
    private func priceLines(_ plan: Package, lead: String) -> some View {
        VStack(spacing: 4) {
            Text(tr(lead))
                .font(.system(size: 15))
            if let monthly = plan.monthlyEquivalent {
                Text(tr("That's %@ per month", "\(monthly)"))
                    .font(.serif(24))
            }
            Text(tr("No commitment. Cancel anytime."))
                .font(.system(size: 13))
                .foregroundStyle(Color.muted)
                .padding(.top, 2)
        }
        .multilineTextAlignment(.center)
    }

    private var footer: some View {
        HStack {
            Button(tr("Restore")) { restore() }
            Spacer()
            Button(tr("Terms & Conditions")) {}
            Spacer()
            Button(tr("Privacy Policy")) {}
        }
        .font(.system(size: 12))
        .foregroundStyle(Color.muted)
        .frame(height: 40)
        .padding(.top, 4)
    }

    /// The discount is offered a single time, ever. That keeps "one-time offer" true.
    private func close() {
        if subscriptions.discount != nil, !discountOffered {
            discountOffered = true
            showDiscount = true
        } else {
            onContinue()
        }
    }

    private func buy(_ package: Package) {
        let trial = subscriptions.trialEligible ? package.trialDays : nil
        busy = true
        Task {
            let outcome = await subscriptions.buy(package)
            busy = false
            switch outcome {
            case .purchased:
                if let trial {
                    Notifications.scheduleTrialReminder(trialDays: trial)
                }
                Haptics.success()
                onContinue()
            case .cancelled:
                break
            case let .failed(reason):
                Haptics.error()
                message = reason
            }
        }
    }

    private func restore() {
        busy = true
        Task {
            let found = await subscriptions.restore()
            busy = false
            if found {
                Haptics.success()
                onContinue()
            } else {
                message = "No active subscription was found for this Apple Account."
            }
        }
    }
}

/// One step of the trial: a round icon on a line, with when it happens and what happens.
private struct TimelineRow: View {
    let symbol: String
    let when: String
    let title: String
    let detail: String
    let last: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.ink))
                Rectangle()
                    .fill(Color.line)
                    .frame(width: 3)
                    .frame(maxHeight: .infinity)
                    .opacity(last ? 0 : 1)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(tr(when).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.muted)
                Text(tr(title))
                    .font(.system(size: 17, weight: .semibold))
                Text(tr(detail))
                    .font(.system(size: 14))
                    .foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, last ? 0 : 22)
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The lower yearly price, shown once to someone who closed the main offer.
/// "No thanks" only appears after a few seconds.
private struct DiscountView: View {
    let offer: Offering
    let regular: Package?
    let buy: (Package) -> Void
    let decline: () -> Void

    @State private var canDecline = false
    @State private var pulse = false

    private let gold = Color(hex: 0xFFD84A)

    private var package: Package? { offer.annual ?? offer.availablePackages.first }

    /// How much cheaper the offer is than the regular yearly plan, in percent.
    private var percent: Int? {
        guard let package, let regular, regular.storeProduct.price > package.storeProduct.price else { return nil }
        let ratio = NSDecimalNumber(decimal: package.storeProduct.price / regular.storeProduct.price).doubleValue
        return Int(((1 - ratio) * 100).rounded())
    }

    /// What is actually charged, next to the regular price when the offer is cheaper.
    private func billed(_ package: Package) -> String {
        var line = tr("Charged %@ per %@", "\(package.price)", package.periodName)
        if let regular, percent != nil {
            line += tr(" instead of %@", "\(regular.price)")
        }
        return line + tr(". Renews automatically. Cancel anytime.")
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.brandBlue, Color(hex: 0x062E99)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                Text(tr("ONE-TIME OFFER"))
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(gold))
                    .padding(.top, 24)
                    .rise(0.05)
                Spacer(minLength: 8)
                if let percent {
                    ZStack {
                        Image(systemName: "seal.fill")
                            .font(.system(size: 190))
                            .foregroundStyle(gold)
                            .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
                        Text(tr("-%@%%", "\(percent)"))
                            .font(.serif(54))
                            .foregroundStyle(Color.ink)
                    }
                    .rotationEffect(.degrees(-9))
                    .scaleEffect(pulse ? 1.05 : 0.97)
                    .modifier(Pop(delay: 0.15))
                    .accessibilityLabel(tr("%@ percent off", "\(percent)"))
                }
                if let package {
                    Text(tr("A full %@ of Bovary for only", package.periodName))
                        .font(.serif(24))
                        .multilineTextAlignment(.center)
                        .padding(.top, 18)
                        .rise(0.35)
                    if let monthly = package.monthlyEquivalent {
                        Text(monthly)
                            .font(.serif(72))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .rise(0.45)
                        Text(tr("per month"))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(gold)
                            .rise(0.55)
                    } else {
                        Text(package.price)
                            .font(.serif(72))
                            .rise(0.45)
                    }
                    Text(tr("You'll only see this price once."))
                        .font(.system(size: 14))
                        .opacity(0.8)
                        .padding(.top, 8)
                        .rise(0.75)
                }
                Spacer(minLength: 8)
                if let package {
                    Button {
                        Haptics.tap()
                        buy(package)
                    } label: {
                        Text(tr("Claim my discount"))
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(Color.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 62)
                            .background(Capsule().fill(gold))
                            .shadow(color: .black.opacity(0.25), radius: 14, y: 8)
                    }
                    .scaleEffect(pulse ? 1.02 : 0.99)
                    .rise(0.85)
                    Text(tr(billed(package)))
                        .font(.system(size: 12))
                        .opacity(0.8)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                }
                Button(tr("No thanks")) {
                    Haptics.tap()
                    decline()
                }
                .font(.system(size: 16, weight: .semibold))
                .frame(height: 48)
                .opacity(canDecline ? 0.85 : 0)
                .disabled(!canDecline)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .onAppear {
            Haptics.success()
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .task {
            // The way out stays hidden for five seconds.
            guard (try? await Task.sleep(nanoseconds: 5_000_000_000)) != nil else { return }
            withAnimation(.easeIn(duration: 0.4)) {
                canDecline = true
            }
        }
    }
}
