//
//  BeforeYouStartViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of "Before you start" (3.3): the glance at the client before she begins, built by the same
/// `PreVisitChecklist` and `AppointmentRecords` as the detail, and "Mark completed" from the sheet. It only shows what
/// is written in her records; nothing is inferred.
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
    /// She marked it completed; the sheet closes, unless it first asks whether to register the visit.
    private(set) var didComplete = false
    /// This appointment's record and the client's previous visit.
    private(set) var records = AppointmentRecords.empty
    /// Completed with no record yet: "Register now" or "Later".
    var offersToRegister = false
    private var thumbnails: [UUID: Data] = [:]

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

    /// The visit form for this appointment; it reopens the linked record when there is one, never a second record.
    var visitFlowRequest: TreatmentFlowRequest? {
        visit.map {
            TreatmentFlowRequest(clientID: $0.client.id, appointmentID: $0.appointment.id,
                                 serviceID: $0.appointment.serviceID, recordID: records.record?.id)
        }
    }

    func thumbnail(for photo: Photo) async -> Data? {
        if let cached = thumbnails[photo.id] { return cached }
        guard let repository = vault.repository,
              let data = try? await repository.photoThumbnail(id: photo.id) else { return nil }
        thumbnails[photo.id] = data
        return data
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
            if let repository = vault.repository {
                records = try await AppointmentRecordsReader(repository: repository).records(
                    for: loaded, appointments: try await repository.appointments(for: loaded.client.id), now: now(),
                    list: business.formatters(displayLocale: InterfaceLocale.current).list
                )
            }
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
            actionErrorMessage = nil
            // Completing the booking never finalizes a record; with none written yet she chooses now or later.
            if records.record == nil {
                offersToRegister = true
            } else {
                didComplete = true
            }
        } catch {
            actionErrorMessage = String(interface: LocalizedStringResource("appointment.error.action"))
        }
    }

    /// The register question was answered (or the visit form closed): the sheet can close.
    func finishAfterCompleting() {
        offersToRegister = false
        didComplete = true
    }

    func dismissActionError() {
        actionErrorMessage = nil
    }
}
