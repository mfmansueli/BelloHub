//
//  IncidentViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of 4.9 Incident: a clear, neutral note of a reaction, saved to the client's record in the
/// vault. It locks like a record 24 hours after it is made. Nothing leaves the phone.
@MainActor
@Observable
final class IncidentViewModel {
    enum Phase: Equatable {
        case loading
        case missing
        case failed(String)
        case form
        case saved
    }

    let clientID: UUID
    private(set) var phase: Phase = .loading
    private(set) var client: Client?
    /// The visits she can tie the note to, newest first.
    private(set) var visits: [TreatmentRecord] = []
    var draft = IncidentDraft()
    private(set) var isWorking = false
    private(set) var saveErrorMessage: String?

    private let appointmentID: UUID?
    /// The visit she came from, when she opened the note from a visit's details.
    private let recordID: UUID?
    private let vault: VaultService
    private let now: @Sendable () -> Date
    private let makeID: @Sendable () -> UUID
    private let resolve: (LocalizedStringResource) -> String

    init(
        clientID: UUID, appointmentID: UUID?, recordID: UUID? = nil, vault: VaultService,
        now: @escaping @Sendable () -> Date = { Date() },
        makeID: @escaping @Sendable () -> UUID = { UUID() },
        resolve: @escaping (LocalizedStringResource) -> String = { String(interface: $0) }
    ) {
        self.clientID = clientID
        self.appointmentID = appointmentID
        self.recordID = recordID
        self.vault = vault
        self.now = now
        self.makeID = makeID
        self.resolve = resolve
    }

    // MARK: - Derived

    var canSave: Bool { IncidentRules.canSave(draft) && !isWorking }

    // MARK: - Actions

    func load() {
        Task { await loadAsync() }
    }

    func loadAsync() async {
        guard let repository = vault.repository else {
            phase = .failed(String(interface: LocalizedStringResource("incident.error.load")))
            return
        }
        do {
            guard let loaded = try await repository.client(id: clientID) else {
                phase = .missing
                return
            }
            client = loaded
            visits = try await repository.records(for: clientID)
                .sorted { ($0.performedAt ?? $0.createdAt) > ($1.performedAt ?? $1.createdAt) }
            if phase == .loading || isFailure {
                // The visit she came from is already chosen; she can change it or clear it.
                draft.recordID = visits.first { $0.id == recordID }?.id
                    ?? visits.first { appointmentID != nil && $0.appointmentID == appointmentID }?.id
                phase = .form
            }
        } catch {
            phase = .failed(String(interface: LocalizedStringResource("incident.error.load")))
        }
    }

    func toggle(_ symptom: IncidentSymptom) {
        if draft.symptoms.contains(symptom) { draft.symptoms.remove(symptom) } else { draft.symptoms.insert(symptom) }
    }

    func toggle(_ action: IncidentAction) {
        if draft.actions.contains(action) { draft.actions.remove(action) } else { draft.actions.insert(action) }
    }

    func save() {
        Task { await saveAsync() }
    }

    func saveAsync() async {
        guard canSave, let repository = vault.repository else { return }
        isWorking = true
        defer { isWorking = false }
        let incident = IncidentRules.incident(
            from: draft, clientID: clientID, id: makeID(), now: now(), resolve: resolve
        )
        do {
            try await repository.save(incident)
            saveErrorMessage = nil
            phase = .saved
        } catch {
            saveErrorMessage = String(interface: LocalizedStringResource("incident.error.save"))
        }
    }

    func dismissSaveError() {
        saveErrorMessage = nil
    }

    // MARK: - Private

    private var isFailure: Bool {
        if case .failed = phase { return true }
        return false
    }
}
