//
//  SubscriptionService.swift
//  BelloHub
//

import Foundation
import Observation

/// Her Bello Hub Pro plan (D33, D59): the one place the app reads the store. It answers the registration gate
/// (`SubscriptionStatusProviding`) and the Plan screen, listens for the store's updates for the whole session, and
/// believes only what the on-device verifier proves from Apple's signed data. At launch, and whenever the store cannot
/// be read, the last proven state stands (never past its signed end). Nothing about a purchase goes to our server.
/// Created once at the root and shared through the environment.
@MainActor
@Observable
final class SubscriptionService: SubscriptionStatusProviding {
    private(set) var state = SubscriptionState.unknown
    private(set) var offers: [PlanOffer] = []
    private(set) var isLoadingOffers = false
    /// The store could not list the products (no storefront, no network).
    private(set) var offersErrorMessage: String?

    private let provider: any SubscriptionProviding
    private let verifier: any SubscriptionVerifying
    private let now: @Sendable () -> Date
    private var updates: Task<Void, Never>?

    /// The app passes `StoreKitSubscriptionProvider` and `DeviceSubscriptionVerifier`; DEBUG launches pass a scripted
    /// store (`preview`, UI tests).
    init(
        provider: any SubscriptionProviding, verifier: any SubscriptionVerifying,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.provider = provider
        self.verifier = verifier
        self.now = now
    }

    var hasActivePlan: Bool { state.hasActivePlan }

    // MARK: - Lifecycle

    /// Shows the last proven state at once, reads the store, and starts following its updates for the session. Safe
    /// to call twice.
    func start() async {
        if state == .unknown, let cached = await verifier.cachedState(now: now()) { state = cached }
        await refreshState()
        guard updates == nil else { return }
        updates = Task { [weak self, provider] in
            for await _ in provider.updates() {
                guard let self else { return }
                await self.refreshState()
            }
        }
    }

    func stop() {
        updates?.cancel()
        updates = nil
    }

    /// The store's verified entitlements through the verifier; when the store cannot be read, the last proven state
    /// (or none).
    func refreshState() async {
        do {
            let entitlements = try await provider.entitlements()
            state = await verifier.verify(entitlements, now: now())
        } catch {
            state = await verifier.cachedState(now: now()) ?? .none
        }
    }

    // MARK: - Offers

    /// Entry point for `.task`; a second call while one runs does nothing.
    func loadOffers() async {
        guard !isLoadingOffers else { return }
        isLoadingOffers = true
        offersErrorMessage = nil
        defer { isLoadingOffers = false }
        do {
            offers = try await provider.offers()
            if offers.isEmpty { offersErrorMessage = Self.unavailableMessage }
        } catch {
            offersErrorMessage = Self.unavailableMessage
        }
    }

    func offer(for period: PlanPeriod) -> PlanOffer? {
        offers.first { $0.period == period }
    }

    // MARK: - Buying

    func purchase(_ period: PlanPeriod) async throws -> PurchaseOutcome {
        let outcome = try await provider.purchase(period)
        if outcome == .purchased { await refreshState() }
        return outcome
    }

    /// "Restore purchases": the App Store syncs her purchases, then the plan is read again. Whether a plan came back is
    /// what the verified entitlements say, not what the sync call returned.
    func restorePurchases() async throws -> PurchaseOutcome {
        try await provider.syncPurchases()
        await refreshState()
        return hasActivePlan ? .purchased : .nothingToRestore
    }

    func manageSubscription() async {
        await provider.showManageSubscriptions()
    }

    // MARK: - Private

    private static var unavailableMessage: String {
        String(interface: LocalizedStringResource(
            "plan.error.unavailable",
            defaultValue: "The App Store could not show the plans right now. Check your connection and try again."
        ))
    }
}
