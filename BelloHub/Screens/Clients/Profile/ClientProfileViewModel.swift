//
//  ClientProfileViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of one client's profile (4.1): it watches the vault for her client record and her appointments
/// and rebuilds the snapshot (`ClientProfileBuilder`) when either changes, so an edit or a new appointment shows at
/// once. The only action of its own is the call.
@MainActor
@Observable
final class ClientProfileViewModel {
    let clientID: UUID
    private(set) var snapshot: ClientProfileSnapshot?
    private(set) var isLoading = true
    /// She was merged into another profile or deleted while this screen was open.
    private(set) var isMissing = false
    private(set) var errorMessage: String?
    /// The phone could not place the call (an iPhone without a SIM, the simulator): the screen says so.
    private(set) var callFailed = false

    private let vault: VaultService
    private let profile: ProfileService
    private let phone: any PhoneLaunching
    private let now: @Sendable () -> Date
    private let listeners = TaskBag()
    private var isReloading = false
    private var needsReload = false

    init(
        clientID: UUID,
        vault: VaultService,
        profile: ProfileService,
        phone: any PhoneLaunching = PhoneLauncher(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.clientID = clientID
        self.vault = vault
        self.profile = profile
        self.phone = phone
        self.now = now
    }

    // MARK: - Derived

    var tagsByID: [UUID: Tag] {
        Dictionary(profile.tags.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var chips: [ClientProfileChip] {
        snapshot.map { ClientProfileChip.chips(for: $0.client, habits: $0.habits, tagsByID: tagsByID) } ?? []
    }

    /// There is a number to call.
    var canCall: Bool {
        snapshot?.client.phoneE164.flatMap(PhoneLauncher.telURL(forE164:)) != nil
    }

    // MARK: - Listening

    /// Starts watching the vault. Safe to call again: a running watch is kept.
    func startListening() {
        guard listeners.isEmpty else { return }
        guard let repository = vault.repository else { return fail() }
        listeners.add([
            Task { [weak self] in
                await self?.reload()
                for await _ in repository.clients() {
                    guard let self, !Task.isCancelled else { return }
                    await self.reload()
                }
            },
            Task { [weak self] in
                for await _ in repository.appointments(in: DateInterval(start: .distantPast, end: .distantFuture)) {
                    guard let self, !Task.isCancelled else { return }
                    await self.reload()
                }
            }
        ])
    }

    func stopListening() {
        listeners.cancelAll()
        snapshot = nil
        isLoading = true
        isMissing = false
        errorMessage = nil
        callFailed = false
    }

    // MARK: - Actions

    /// Fire-and-forget entry point for the retry button (CLAUDE.md section 2).
    func refresh() {
        Task { await refreshAsync() }
    }

    /// For `.refreshable`.
    func refreshAsync() async {
        await reload()
    }

    func call() {
        Task { await callAsync() }
    }

    func callAsync() async {
        guard let number = snapshot?.client.phoneE164 else { return }
        callFailed = !(await phone.call(number))
    }

    func dismissCallFailure() {
        callFailed = false
    }

    // MARK: - Private

    /// One reload at a time; a change that arrives while one runs asks for exactly one more, so the screen always ends
    /// on the latest state without queueing a reload per emission.
    private func reload() async {
        if isReloading {
            needsReload = true
            return
        }
        isReloading = true
        defer { isReloading = false }
        repeat {
            needsReload = false
            await performReload()
        } while needsReload
    }

    private func performReload() async {
        guard let repository = vault.repository else { return fail() }
        do {
            guard let client = try await repository.client(id: clientID) else {
                snapshot = nil
                isMissing = true
                isLoading = false
                return
            }
            let input = ClientProfileBuilder.Input(
                client: client,
                appointments: try await repository.appointments(for: clientID),
                plans: try await repository.sessionPlans(for: clientID),
                forms: try await repository.healthForms(for: clientID),
                consents: try await repository.consents(for: clientID)
            )
            snapshot = ClientProfileBuilder.make(input, now: now(), calendar: calendar)
            isMissing = false
            errorMessage = nil
            isLoading = false
        } catch {
            fail()
        }
    }

    private func fail() {
        isLoading = false
        errorMessage = String(interface: LocalizedStringResource("clientProfile.error.message"))
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = profile.profile.flatMap { TimeZone(identifier: $0.timeZoneID) } ?? .current
        return calendar
    }
}
