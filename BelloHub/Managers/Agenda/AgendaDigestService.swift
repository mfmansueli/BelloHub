//
//  AgendaDigestService.swift
//  BelloHub
//

import Foundation
import Observation

/// What Home, Alerts, Follow-ups and Win back all read: her visits (every one, so "the last visit" of a client is
/// known), her clients, her services and the blocks of the coming days, kept up to date by one observation of the vault
/// (`startListening` / `stopListening`). The rules that turn this into lists (`AgendaDigest`) are pure and live in the
/// screens' support folder; this class only holds the data and says whether it has arrived.
///
/// Read with `@Environment(AgendaDigestService.self)`. It stops and forgets everything when the app locks or she signs
/// out, so no client data stays in memory.
@MainActor
@Observable
final class AgendaDigestService {
    private(set) var appointments: [Appointment] = []
    private(set) var clients: [Client] = []
    private(set) var services: [Service] = []
    private(set) var blocks: [TimeBlock] = []
    /// True until the visits have arrived once.
    private(set) var isLoading = true
    private(set) var errorMessage: String?

    private let appointmentService: AppointmentService
    private let timeBlocks: TimeBlockService
    private let vault: VaultService
    private let now: @Sendable () -> Date
    private let listeners = TaskBag()
    private var isListening = false

    init(
        appointments: AppointmentService, timeBlocks: TimeBlockService, vault: VaultService,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        appointmentService = appointments
        self.timeBlocks = timeBlocks
        self.vault = vault
        self.now = now
    }

    // MARK: - Listening

    /// Starts watching the vault. Safe to call again (a screen appearing, a retry): it only starts what is not running.
    func startListening() {
        guard !isListening else { return }
        guard vault.isAvailable, let repository = vault.repository else {
            errorMessage = String(
                localized: "calendar.error.unavailable",
                defaultValue: "Your calendar is not available. Check that your iPhone is unlocked and try again."
            )
            isLoading = false
            return
        }
        isListening = true
        errorMessage = nil
        let moment = now()
        // Every visit ever made through a year ahead: the follow-up rules need each client's last completed visit.
        let history = DateInterval(start: Date(timeIntervalSince1970: 0), end: moment.addingTimeInterval(366 * 86_400))
        let nearby = DateInterval(start: moment.addingTimeInterval(-86_400), end: moment.addingTimeInterval(9 * 86_400))
        let visits = appointmentService.stream(in: history)
        let closed = timeBlocks.stream(in: nearby)
        let people = repository.clients()
        listeners.add([
            Task { [weak self] in
                for await list in visits {
                    guard let self, !Task.isCancelled else { return }
                    appointments = list
                    isLoading = false
                }
            },
            Task { [weak self] in
                for await list in closed {
                    guard let self, !Task.isCancelled else { return }
                    blocks = list
                }
            },
            Task { [weak self] in
                for await list in people {
                    guard let self, !Task.isCancelled else { return }
                    clients = list
                }
            },
            Task { [weak self] in
                await self?.loadServices()
            }
        ])
    }

    /// Stops watching and forgets what was loaded.
    func stopListening() {
        listeners.cancelAll()
        isListening = false
        appointments = []
        clients = []
        services = []
        blocks = []
        isLoading = true
        errorMessage = nil
    }

    /// Reads the services again and restarts the observation if it stopped (pull to refresh, "Try again").
    func refresh() async {
        if !isListening { startListening() }
        await loadServices()
    }

    // MARK: - Private

    private func loadServices() async {
        guard let repository = vault.repository else { return }
        if let list = try? await repository.services() { services = list }
    }
}
