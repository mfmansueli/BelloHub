//
//  PlanViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of Plan (7.3) and of the paywall (the same screen opened as a sheet, ASSUMPTION-20): the
/// period she picked, purchase, restore and manage, with the store's answers turned into a notice, and the Terms and the
/// Privacy Policy to read before buying (App Review 3.1.2).
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
    private(set) var choice: PlanPeriod
    /// She tapped a card: the store's later answer must not move her choice.
    private var hasChosen = false
    private(set) var isBusy = false
    private(set) var notice: Notice?
    private(set) var openedNotice: LegalNoticeText?
    private(set) var legalErrorMessage: String?

    private let subscription: SubscriptionService
    private let legal: any LegalNoticeLibrary
    private let localization: AppLocalization

    init(
        subscription: SubscriptionService, mode: Mode, legal: any LegalNoticeLibrary = BundleLegalNoticeLibrary(),
        localization: AppLocalization = InterfaceLocale.localization
    ) {
        self.subscription = subscription
        self.mode = mode
        self.legal = legal
        self.localization = localization
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
        if !subscription.offers.isEmpty, !hasChosen || subscription.offer(for: choice) == nil {
            choice = presentation.defaultChoice
        }
    }

    func retry() {
        Task { await load() }
    }

    // MARK: - Actions

    func choose(_ period: PlanPeriod) {
        choice = period
        hasChosen = true
    }

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

    // MARK: - Legal

    /// The bundled Terms or Privacy Policy in her language, in a sheet.
    func open(_ legalNotice: LegalNotice) {
        do {
            openedNotice = try legal.latest(legalNotice, localization: localization)
            legalErrorMessage = nil
        } catch {
            legalErrorMessage = String(interface: LocalizedStringResource(
                "privacy.legal.error", defaultValue: "This text could not be opened right now."
            ))
        }
    }

    func closeLegalNotice() {
        openedNotice = nil
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
