import SwiftUI
import RevenueCat

/// The subscription offer. It lists the plans of RevenueCat's current
/// offering, with the yearly one chosen first. Closing it shows the discount
/// once, if there is one; after that, closing simply moves on.
struct OfferView: View {
    let onContinue: () -> Void

    @ObservedObject private var subscriptions = Subscriptions.shared
    @AppStorage("trialReminder") private var reminder = false
    @AppStorage("discountOffered") private var discountOffered = false
    @State private var selected: String?
    @State private var busy = false
    @State private var message: String?
    @State private var showDiscount = false

    private var packages: [Package] { subscriptions.main?.availablePackages ?? [] }

    private var chosen: Package? {
        packages.first { $0.identifier == selected } ?? subscriptions.main?.annual ?? packages.first
    }

    private func trial(_ package: Package) -> Int? {
        subscriptions.trialEligible ? package.trialDays : nil
    }

    private var title: String {
        guard let chosen else { return "Unlock every word, topic and game" }
        if let days = trial(chosen) {
            return "Try \(days) days for free, then \(chosen.price) per \(chosen.periodName)"
        }
        return "Unlock everything for \(chosen.price) per \(chosen.periodName)"
    }

    private var cta: String {
        guard let chosen else { return "Continue" }
        return trial(chosen) == nil ? "Subscribe" : "Start my free trial"
    }

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            if showDiscount, let offer = subscriptions.discount {
                DiscountView(offer: offer, regular: subscriptions.main?.annual,
                             buy: buy, decline: onContinue)
                    .transition(.opacity.combined(with: .offset(x: 0, y: 14)))
            } else {
                plans
            }
        }
        .foregroundStyle(Color.ink)
        .animation(.easeInOut(duration: 0.38), value: showDiscount)
        .disabled(busy)
        .overlay {
            if busy {
                ProgressView().controlSize(.large)
            }
        }
        .alert("Subscription", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") {}
        } message: {
            Text(message ?? "")
        }
        .task { await subscriptions.refresh() }
    }

    private var plans: some View {
        VStack(spacing: 14) {
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
                .accessibilityLabel("Close")
                Spacer()
            }
            Spacer(minLength: 0)
            FloatingArt(name: "onb_offer", size: 150)
                .padding(.bottom, 8)
            Text(title)
                .font(.serif(28))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            Spacer(minLength: 0)
            if packages.isEmpty {
                Text("Plans are not available right now.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.muted)
            }
            ForEach(packages, id: \.identifier) { package in
                planRow(package)
            }
            if let chosen, trial(chosen) != nil {
                Toggle("Reminder before trial ends", isOn: $reminder)
                    .font(.system(size: 15, weight: .medium))
                    .padding(.horizontal, 18)
                    .frame(height: 54)
                    .background(Capsule().fill(Color.white))
                    .onChange(of: reminder) { _, _ in Haptics.select() }
            }
            PrimaryButton(title: cta) {
                if let chosen {
                    buy(chosen)
                } else {
                    onContinue()
                }
            }
            if let chosen {
                Text(trial(chosen) == nil
                     ? "\(chosen.price) per \(chosen.periodName). Renews automatically. Cancel anytime."
                     : "Free for \(trial(chosen) ?? 0) days, then \(chosen.price) per \(chosen.periodName). "
                       + "Renews automatically. Cancel anytime.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.muted)
                    .multilineTextAlignment(.center)
            }
            HStack {
                Button("Restore") { restore() }
                Spacer()
                Button("Terms & Conditions") {}
                Spacer()
                Button("Privacy Policy") {}
            }
            .font(.system(size: 12))
            .foregroundStyle(Color.ink)
            .frame(height: 40)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func planRow(_ package: Package) -> some View {
        let on = package.identifier == chosen?.identifier
        return Button {
            Haptics.select()
            selected = package.identifier
        } label: {
            HStack(spacing: 12) {
                Image(systemName: on ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(on ? Color.brandBlue : Color(hex: 0x8A8390))
                VStack(alignment: .leading, spacing: 2) {
                    Text(package.planName)
                        .font(.system(size: 16, weight: .semibold))
                    if let days = trial(package) {
                        Text("\(days)-day free trial")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.muted)
                    }
                }
                Spacer()
                Text("\(package.price) / \(package.periodName)")
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 16)
            .frame(height: 62)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(on ? Color.blueTint : Color.white))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(on ? Color.brandBlue : Color.line, lineWidth: 1.5))
        }
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
        busy = true
        Task {
            let outcome = await subscriptions.buy(package)
            busy = false
            switch outcome {
            case .purchased:
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

/// The lower yearly price, shown once to someone who closed the main offer.
private struct DiscountView: View {
    let offer: Offering
    let regular: Package?
    let buy: (Package) -> Void
    let decline: () -> Void

    private var package: Package? { offer.annual ?? offer.availablePackages.first }

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            FloatingArt(name: "onb_trial", size: 170)
            Text("One-time offer")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.brandBlue))
                .padding(.top, 10)
                .rise(0.1)
            if let package {
                Text("A full \(package.periodName) for \(package.price)")
                    .font(.serif(32))
                    .multilineTextAlignment(.center)
                    .rise(0.2)
                if let regular, regular.storeProduct.price > package.storeProduct.price {
                    HStack(spacing: 6) {
                        Text("instead of")
                        Text(regular.price).strikethrough()
                    }
                    .font(.system(size: 16))
                    .foregroundStyle(Color.muted)
                    .rise(0.3)
                }
                Text("You won't see this price again once you leave this screen.")
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .rise(0.4)
            }
            Spacer(minLength: 0)
            if let package {
                PrimaryButton(title: "Get the offer") { buy(package) }
                Text("\(package.price) per \(package.periodName). Renews automatically. Cancel anytime.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.muted)
                    .multilineTextAlignment(.center)
            }
            Button("No thanks") {
                Haptics.tap()
                decline()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.ink)
            .frame(height: 48)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
