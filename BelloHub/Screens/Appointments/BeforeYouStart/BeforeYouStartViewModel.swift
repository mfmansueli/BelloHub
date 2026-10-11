//
//  BeforeYouStartViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of "Before you start" (3.3): the glance at the client before she begins, built by the same
/// `PreVisitChecklist` as the detail, and "Mark completed" from the sheet.
@MainActor
@Observable
final class BeforeYouStartViewModel {
    let appointmentID: UUID
    private(set) var visit: VisitContext?
    private(set) var checklist: PreVisitChecklist?
    private(set) var business: AgendaBusinessContext
    private(set) var isLoading = true
    private(set) var isMissing = false
    private(set) var errorMessage: String?
    private(set) var actionErrorMessage: String?
    private(set) var isWorking = false
    /// She marked it completed; the sheet closes.
    private(set) var didComplete = false

    private let appointments: AppointmentService
    private let vault: VaultService
    private let profile: ProfileService
    private let catalogProvider: any HealthFormCatalogProviding
    private let now: @Sendable () -> Date

    init(
        appointmentID: UUID, appointments: AppointmentService, vault: VaultService, profile: ProfileService,
        catalogProvider: any HealthFormCatalogProviding = BundleHealthFormCatalogProvider(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.appointmentID = appointmentID
        self.appointments = appointments
        self.vault = vault
        self.profile = profile
        self.catalogProvider = catalogProvider
        self.now = now
        business = AgendaBusinessContext(profile: profile.profile)
    }

    // MARK: - Derived

    var canComplete: Bool {
        guard let appointment = visit?.appointment else { return false }
        return AppointmentActionRules.layout(for: appointment, now: now()).all.contains(.complete)
    }

    // MARK: - Actions

    func load() {
        Task { await loadAsync() }
    }

    func loadAsync() async {
        business = AgendaBusinessContext(profile: profile.profile)
        do {
            guard let loaded = try await VisitReader(appointments: appointments, vault: vault).visit(id: appointmentID)
            else {
                isMissing = true
                isLoading = false
                return
            }
            let reader = PreVisitReader(
                vault: vault, localization: business.localization, catalogProvider: catalogProvider
            )
            checklist = try await reader.checklist(for: loaded, now: now(), calendar: business.calendar)
            visit = loaded
            errorMessage = nil
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = String(interface: LocalizedStringResource("beforeYouStart.error.load"))
        }
    }

    func complete() {
        Task { await completeAsync() }
    }

    func completeAsync() async {
        guard !isWorking, canComplete else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await appointments.complete(id: appointmentID, now: now())
            didComplete = true
            actionErrorMessage = nil
        } catch {
            actionErrorMessage = String(interface: LocalizedStringResource("appointment.error.action"))
        }
    }

    func dismissActionError() {
        actionErrorMessage = nil
    }
}
