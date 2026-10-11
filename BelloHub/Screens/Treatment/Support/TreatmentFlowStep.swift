//
//  TreatmentFlowStep.swift
//  BelloHub
//

import Foundation

/// The screens the flow pushes after its first one (5.1 Tx-1-Register is the root of the stack, so it has no case).
enum TreatmentFlowStep: Hashable, Sendable {
    /// 5.2 Tx-2-Listening.
    case listening
    /// 5.3 Tx-3-Organizing.
    case organizing
    /// 5.4 Tx-4-Review.
    case review
    /// 5.5 Tx-Form.
    case form
    /// 5.6 Tx-5-Saved.
    case saved
    /// 5.7 Tx-6-Photos.
    case photos
    /// 5.8 Camera, for a before, an after or a progress photo.
    case camera(PhotoKind)
    /// The aftercare step of the visit's closing (routine-a item 7).
    case aftercare
    /// 5.9 Tx-7-NextSession.
    case nextSession
    /// "See the full record": the client's record history (4.7).
    case history
}
