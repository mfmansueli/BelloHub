//
//  TreatmentFlowStep.swift
//  BelloHub
//

import Foundation

/// The screens the flow pushes over the visit form (the form is the root of the stack, so it has no case).
enum TreatmentFlowStep: Hashable, Sendable {
    /// 5.2 Tx-2-Listening.
    case listening
    /// 5.3 Tx-3-Organizing.
    case organizing
    /// 5.4 Tx-4-Review.
    case review
    /// The compact confirmation after "Finalize record".
    case saved
    /// 5.8 Camera, for a before, an after or a progress photo.
    case camera(PhotoKind)
    /// The finalized visit's full details.
    case record
}
