//
//  PlanViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("PlanViewModel")
struct PlanViewModelTests {
    private func makeViewModel(
        provider: FakeSubscriptionProvider = FakeSubscriptionProvider(), mode: PlanViewModel.Mode = .plan
    ) async -> (PlanViewModel, SubscriptionService) {
        let service = makeSubscriptionService(provider: provider)
        await service.refreshState()
        let viewModel = PlanViewModel(subscription: service, mode: mode)
        await viewModel.load()
        return (viewModel, service)
    }

    @Test("Loading lists both offers and starts on the highlighted yearly plan")
    func load() async {
        let (viewModel, _) = await makeViewModel()

        #expect(viewModel.offers.count == 2)
        #expect(viewModel.choice == .yearly)
        #expect(viewModel.presentation.savingsPercent == 17)
        #expect(viewModel.chosenOffer?.displayPrice == "€149.99")
        #expect(viewModel.canBuy)
    }

    @Test("Buying the chosen period activates the plan and shows the notice")
    func buy() async {
        let provider = FakeSubscriptionProvider()
        let (viewModel, service) = await makeViewModel(provider: provider)
        viewModel.choose(.monthly)

        await viewModel.buyAsync()

        #expect(provider.purchases == [.monthly])
        #expect(service.hasActivePlan)
        #expect(viewModel.notice == .purchased)
        #expect(!viewModel.canBuy, "an active plan is not bought twice")
    }

    @Test("A cancelled sheet shows nothing; a pending purchase and a store failure explain themselves")
    func outcomes() async {
        let (cancelled, _) = await makeViewModel(provider: FakeSubscriptionProvider(purchaseOutcome: .cancelled))
        await cancelled.buyAsync()
        #expect(cancelled.notice == nil)

        let (pending, _) = await makeViewModel(provider: FakeSubscriptionProvider(purchaseOutcome: .pending))
        await pending.buyAsync()
        #expect(pending.notice == .pending)

        let failing = FakeSubscriptionProvider()
        failing.purchaseError = FakeStoreError()
        let (failed, _) = await makeViewModel(provider: failing)
        await failed.buyAsync()
        #expect(failed.notice == .failed)
    }

    @Test("Restore reports a plan that came back or nothing to restore")
    func restore() async {
        let (found, _) = await makeViewModel(provider: FakeSubscriptionProvider(restoreOutcome: .purchased))
        await found.restoreAsync()
        #expect(found.notice == .restored)

        let (nothing, _) = await makeViewModel()
        await nothing.restoreAsync()
        #expect(nothing.notice == .nothingToRestore)
    }

    @Test("The paywall mode is the same screen with the gate's headline; a failing store gives a retry message")
    func paywallAndErrors() async {
        let failing = FakeSubscriptionProvider()
        failing.offersError = FakeStoreError()
        let (viewModel, _) = await makeViewModel(provider: failing, mode: .paywall)

        #expect(viewModel.mode == .paywall)
        #expect(viewModel.offers.isEmpty)
        #expect(viewModel.offersErrorMessage != nil)
        #expect(!viewModel.canBuy)

        failing.offersError = nil
        await viewModel.load()
        #expect(viewModel.offersErrorMessage == nil)
        #expect(viewModel.canBuy)
    }

    @Test("Manage opens the store's sheet")
    func manage() async {
        let provider = FakeSubscriptionProvider(state: .active(period: .monthly, expiresAt: nil, willRenew: true))
        let (viewModel, _) = await makeViewModel(provider: provider)

        viewModel.manage()

        #expect(await Wait.until { provider.manageCount == 1 })
    }
}
