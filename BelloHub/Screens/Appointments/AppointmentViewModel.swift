//
//  AppointmentViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of the visit's detail (3.2). It watches the calendar for this visit and rebuilds the screen when
/// it changes (a sheet cancelled it, the client confirmed), and reads what the vault says about the client for the
/// checklist. Every change goes through `AppointmentService`; "Mark completed" is the only one it makes itself, the
/// others open their sheets.
@MainActor
@Observable
final class AppointmentViewModel {
    let appointmentID: UUID
    private(set) var visit: VisitContext?
    private(set) var checklist: PreVisitChecklist?
    /// What counts against the client now, for the no-show history row; nil until the policy is read.
    private(set) var noShow: NoShowStatus?
    private(set) var business: AgendaBusinessContext
    private(set) var isLoading = true
    /// The visit, or its client, no longer exists.
    private(set) var isMissing = false
    private(set) var errorMessage: String?
    /// A change could not be saved; the screen says so and the visit is as it was.
    private(set) var actionErrorMessage: String?
    private(set) var isWorking = false

    private let appointments: AppointmentService
    private let vault: VaultService
    private let profile: ProfileService
    private let setup: BookingSetupService
    private let catalogProvider: any HealthFormCatalogProviding
    let now: @Sendable () -> Date
    private let listener = TaskBag()
    private var isReloading = false
    private var needsReload = false

    init(
        appointmentID: UUID, appointments: AppointmentService, vault: VaultService, profile: ProfileService,
        setup: BookingSetupService, catalogProvider: any HealthFormCatalogProviding = BundleHealthFormCatalogProvider(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.appointmentID = appointmentID
        self.appointments = appointments
        self.vault = vault
        self.profile = profile
        self.setup = setup
        self.catalogProvider = catalogProvider
        self.now = now
        business = AgendaBusinessContext(profile: profile.profile)
    }

    // MARK: - Derived

    var layout: AppointmentActionLayout? {
        visit.map { AppointmentActionRules.layout(for: $0.appointment, now: now()) }
    }

    var reminder: AppointmentReminder {
        visit.map { AppointmentReminder.make(for: $0.appointment) } ?? .notSent
    }

    /// The history row is worth showing: she missed this one, or the client has something counting.
    var showsNoShowHistory: Bool {
        guard let visit else { return false }
        return visit.appointment.status == .noShow || (noShow?.counted ?? 0) > 0
    }

    // MARK: - Listening

    /// Starts watching the calendar. Safe to call again: a running watch is kept.
    func startListening() {
        guard listener.isEmpty else { return }
        listener.add([Task { [weak self, appointments] in
            await self?.reload()
            for await _ in appointments.stream(in: DateInterval(start: .distantPast, end: .distantFuture)) {
                guard let self, !Task.isCancelled else { return }
                await self.reload()
            }
        }])
    }

    func stopListening() {
        listener.cancelAll()
        visit = nil
        checklist = nil
        noShow = nil
        isLoading = true
        isMissing = false
        errorMessage = nil
        actionErrorMessage = nil
    }

    // MARK: - Actions

    /// Fire-and-forget entry point for the retry button.
    func refresh() {
        Task { await refreshAsync() }
    }

    /// For `.refreshable`.
    func refreshAsync() async {
        await reload()
    }

    func complete() {
        Task { await completeAsync() }
    }

    func completeAsync() async {
        guard !isWorking, let visit, AppointmentActionRules.layout(for: visit.appointment, now: now()).all
            .contains(.complete) else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let changed = try await appointments.complete(id: appointmentID, now: now())
            self.visit = VisitContext(appointment: changed, client: visit.client)
            actionErrorMessage = nil
        } catch {
            actionErrorMessage = String(localized: "appointment.error.action")
        }
    }

    func dismissActionError() {
        actionErrorMessage = nil
    }

    // MARK: - Private

    /// One reload at a time; a change that arrives while one runs asks for exactly one more.
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
        business = AgendaBusinessContext(profile: profile.profile)
        let reader = VisitReader(appointments: appointments, vault: vault)
        do {
            guard let loaded = try await reader.visit(id: appointmentID) else {
                visit = nil
                isMissing = true
                isLoading = false
                return
            }
            if !setup.hasLoaded { try? await setup.load(timeZoneID: business.timeZone.identifier) }
            let preVisit = PreVisitReader(
                vault: vault, localization: business.localization, catalogProvider: catalogProvider
            )
            let current = now()
            checklist = try await preVisit.checklist(for: loaded, now: current, calendar: business.calendar)
            let history = try await reader.history(of: loaded.client.id)
            noShow = NoShowEvaluator.status(
                policy: setup.setup.noShow, client: loaded.client, appointments: history, now: current,
                calendar: business.calendar
            )
            visit = loaded
            isMissing = false
            errorMessage = nil
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = String(localized: "appointment.error.load")
        }
    }
}
