//
//  NoShowHistoryViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of a client's no-show history (4.11): her count under the rule, the lines that make it up,
/// forgiving a miss (D13) and starting her count from zero, which also lets her book online again. History is never
/// deleted.
@MainActor
@Observable
final class NoShowHistoryViewModel {
    let clientID: UUID
    private(set) var client: Client?
    private(set) var status: NoShowStatus?
    private(set) var entries: [NoShowHistoryEntry] = []
    private(set) var policy: NoShowPolicy = .standard
    private(set) var business: AgendaBusinessContext
    private(set) var isLoading = true
    private(set) var isMissing = false
    private(set) var errorMessage: String?
    private(set) var actionErrorMessage: String?
    private(set) var isWorking = false
    /// Her count was just started from zero (the screen says so).
    private(set) var didReset = false

    private let vault: VaultService
    private let appointments: AppointmentService
    private let profile: ProfileService
    private let setup: BookingSetupService
    private let now: @Sendable () -> Date

    init(
        clientID: UUID, vault: VaultService, appointments: AppointmentService, profile: ProfileService,
        setup: BookingSetupService, now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.clientID = clientID
        self.vault = vault
        self.appointments = appointments
        self.profile = profile
        self.setup = setup
        self.now = now
        business = AgendaBusinessContext(profile: profile.profile)
    }

    // MARK: - Derived

    /// "Allow online booking again" is offered when the limit has been reached or booking is stopped for her.
    var offersReset: Bool {
        guard let client, let status else { return false }
        return status.limitReached || client.onlineBookingStopped
    }

    // MARK: - Actions

    func load() {
        Task { await loadAsync() }
    }

    func loadAsync() async {
        business = AgendaBusinessContext(profile: profile.profile)
        guard let repository = vault.repository else {
            isLoading = false
            errorMessage = String(interface: LocalizedStringResource("noShowHistory.error.load"))
            return
        }
        do {
            guard let loaded = try await repository.client(id: clientID) else {
                isMissing = true
                isLoading = false
                return
            }
            if !setup.hasLoaded { try? await setup.load(timeZoneID: business.timeZone.identifier) }
            let history = try await appointments.appointments(for: clientID)
            apply(client: loaded, history: history)
            errorMessage = nil
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = String(interface: LocalizedStringResource("noShowHistory.error.load"))
        }
    }

    /// Forgives one missed visit: it stays in the history and stops counting.
    func forgive(_ entry: NoShowHistoryEntry) {
        Task { await forgiveAsync(entry) }
    }

    func forgiveAsync(_ entry: NoShowHistoryEntry) async {
        guard !isWorking, entry.canForgive else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await appointments.markNoShow(id: entry.id, forgive: true, now: now())
            didReset = false
            await loadAsync()
            actionErrorMessage = nil
        } catch {
            actionErrorMessage = String(interface: LocalizedStringResource("noShowHistory.error.save"))
        }
    }

    /// Starts her count from zero and opens online booking for her again. The history stays.
    func resetCount() {
        Task { await resetCountAsync() }
    }

    func resetCountAsync() async {
        guard !isWorking, var updated = client, let repository = vault.repository else { return }
        isWorking = true
        defer { isWorking = false }
        updated.noShowCountResetAt = now()
        updated.onlineBookingStopped = false
        updated.stopReason = nil
        do {
            try await repository.save(updated)
            didReset = true
            await loadAsync()
            actionErrorMessage = nil
        } catch {
            actionErrorMessage = String(interface: LocalizedStringResource("noShowHistory.error.save"))
        }
    }

    func dismissActionError() {
        actionErrorMessage = nil
    }

    // MARK: - Private

    private func apply(client loaded: Client, history: [Appointment]) {
        client = loaded
        policy = setup.setup.noShow
        let current = now()
        let calendar = business.calendar
        status = NoShowEvaluator.status(
            policy: policy, client: loaded, appointments: history, now: current, calendar: calendar
        )
        entries = NoShowHistoryBuilder.entries(
            policy: policy, client: loaded, appointments: history, now: current, calendar: calendar
        )
    }
}
