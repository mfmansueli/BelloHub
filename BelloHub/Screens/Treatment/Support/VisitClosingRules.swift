//
//  VisitClosingRules.swift
//  BelloHub
//

import Foundation

/// The path that closes a visit after the record is saved (routine-a item 7): Register (done), then the optional
/// photos, aftercare and next visit, each skippable and resumable. Pure: which screen a step is, where a resumed flow
/// starts, and the "Step n of 4" position.
enum VisitClosingRules {
    /// Register plus the three optional steps.
    static let totalSteps = 4

    static func screen(for step: VisitClosing.Step) -> TreatmentFlowStep {
        switch step {
        case .photos: .photos
        case .aftercare: .aftercare
        case .nextVisit: .nextSession
        }
    }

    static func step(for screen: TreatmentFlowStep) -> VisitClosing.Step? {
        switch screen {
        case .photos: .photos
        case .aftercare: .aftercare
        case .nextSession: .nextVisit
        default: nil
        }
    }

    /// 1 for the saved record, then 2, 3, 4.
    static func position(of screen: TreatmentFlowStep) -> Int {
        guard let step = step(for: screen), let index = VisitClosing.Step.allCases.firstIndex(of: step) else {
            return 1
        }
        return index + 2
    }

    /// The step after `step` that is still open, or nil when the visit is closed.
    static func next(after step: VisitClosing.Step, in closing: VisitClosing) -> VisitClosing.Step? {
        let all = VisitClosing.Step.allCases
        guard let index = all.firstIndex(of: step) else { return closing.nextStep }
        return all[(index + 1)...].first { !closing.settled.contains($0) } ?? closing.nextStep
    }

    /// Where a resumed flow opens: the saved record with the first open step on top of it.
    static func resumePath(for closing: VisitClosing) -> [TreatmentFlowStep] {
        [.saved] + (closing.nextStep.map { [screen(for: $0)] } ?? [])
    }
}
