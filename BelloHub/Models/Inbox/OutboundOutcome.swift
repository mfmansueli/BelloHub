//
//  OutboundOutcome.swift
//  BelloHub
//

/// How an `OutboundAction` ended once it reached the server (or could not).
enum OutboundOutcome: Equatable, Sendable {
    case bookingRequest(BookingRequestOutcome)
    case reschedule(RescheduleOutcome)
    /// A write with no answer worth keeping (acknowledge, remove, reset, device).
    case done
    /// Dropped: the server refused it for good, or there is no server. Transient failures are not outcomes; the
    /// action waits in the queue.
    case failed(BookingRepositoryError)
}
