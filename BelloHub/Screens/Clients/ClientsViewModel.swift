//
//  ClientsViewModel.swift
//  BelloHub
//

import Foundation
import Observation
import os

/// State and actions of the Clients list: it watches the vault, builds the entries once per change
/// (`ClientListBuilder`, off the main actor) and narrows them by the chip and the search (`ClientListFilter`,
/// `ClientSearch`). Views read `visible`; nothing recomputes while she scrolls or types in an unrelated field.
@MainActor
@Observable
final class ClientsViewModel {
    private(set) var list = ClientList.empty
    /// The entries the screen shows: `list` narrowed by `filter` and `searchText`, in reading order.
    private(set) var visible: [ClientListEntry] = []
    private(set) var isLoading = true
    private(set) var errorMessage: String?
    private(set) var filter = ClientListFilter.all
    private(set) var searchText = ""

    private let vault: VaultService
    private let profile: ProfileService
    private let now: @Sendable () -> Date
    private var clients: [Client] = []
    private var appointments: [Appointment] = []
    private var services: [Service] = []
    private var hasClients = false
    private var hasAppointments = false
    private let listeners = TaskBag()
    /// Counts the builds started, so a slow one that finishes late never overwrites a newer one.
    private var buildGeneration = 0

    init(vault: VaultService, profile: ProfileService, now: @escaping @Sendable () -> Date = { Date() }) {
        self.vault = vault
        self.profile = profile
        self.now = now
    }

    // MARK: - Derived

    /// The chips, in the order they are shown.
    var chips: [ClientListFilter] {
        ClientListFilter.chips(tags: profile.tags, hasArchived: list.hasArchived)
    }

    /// The tags by id, for the row badges.
    var tagsByID: [UUID: Tag] {
        Dictionary(profile.tags.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// How many people the screen shows under the chips ("12 clients").
    var count: Int { visible.count }

    /// Nobody is registered at all (archived clients count): the screen invites her to add the first one.
    var isEmpty: Bool { list.entries.isEmpty }

    /// Someone is registered, but the chip and the search leave no one.
    var hasNoMatches: Bool { !list.entries.isEmpty && visible.isEmpty }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// The "haven't been back" strip, only while the plain list shows (a search or a chip is a narrower question).
    var winBackCount: Int { filter == .all && !isSearching ? list.winBack.count : 0 }

    // MARK: - Query

    func select(_ filter: ClientListFilter) {
        guard filter != self.filter else { return }
        self.filter = filter
        applyQuery()
    }

    func setSearchText(_ text: String) {
        guard text != searchText else { return }
        searchText = text
        applyQuery()
    }

    /// The chip list changed under the filter (a tag was deleted or renamed): fall back to everyone if its chip is
    /// gone, and narrow again.
    func tagsChanged() {
        if !chips.contains(filter) { filter = .all }
        applyQuery()
    }

    // MARK: - Listening

    /// Starts watching the vault. Safe to call again: a running watch is kept.
    func startListening() {
        guard listeners.isEmpty else { return }
        guard let repository = vault.repository else { return fail() }
        listeners.add([
            Task { [weak self] in
                await self?.refreshAsync()
                for await clients in repository.clients() {
                    guard let self, !Task.isCancelled else { return }
                    self.clients = clients
                    self.hasClients = true
                    await self.rebuild(reloadingServices: true)
                }
            },
            Task { [weak self] in
                for await appointments in repository.appointments(in: Self.everything) {
                    guard let self, !Task.isCancelled else { return }
                    self.appointments = appointments
                    self.hasAppointments = true
                    await self.rebuild(reloadingServices: false)
                }
            }
        ])
    }

    /// Stops watching and forgets what was loaded, so a sign-out leaves nothing behind.
    func stopListening() {
        listeners.cancelAll()
        clients = []
        appointments = []
        services = []
        hasClients = false
        hasAppointments = false
        buildGeneration += 1
        list = .empty
        visible = []
        isLoading = true
        errorMessage = nil
        filter = .all
        searchText = ""
    }

    // MARK: - Refresh

    /// Fire-and-forget entry point for the retry button (CLAUDE.md section 2).
    func refresh() {
        Task { await refreshAsync() }
    }

    /// Reads the vault again and says so when it cannot: the watch swallows read errors (a locked vault would look like
    /// an empty list), so this is where "could not load" comes from. For `.refreshable` and the first load.
    func refreshAsync() async {
        guard let repository = vault.repository else { return fail() }
        do {
            clients = try await repository.allClients()
            appointments = try await repository.loadAppointments(in: Self.everything)
            services = try await repository.services()
            hasClients = true
            hasAppointments = true
            await rebuild(reloadingServices: false)
        } catch {
            fail()
        }
    }

    // MARK: - Private

    private static let everything = DateInterval(start: .distantPast, end: .distantFuture)

    private func fail() {
        isLoading = false
        errorMessage = String(interface: LocalizedStringResource("clients.error.message"))
    }

    private func rebuild(reloadingServices: Bool) async {
        if reloadingServices, let repository = vault.repository, let loaded = try? await repository.services() {
            services = loaded
        }
        // Wait for both first answers: a list built from clients alone would flash "New" on every client.
        guard hasClients, hasAppointments else { return }
        buildGeneration += 1
        let generation = buildGeneration
        let (currentClients, currentAppointments, currentServices) = (clients, appointments, services)
        let (moment, businessCalendar) = (now(), calendar)
        let built = await Task.detached(priority: .userInitiated) {
            ClientListBuilder.build(
                clients: currentClients, appointments: currentAppointments, services: currentServices,
                now: moment, calendar: businessCalendar
            )
        }.value
        guard generation == buildGeneration else { return }
        list = built
        isLoading = false
        errorMessage = nil
        if !chips.contains(filter) { filter = .all }
        applyQuery()
    }

    private func applyQuery() {
        visible = PerformanceSignposts.signposter.withIntervalSignpost(PerformanceSignposts.clientSearch) {
            ClientSearch.filter(filter.apply(to: list.entries), query: searchText, tags: profile.tags)
        }
    }

    /// The business time zone decides what "a month ago" and "this afternoon" mean (docs/07 section 2.4).
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = profile.profile.flatMap { TimeZone(identifier: $0.timeZoneID) } ?? .current
        return calendar
    }
}
