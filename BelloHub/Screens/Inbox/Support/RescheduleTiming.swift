//
//  RescheduleTiming.swift
//  BelloHub
//

import Foundation

/// How long before the visit the client asked to move it, against her free-change window (2.11). A request inside the
/// window is why it reached her instead of moving by itself (`CancellationPolicy.afterWindowReschedule`). Pure.
struct RescheduleTiming: Equatable, Sendable {
    /// Minutes between the request and the current visit's start; never negative.
    let minutesBefore: Int
    /// Her free-change window, when the booking carried her rules.
    let freeWindowHours: Int?

    /// Asked inside the last `freeWindowHours` before the visit.
    var isLate: Bool {
        guard let freeWindowHours else { return false }
        return minutesBefore < freeWindowHours * 60
    }

    static func make(request: RescheduleRequest, policy: CancellationPolicy?) -> RescheduleTiming {
        let seconds = request.currentStart.timeIntervalSince(request.createdAt)
        return RescheduleTiming(minutesBefore: max(Int(seconds / 60), 0), freeWindowHours: policy?.freeWindowHours)
    }
}
