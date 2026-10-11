//
//  SessionPlanViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of a client's session plan (4.8): the plan in progress (or a new one), its form and the timeline
/// the numbers produce. The timeline reads the client's completed visits, so changing the number of sessions or the
/// weeks between them moves the dates at once.
@MainActor
@Observable
final class SessionPlanViewModel {
    let clientID: UUID
    private(set) var client: Client?
    /// The stored plan being edited; nil while she writes a new one.
    private(set) var existing: SessionPlan?
    private(set) var appointments: [Appointment] = []
    private(set) var business: AgendaBusinessContext
    private(set) var isLoading = true
    private(set) var isMissing = false
    private(set) var errorMessage: String?
    private(set) var saveErrorMessage: String?
    private(set) var isSaving = false
    /// The last save worked; the screen says "Saved" until she edits again.
    private(set) var didSave = false
    var draft = SessionPlanDraft() {
        didSet { if draft != oldValue { didSave = false } }
    }

    private let vault: VaultService
    private let appointmentService: AppointmentService
    private let profile: ProfileService
    private let now: @Sendable () -> Date
    private let makeID: @Sendable () -> UUID

    init(
        clientID: UUID, vault: VaultService, appointments: AppointmentService, profile: ProfileService,
        now: @escaping @Sendable () -> Date = { Date() }, makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.clientID = clientID
        self.vault = vault
        appointmentService = appointments
        self.profile = profile
        self.now = now
        self.makeID = makeID
        business = AgendaBusinessContext(profile: profile.profile)
    }

    // MARK: - Derived

    var canSave: Bool {
        !isSaving && SessionPlanRules.canSave(draft)
    }

    var timeline: SessionPlanProgress {
        SessionPlanRules.timeline(
            for: draft, existing: existing, appointments: appointments, now: now(), calendar: business.calendar
        )
    }

    /// The plan has all its sessions: the screen offers to start a new one.
    var isFinished: Bool {
        existing != nil && timeline.isFinished
    }

    // MARK: - Actions

    func load() {
        Task { await loadAsync() }
    }

    func loadAsync() async {
        business = AgendaBusinessContext(profile: profile.profile)
        guard let repository = vault.repository else {
            isLoading = false
            errorMessage = String(interface: LocalizedStringResource("sessionPlan.error.load"))
            return
        }
        do {
            guard let loaded = try await repository.client(id: clientID) else {
                isMissing = true
                isLoading = false
                return
            }
            let plans = try await repository.sessionPlans(for: clientID)
            appointments = try await appointmentService.appointments(for: clientID)
            client = loaded
            existing = SessionPlanRules.openingPlan(
                plans: plans, appointments: appointments, calendar: business.calendar
            )
            draft = existing.map(SessionPlanDraft.init(plan:)) ?? SessionPlanDraft()
            didSave = false
            errorMessage = nil
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = String(interface: LocalizedStringResource("sessionPlan.error.load"))
        }
    }

    func save() {
        Task { await saveAsync() }
    }

    func saveAsync() async {
        guard canSave, let repository = vault.repository else { return }
        isSaving = true
        defer { isSaving = false }
        let plan = SessionPlanRules.plan(from: draft, clientID: clientID, existing: existing, now: now(), id: makeID())
        do {
            try await repository.save(plan)
            existing = plan
            didSave = true
            saveErrorMessage = nil
        } catch {
            saveErrorMessage = String(interface: LocalizedStringResource("sessionPlan.error.save"))
        }
    }

    /// Leaves the finished plan alone and starts a blank one.
    func startNewPlan() {
        existing = nil
        draft = SessionPlanDraft()
        didSave = false
    }

    func dismissSaveError() {
        saveErrorMessage = nil
    }
}
