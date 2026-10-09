//
//  SubscriptionService.swift
//  BelloHub
//

import Foundation
import Observation

/// Her Bello Hub Pro plan (D33, D42): the one place the app reads the store. It answers the registration gate
/// (`SubscriptionStatusProviding`) and the Plan screen, listens for the store's updates while the app runs, and hands
/// every change to the server verifier before it believes it. Created once at the root and shared through the
/// environment.
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
    private var updates: Task<Void, Never>?

    init(
        provider: any SubscriptionProviding = StoreKitSubscriptionProvider(),
        verifier: any SubscriptionVerifying = OfflineSubscriptionVerifier()
    ) {
        self.provider = provider
        self.verifier = verifier
    }

    var hasActivePlan: Bool { state.hasActivePlan }

    // MARK: - Lifecycle

    /// Reads the current entitlement and starts following the store's updates. Safe to call twice.
    func start() async {
        await refreshState()
        guard updates == nil else { return }
        updates = Task { [weak self, provider] in
            for await update in provider.stateUpdates() {
                guard let self else { return }
                await self.adopt(update)
            }
        }
    }

    func stop() {
        updates?.cancel()
        updates = nil
    }

    func refreshState() async {
        await adopt(await provider.currentState())
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

    func restorePurchases() async throws -> PurchaseOutcome {
        let outcome = try await provider.restorePurchases()
        await refreshState()
        return outcome
    }

    func manageSubscription() async {
        await provider.showManageSubscriptions()
    }

    // MARK: - Private

    /// The store's answer goes through the server first; when the server cannot be reached the store's answer is
    /// kept, because StoreKit 2 already checked Apple's signature on the device.
    private func adopt(_ storeState: SubscriptionState) async {
        state = (try? await verifier.verify(storeState)) ?? storeState
    }

    private static var unavailableMessage: String {
        String(
            localized: "plan.error.unavailable",
            defaultValue: "The App Store could not show the plans right now. Check your connection and try again."
        )
    }
}
