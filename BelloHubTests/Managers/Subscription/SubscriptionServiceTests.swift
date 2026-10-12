//
//  SubscriptionServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The one reader of the store (D59): the verdict comes from the store's verified entitlements on this iPhone, the
/// last proven state stands offline and at launch, updates are followed for the session, restore re-reads the store,
/// and the registration gate opens once a plan is active. Nothing goes to a server.
@MainActor
@Suite("SubscriptionService")
struct SubscriptionServiceTests {
    private let yearly = SubscriptionState.active(period: .yearly, expiresAt: TestClock.days(30), willRenew: true)

    @Test("Start reads the verified entitlements: an active plan, then the snapshot is saved")
    func startReadsTheStore() async {
        let store = FakeSubscriptionSnapshotStore()
        let service = makeSubscriptionService(provider: FakeSubscriptionProvider(state: yearly), store: store)

        await service.start()
        defer { service.stop() }

        #expect(service.state == yearly)
        #expect(service.hasActivePlan)
        #expect(store.snapshot?.accessEndsAt == TestClock.days(30))
    }

    @Test("Offline, the last proven plan stands until its signed end; with no snapshot there is no plan")
    func offline() async {
        let provider = FakeSubscriptionProvider()
        provider.entitlementsError = FakeStoreError()
        let store = FakeSubscriptionSnapshotStore(SubscriptionSnapshot(state: yearly, seenAt: TestClock.days(-1)))

        let service = makeSubscriptionService(provider: provider, store: store)
        await service.refreshState()
        #expect(service.state == yearly)

        let later = makeSubscriptionService(provider: provider, store: store, now: TestClock.days(31))
        await later.refreshState()
        #expect(later.state == SubscriptionState.none)

        let fresh = makeSubscriptionService(provider: provider)
        await fresh.refreshState()
        #expect(fresh.state == SubscriptionState.none)
    }

    @Test("At launch the cached plan shows before the store answers")
    func cachedFirst() async {
        let provider = FakeSubscriptionProvider()
        provider.entitlementsError = FakeStoreError()
        let store = FakeSubscriptionSnapshotStore(SubscriptionSnapshot(state: yearly, seenAt: TestClock.now))
        let service = makeSubscriptionService(provider: provider, store: store)

        await service.start()
        defer { service.stop() }

        #expect(service.hasActivePlan)
    }

    @Test("A purchase refreshes the state and opens the registration gate (the 11th client, D42)")
    func purchaseOpensGate() async throws {
        let service = makeSubscriptionService()
        await service.start()
        defer { service.stop() }
        let repository = InMemoryClientRecordRepository()
        let gate = ClientRegistrationService(vault: VaultService(repository: repository), subscription: service)
        for index in 1...10 {
            _ = try await gate.register(makeClient(name: "Client \(index)"))
        }
        let eleventh = makeClient(name: "Client 11")
        #expect(try await gate.register(eleventh) == .needsSubscription)

        let outcome = try await service.purchase(.monthly)

        #expect(outcome == .purchased)
        #expect(service.hasActivePlan)
        #expect(try await gate.register(eleventh) == .registered)
    }

    @Test("A cancelled or pending purchase unlocks nothing")
    func purchaseNotFinished() async throws {
        let cancelled = makeSubscriptionService(provider: FakeSubscriptionProvider(purchaseOutcome: .cancelled))
        #expect(try await cancelled.purchase(.yearly) == .cancelled)
        #expect(!cancelled.hasActivePlan)

        let pending = makeSubscriptionService(provider: FakeSubscriptionProvider(purchaseOutcome: .pending))
        #expect(try await pending.purchase(.yearly) == .pending)
        #expect(!pending.hasActivePlan)
    }

    @Test("Offers come from the store, monthly first; an empty or failing store gives a message")
    func offers() async {
        let provider = FakeSubscriptionProvider()
        let service = makeSubscriptionService(provider: provider)

        await service.loadOffers()
        #expect(service.offers.map(\.period) == [.monthly, .yearly])
        #expect(service.offer(for: .yearly)?.displayPrice == "€149.99")
        #expect(service.offersErrorMessage == nil)

        provider.offersError = FakeStoreError()
        await service.loadOffers()
        #expect(service.offersErrorMessage != nil)
    }

    @Test("A refund arriving through the updates takes the plan away")
    func refundThroughUpdates() async {
        let provider = FakeSubscriptionProvider(state: yearly)
        let service = makeSubscriptionService(provider: provider)
        await service.start()
        defer { service.stop() }
        #expect(service.hasActivePlan)

        provider.push([StoreEntitlement(
            productID: FakeSubscriptionProvider.products.yearly, renewal: .revoked, expiresAt: TestClock.days(30),
            revokedAt: TestClock.now
        )])

        #expect(await Wait.untilMain { !service.hasActivePlan })
    }

    @Test("A failed payment in the grace period keeps the plan; billing retry without grace ends it")
    func graceAndRetry() async {
        let provider = FakeSubscriptionProvider()
        provider.entitlementsNow = [StoreEntitlement(
            productID: FakeSubscriptionProvider.products.monthly, renewal: .gracePeriod, expiresAt: TestClock.days(-1),
            graceExpiresAt: TestClock.days(6)
        )]
        let service = makeSubscriptionService(provider: provider)
        await service.refreshState()
        #expect(service.state == .inGracePeriod(period: .monthly, expiresAt: TestClock.days(6)))

        provider.entitlementsNow = [StoreEntitlement(
            productID: FakeSubscriptionProvider.products.monthly, renewal: .billingRetry, expiresAt: TestClock.days(-1)
        )]
        await service.refreshState()
        #expect(!service.hasActivePlan)
    }

    @Test("Restore syncs the store and reports whether a plan came back")
    func restore() async throws {
        let foundProvider = FakeSubscriptionProvider(restoreOutcome: .purchased)
        let found = makeSubscriptionService(provider: foundProvider)
        #expect(try await found.restorePurchases() == .purchased)
        #expect(found.hasActivePlan)
        #expect(foundProvider.syncCount == 1)

        let nothing = makeSubscriptionService()
        #expect(try await nothing.restorePurchases() == .nothingToRestore)
        #expect(!nothing.hasActivePlan)
    }
}
