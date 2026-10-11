//
//  FollowUpReason.swift
//  BelloHub
//

import Foundation

/// The facts behind one suggestion, from her own visits and services only (routine-a item 12): no clinical inference,
/// no promise. `FollowUpReasonText` turns them into the sentence she reads.
enum FollowUpReason: Equatable, Sendable {
    /// A visit coming up; reminders are ready from the evening before.
    case reminder(visitStart: Date, serviceName: String)
    /// She chose "Finish later" on a visit; these steps are still open.
    case unfinishedVisit(serviceName: String, openSteps: [VisitClosing.Step])
    /// A visit of today or yesterday.
    case postVisit(visitStart: Date, serviceName: String)
    /// The usual interval of the service has passed since the last visit and no return is booked.
    case returnDue(serviceName: String, intervalWeeks: Int?, lastVisit: Date)
    /// Nothing booked since the last visit, this many days ago.
    case notBack(daysSinceLastVisit: Int)
    case birthday(date: Date, isToday: Bool)
}
