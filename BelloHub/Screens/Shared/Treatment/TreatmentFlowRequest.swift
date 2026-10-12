//
//  TreatmentFlowRequest.swift
//  BelloHub
//

import Foundation

/// What starts the visit flow: a visit she is about to document, a client with no appointment (a walk-in, or an old
/// visit she is writing now), a draft she is continuing, or a past visit she uses as the base of a new one. The flow
/// is a full-screen cover with its own stack, opened from the appointment, the client record, Home and the alerts.
struct TreatmentFlowRequest: Identifiable, Hashable, Sendable {
    let id = UUID()
    let clientID: UUID
    var appointmentID: UUID?
    var serviceID: UUID?
    /// A record already saved whose closing she is resuming (routine-a item 7): the flow opens on it, at the first
    /// step still open, and never makes a second record.
    var resumeRecordID: UUID?
    /// A record to open as it is: a draft to continue, or one still open to complete.
    var recordID: UUID?
    /// A past visit used as the base of a new one, with the parts she chose to copy (`VisitReuse`).
    var base: VisitReuse?
}
