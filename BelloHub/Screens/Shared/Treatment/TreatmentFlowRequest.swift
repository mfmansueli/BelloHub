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
}
