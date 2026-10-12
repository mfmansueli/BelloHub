//
//  TreatmentFlowViewModel+Closing.swift
//  BelloHub
//

import Foundation

/// Older visits saved before the visit form had everything on one screen could be left "to finish later" with their
/// photos, aftercare and next visit open (routine-a item 7). The form now holds all of that, so no closing is started
/// any more; a resumed one opens its record in the form and is marked done when she finalizes or leaves it, so it
/// leaves the follow-up queue.
extension TreatmentFlowViewModel {
    /// Reads the closing of the record being resumed, if any.
    func resumeClosingIfRequested() {
        guard let resumeID = request.resumeRecordID else { return }
        closing = closings?.closing(for: resumeID)
    }

    /// Settles every step of a resumed closing.
    func markClosingDone() {
        guard var current = closing ?? request.resumeRecordID.flatMap({ closings?.closing(for: $0) }) else { return }
        current.settled = Set(VisitClosing.Step.allCases)
        current.isDeferred = false
        closing = current
        closings?.save(current)
    }
}
