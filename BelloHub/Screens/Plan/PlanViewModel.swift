//
//  PlanViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of Plan (7.3) and of the paywall (the same screen opened as a sheet, ASSUMPTION-20): the
/// period she picked, purchase, restore and manage, with the store's answers turned into a notice.
@MainActor
@Observable
final class PlanViewModel {
    enum Mode: Equatable, Sendable {
        /// From More: her plan.
        case plan
        /// From the registration gate (D42): the free registrations are used.
        case paywall
    }

    enum Notice: Equatable, Sendable {
        case purchased
        case restored
        case nothingToRestore
        case pending
        case failed
    }

    let mode: Mode
    var choice: PlanPeriod
    private(set) var isBusy = false
    private(set) var notice: Notice?

    private let subscription: SubscriptionService

    init(subscription: SubscriptionService, mode: Mode) {
        self.subscription = subscription
        self.mode = mode
        choice = PlanPresentation(offers: subscription.offers, state: subscription.state).defaultChoice
    }

    // MARK: - Reading

    var presentation: PlanPresentation {
        PlanPresentation(offers: subscription.offers, state: subscription.state)
    }

    var state: SubscriptionState { subscription.state }
    var offers: [PlanOffer] { subscription.offers }
    var isLoadingOffers: Bool { subscription.isLoadingOffers }
    var offersErrorMessage: String? { subscription.offersErrorMessage }
    var chosenOffer: PlanOffer? { subscription.offer(for: choice) }
    var canBuy: Bool { chosenOffer != nil && !isBusy && !state.hasActivePlan }

    // MARK: - Loading

    func load() async {
        await subscription.loadOffers()
        if !subscription.offers.isEmpty, subscription.offer(for: choice) == nil {
            choice = presentation.defaultChoice
        }
    }

    func retry() {
        Task { await load() }
    }

    // MARK: - Actions

    func buy() {
        Task { await buyAsync() }
    }

    func buyAsync() async {
        guard canBuy else { return }
        await run {
            switch try await subscription.purchase(choice) {
            case .purchased: .purchased
            case .pending: .pending
            case .cancelled: nil
            case .nothingToRestore: nil
            }
        }
    }

    func restore() {
        Task { await restoreAsync() }
    }

    func restoreAsync() async {
        await run {
            switch try await subscription.restorePurchases() {
            case .purchased: .restored
            case .nothingToRestore: .nothingToRestore
            case .pending: .pending
            case .cancelled: nil
            }
        }
    }

    func manage() {
        Task { await subscription.manageSubscription() }
    }

    func dismissNotice() {
        notice = nil
    }

    // MARK: - Private

    private func run(_ action: () async throws -> Notice?) async {
        guard !isBusy else { return }
        isBusy = true
        notice = nil
        defer { isBusy = false }
        do {
            notice = try await action()
        } catch {
            notice = .failed
        }
    }
}
