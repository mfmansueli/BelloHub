//
//  FollowUpItem.swift
//  BelloHub
//

import Foundation

/// One pending reason for one client in the follow-up queue: why (`reason`), since when (`due`), what the next action
/// opens, and where its message stands.
struct FollowUpItem: Identifiable, Equatable, Sendable {
    let kind: FollowUpKind
    let clientID: UUID
    /// Names this occurrence of the reason (a reminder of one visit, a return due after one last visit), so a decision
    /// about it never hides the next one.
    let occurrence: String
    /// The day it became due, or the visit's start for reminders and check-ins.
    let due: Date
    let reason: FollowUpReason
    var appointmentID: UUID?
    var recordID: UUID?
    var serviceName: String?
    var delivery: MessageDeliveryState = .readyToSend

    var id: String { occurrence }
}
