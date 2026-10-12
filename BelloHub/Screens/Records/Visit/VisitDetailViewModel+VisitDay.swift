//
//  VisitDetailViewModel+VisitDay.swift
//  BelloHub
//

import Foundation

/// Setting the day the treatment happened. On an open record or a draft it is stored on the record; on a locked one
/// it is a logged correction with a reason, like any other field. An old record with no visit day keeps none until
/// she sets one: nothing is guessed for her.
extension VisitDetailViewModel {
    enum VisitDayProblem: Equatable {
        case unchanged
        case inFuture
        case reasonMissing
    }

    /// Whether changing the day needs a reason (the record is locked).
    var visitDayNeedsReason: Bool {
        draftPathForDay == .addCorrection
    }

    private var draftPathForDay: RecordLockPolicy.EditPath {
        record.map { RecordEditRules.path(for: $0, now: now()) } ?? .addCorrection
    }

    /// Nil when the day can be saved.
    func visitDayProblem(day: Date, reason: String) -> VisitDayProblem? {
        if day > now() { return .inFuture }
        if let current = values?.performedAt, abs(current.timeIntervalSince(day)) < 60 { return .unchanged }
        if visitDayNeedsReason, RecordEditRules.normalized(reason) == nil { return .reasonMissing }
        return nil
    }

    /// Saves the visit day. Returns true when it was saved.
    @discardableResult
    func saveVisitDay(_ day: Date, reason: String) async -> Bool {
        guard !isWorking, let record, let repository = vault.repository,
              visitDayProblem(day: day, reason: reason) == nil else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            switch draftPathForDay {
            case .editDirectly:
                var changed = record
                changed.performedAt = day
                try await repository.save(changed)
            case .addCorrection:
                try await repository.addCorrection(RecordCorrection(
                    id: makeID(), recordID: record.id, createdAt: now(),
                    fieldKey: RecordCurrentValues.performedAtKey,
                    oldValue: values?.performedAt.map(RecordCurrentValues.text(from:)),
                    newValue: RecordCurrentValues.text(from: day), reason: RecordEditRules.normalized(reason)
                ))
            }
            actionErrorMessage = nil
            await loadAsync()
            return true
        } catch {
            failAction()
            return false
        }
    }
}
