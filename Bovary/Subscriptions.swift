import Foundation
import RevenueCat

/// The link to RevenueCat: which plans are on sale, whether the member is
/// subscribed, and the purchase itself.
///
/// What is sold is decided in the RevenueCat dashboard, not here. The paywall
/// shows every package of the current offering, and the discount screen shows
/// the offering named `discountOffering`. Changing a price means pointing an
/// offering at another product there; no app update is needed.
final class Subscriptions: ObservableObject {
    static let shared = Subscriptions()

    /// RevenueCat's public key for the iOS app (it starts with "appl_"). It is
    /// meant to ship in the app. If it were empty, nothing would be sold: the
    /// paywall would show no price and its button would simply move on.
    static let apiKey = "appl_aTrXHKGLzrCoRZPFpbIZNcPQpga"

    /// Identifier of the entitlement that every plan unlocks.
    static let entitlement = "premium"

    /// Identifier of the offering shown once when the main paywall is closed.
    static let discountOffering = "discount"

    enum Outcome {
        case purchased
        case cancelled
        case failed(String)
    }

    @Published private(set) var isPremium = false
    @Published private(set) var main: Offering?
    @Published private(set) var discount: Offering?
    /// Whether the member can still get the free trial. Apple grants it once.
    @Published private(set) var trialEligible = true

    var isConfigured: Bool { !Self.apiKey.isEmpty }

    private init() {}

    func start() {
        guard isConfigured else { return }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: Self.apiKey)
        Task { await refresh() }
        Task {
            for await info in Purchases.shared.customerInfoStream {
                await apply(info)
            }
        }
    }

    /// Loads the plans and the member's status. Fails quietly: the paywall
    /// copes with no plans.
    func refresh() async {
        guard isConfigured else { return }
        guard let offerings = try? await Purchases.shared.offerings() else { return }
        var eligible = true
        if let product = offerings.current?.annual?.storeProduct {
            let status = await Purchases.shared.checkTrialOrIntroDiscountEligibility(product: product)
            eligible = status != .ineligible
        }
        await show(main: offerings.current,
                   discount: offerings.offering(identifier: Self.discountOffering),
                   trialEligible: eligible)
        if let info = try? await Purchases.shared.customerInfo() {
            await apply(info)
        }
    }

    func buy(_ package: Package) async -> Outcome {
        guard isConfigured else { return .failed("Purchases are not set up yet.") }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled {
                return .cancelled
            }
            await apply(result.customerInfo)
            return .purchased
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Returns whether a subscription was found.
    func restore() async -> Bool {
        guard isConfigured, let info = try? await Purchases.shared.restorePurchases() else { return false }
        await apply(info)
        return info.entitlements[Self.entitlement]?.isActive == true
    }

    @MainActor
    private func show(main: Offering?, discount: Offering?, trialEligible: Bool) {
        self.main = main
        self.discount = discount
        self.trialEligible = trialEligible
    }

    @MainActor
    private func apply(_ info: CustomerInfo) {
        isPremium = info.entitlements[Self.entitlement]?.isActive == true
    }
}

extension Package {
    /// "year", "month" or "week", for sentences such as "per year".
    var periodName: String {
        switch packageType {
        case .annual: return tr("year")
        case .sixMonth: return tr("6 months")
        case .threeMonth: return tr("3 months")
        case .twoMonth: return tr("2 months")
        case .monthly: return tr("month")
        case .weekly: return tr("week")
        default: return tr("period")
        }
    }

    var planName: String {
        switch packageType {
        case .annual: return tr("Yearly")
        case .monthly: return tr("Monthly")
        case .weekly: return tr("Weekly")
        default: return storeProduct.localizedTitle
        }
    }

    /// The price as the App Store formats it for the member's country.
    var price: String { storeProduct.localizedPriceString }

    /// The plan's price spread over its months, formatted like the price itself.
    /// Nil for plans shorter than a month.
    var monthlyEquivalent: String? {
        let months: Int
        switch packageType {
        case .annual: months = 12
        case .sixMonth: months = 6
        case .threeMonth: months = 3
        case .twoMonth: months = 2
        default: return nil
        }
        let share = NSDecimalNumber(decimal: storeProduct.price / Decimal(months))
        return storeProduct.priceFormatter?.string(from: share)
    }

    /// Zero in the plan's currency, for "nothing due today".
    var zeroPrice: String {
        storeProduct.priceFormatter?.string(from: 0) ?? "0.00"
    }

    /// Length of the free trial in days, when the plan has one.
    var trialDays: Int? {
        guard let intro = storeProduct.introductoryDiscount,
              intro.paymentMode == .freeTrial else { return nil }
        switch intro.subscriptionPeriod.unit {
        case .day: return intro.subscriptionPeriod.value
        case .week: return intro.subscriptionPeriod.value * 7
        default: return nil
        }
    }
}
