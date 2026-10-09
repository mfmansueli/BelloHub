//
//  PatchTestViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// The "Record patch test" sheet: what was tried, where, for how long the skin was watched and what happened.
@MainActor
@Observable
final class PatchTestViewModel: Identifiable {
    let id = UUID()
    var draft: PatchTestDraft
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    private(set) var didSave = false

    private let clientID: UUID
    private let repository: any HealthRepository
    /// Made once, so saving again after a failure updates the same entry instead of adding a second one.
    private let patchTestID: UUID

    init(
        clientID: UUID,
        repository: any HealthRepository,
        now: @Sendable () -> Date = { Date() },
        makeID: @Sendable () -> UUID = { UUID() }
    ) {
        self.clientID = clientID
        self.repository = repository
        self.draft = PatchTestDraft(testedAt: now())
        self.patchTestID = makeID()
    }

    var canSave: Bool { !isSaving && PatchTestRules.canSave(draft) }

    /// Fire-and-forget entry point for the button; `saveAsync()` is what tests await.
    func save() {
        Task { await saveAsync() }
    }

    func saveAsync() async {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await repository.save(PatchTestRules.patchTest(from: draft, clientID: clientID, id: patchTestID))
            didSave = true
        } catch {
            errorMessage = String(localized: "health.error.save")
        }
    }
}
