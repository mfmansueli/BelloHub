//
//  TreatmentFlowRequest.swift
//  BelloHub
//

import Foundation

/// What starts the treatment flow (5.1 to 5.9): a visit she is about to document, or a client with no visit. The flow
/// is a full-screen cover with its own stack, opened from the appointment, the client profile and the calendar.
struct TreatmentFlowRequest: Identifiable, Hashable, Sendable {
    let id = UUID()
    let clientID: UUID
    var appointmentID: UUID?
    var serviceID: UUID?
    /// A record already saved whose closing she is resuming (routine-a item 7): the flow opens on it, at the first
    /// step still open, and never makes a second record.
    var resumeRecordID: UUID?
}
