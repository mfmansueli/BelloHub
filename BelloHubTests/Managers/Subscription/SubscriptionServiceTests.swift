//
//  SubscriptionServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The one reader of the store: the server verifier is asked before a state is believed, offers come from the
/// store, and the registration gate opens once a plan is active.
@MainActor
@Suite("SubscriptionService")
struct SubscriptionServiceTests {
    @Test("Start reads the entitlement through the verifier; the server's word wins")
    func verifierWins() async {
        let provider = FakeSubscriptionProvider(state: .active(period: .monthly, expiresAt: nil, willRenew: true))
        let verifier = FakeSubscriptionVerifier(override: SubscriptionState.none)
        let service = SubscriptionService(provider: provider, verifier: verifier)

        await service.start()
        defer { service.stop() }

        #expect(service.state == SubscriptionState.none, "the server says no plan, so there is none")
        #expect(verifier.received.count == 1)
        #expect(!service.hasActivePlan)
    }

    @Test("When the server cannot be reached the store's signed answer is kept")
    func offlineKeepsStore() async {
        let provider = FakeSubscriptionProvider(state: .active(period: .yearly, expiresAt: nil, willRenew: true))
        let service = SubscriptionService(
            provider: provider, verifier: FakeSubscriptionVerifier(error: FakeStoreError())
        )

        await service.start()
        defer { service.stop() }

        #expect(service.hasActivePlan)
        #expect(service.state.period == .yearly)
    }

    @Test("A purchase refreshes the state and opens the registration gate (the 11th client, D42)")
    func purchaseOpensGate() async throws {
        let service = SubscriptionService(provider: FakeSubscriptionProvider(), verifier: FakeSubscriptionVerifier())
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

    @Test("A purchase carries the server's account token into the store")
    func purchaseCarriesToken() async throws {
        let token = UUID()
        let provider = FakeSubscriptionProvider()
        let service = SubscriptionService(provider: provider, verifier: FakeSubscriptionVerifier(token: token))

        #expect(try await service.purchase(.yearly) == .purchased)

        #expect(provider.purchaseTokens == [token])
    }

    @Test("Without the account token the store is never asked")
    func purchaseNeedsToken() async {
        let provider = FakeSubscriptionProvider()
        let service = SubscriptionService(
            provider: provider, verifier: FakeSubscriptionVerifier(tokenError: SubscriptionError.accountUnavailable)
        )

        await #expect(throws: SubscriptionError.accountUnavailable) { try await service.purchase(.monthly) }

        #expect(provider.purchases.isEmpty)
        #expect(!service.hasActivePlan)
    }

    @Test("The store's signed transaction goes to the verifier with the state")
    func signedTransactionTravels() async {
        let provider = FakeSubscriptionProvider(state: .active(period: .monthly, expiresAt: nil, willRenew: true))
        provider.signedTransaction = "header.payload.signature"
        let verifier = FakeSubscriptionVerifier()
        let service = SubscriptionService(provider: provider, verifier: verifier)

        await service.refreshState()

        #expect(verifier.signedTransactions == ["header.payload.signature"])
    }

    @Test("Offers come from the store, monthly first; an empty or failing store gives a message")
    func offers() async {
        let provider = FakeSubscriptionProvider()
        let service = SubscriptionService(provider: provider, verifier: FakeSubscriptionVerifier())

        await service.loadOffers()
        #expect(service.offers.map(\.period) == [.monthly, .yearly])
        #expect(service.offer(for: .yearly)?.displayPrice == "€149.99")
        #expect(service.offersErrorMessage == nil)

        provider.offersError = FakeStoreError()
        await service.loadOffers()
        #expect(service.offersErrorMessage != nil)
    }

    @Test("A store update (a refund) arrives through the stream and goes through the verifier")
    func updates() async {
        let provider = FakeSubscriptionProvider(state: .active(period: .monthly, expiresAt: nil, willRenew: true))
        let verifier = FakeSubscriptionVerifier()
        let service = SubscriptionService(provider: provider, verifier: verifier)
        await service.start()
        defer { service.stop() }
        #expect(service.hasActivePlan)

        provider.push(.none)

        #expect(await Wait.untilMain { !service.hasActivePlan })
        #expect(verifier.received.count == 2)
    }

    @Test("Restore reports whether a plan came back")
    func restore() async throws {
        let found = SubscriptionService(
            provider: FakeSubscriptionProvider(restoreOutcome: .purchased), verifier: FakeSubscriptionVerifier()
        )
        #expect(try await found.restorePurchases() == .purchased)
        #expect(found.hasActivePlan)

        let nothing = SubscriptionService(provider: FakeSubscriptionProvider(), verifier: FakeSubscriptionVerifier())
        #expect(try await nothing.restorePurchases() == .nothingToRestore)
        #expect(!nothing.hasActivePlan)
    }
}
