//
//  VisitDetailViewModel+Corrections.swift
//  BelloHub
//

import Foundation

/// Completing or correcting one field of the visit. The rule is `RecordEditRules`: an open record or a draft is
/// edited directly, a locked one gets a logged correction with a reason. The original is never overwritten after the
/// lock.
extension VisitDetailViewModel {
    // MARK: - Draft

    /// Whether saving the draft edits the record (still open) or logs a correction (locked).
    var draftPath: RecordLockPolicy.EditPath {
        record.map { RecordEditRules.path(for: $0, now: now()) } ?? .addCorrection
    }

    /// What the field says now, shown above the box she types in.
    var draftCurrentValue: String? {
        guard let draft, let record else { return nil }
        return RecordEditRules.currentValue(of: draft.field, in: record, corrections: corrections)
    }

    func beginCorrection(field: RecordEditableField = .standard(.notes)) {
        draftProblem = nil
        actionErrorMessage = nil
        draft = RecordCorrectionDraft(recordID: recordID, field: field)
        syncDraftText()
    }

    /// Picking another field starts from what that field says now.
    func selectField(_ field: RecordEditableField) {
        draft?.field = field
        draftProblem = nil
        syncDraftText()
    }

    func cancelCorrection() {
        draft = nil
        draftProblem = nil
    }

    func saveCorrection() {
        Task { await saveCorrectionAsync() }
    }

    func saveCorrectionAsync() async {
        guard !isWorking, let draft, let record, let repository = vault.repository else { return }
        let moment = now()
        if let problem = RecordEditRules.problem(for: draft, record: record, corrections: corrections, now: moment) {
            draftProblem = problem
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            switch RecordEditRules.path(for: record, now: moment) {
            case .editDirectly:
                try await repository.save(draft.field.setting(RecordEditRules.normalized(draft.newValue), in: record))
            case .addCorrection:
                try await repository.addCorrection(RecordEditRules.correction(
                    id: makeID(), draft: draft, record: record, corrections: corrections, now: moment
                ))
            }
            self.draft = nil
            draftProblem = nil
            actionErrorMessage = nil
            await loadAsync()
        } catch {
            failAction()
        }
    }

    func dismissActionError() {
        actionErrorMessage = nil
    }

    private func syncDraftText() {
        // Read first, then write: writing `draft?.newValue` while the getter reads `draft` is an exclusivity conflict.
        let current = draftCurrentValue ?? ""
        draft?.newValue = current
    }
}
