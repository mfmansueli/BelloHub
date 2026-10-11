//
//  TreatmentFlowViewModel+Closing.swift
//  BelloHub
//

import Foundation

/// Closing the visit after the record is saved (routine-a item 7): photos, aftercare and the next visit, in one path
/// with a small "Step n of 4", each skippable, with "Finish later" that leaves the visit in the follow-up queue. The
/// progress lives in `VisitClosing` (ids and flags, on this iPhone), never in the record, so the record's 24-hour lock
/// and its corrections are untouched: aftercare and the next-visit note are written into the record only while it is
/// still open.
extension TreatmentFlowViewModel {
    /// The record can still be edited directly (`RecordLockPolicy`).
    var isRecordEditable: Bool {
        guard let record = savedRecord else { return false }
        return !RecordLockPolicy.isLocked(lockedAt: record.lockedAt, now: now())
    }

    /// Starts (or finds) the closing of the record just saved.
    func beginClosing() {
        guard let record = savedRecord else { return }
        if let stored = closings?.closing(for: record.id) {
            closing = stored
            return
        }
        let started = VisitClosing(
            id: record.id, clientID: record.clientID, appointmentID: record.appointmentID,
            serviceName: record.serviceName, recordCreatedAt: record.createdAt
        )
        closing = started
        closings?.save(started)
    }

    /// The step is done or skipped; the flow moves to the next open step, or closes the visit when none is left.
    /// Returns false when the visit is closed, so the screen can close the flow.
    @discardableResult
    func advance(from step: VisitClosing.Step) -> Bool {
        guard var current = closing else { return false }
        current.settled.insert(step)
        if current.isComplete { current.isDeferred = false }
        store(current)
        guard let next = VisitClosingRules.next(after: step, in: current) else { return false }
        replaceTop(with: VisitClosingRules.screen(for: next))
        return true
    }

    /// From the saved record: the first open step.
    func continueClosing() {
        guard let next = closing?.nextStep else { return }
        path.append(VisitClosingRules.screen(for: next))
    }

    /// "Finish later": the open steps wait in the follow-up queue.
    func finishLater() {
        guard var current = closing, !current.isComplete else { return }
        current.isDeferred = true
        store(current)
    }

    /// Writes the aftercare she prepared into the record while it can still be edited. Returns whether it worked (a
    /// locked record is left as it is: a change then is a correction, from the record's history).
    @discardableResult
    func saveAftercare(_ text: String) async -> Bool {
        guard isRecordEditable, let repository, var record = savedRecord else { return false }
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned != (record.aftercare ?? "") else { return true }
        record.aftercare = cleaned.isEmpty ? nil : cleaned
        do {
            try await repository.save(record)
            savedRecord = record
            return true
        } catch {
            failure = .save
            return false
        }
    }

    /// The aftercare text to start from: the record's, else the service's own template.
    var aftercareText: String {
        savedRecord?.aftercare ?? service?.aftercareTemplate ?? ""
    }

    /// Opens a resumed flow on the saved record and the first open step (no second record is ever made: the record
    /// id is the request's).
    func resumeIfRequested() async {
        guard let resumeID = request.resumeRecordID, let repository else { return }
        guard let record = try? await repository.record(id: resumeID) else { return }
        savedRecord = record
        beginClosing()
        if let closing { path = VisitClosingRules.resumePath(for: closing) }
    }

    private func store(_ updated: VisitClosing) {
        closing = updated
        closings?.save(updated)
    }
}
