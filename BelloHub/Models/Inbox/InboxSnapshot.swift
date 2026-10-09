//
//  InboxSnapshot.swift
//  BelloHub
//

import Foundation

/// What `BookingSyncService` last learned from the server, kept per user so the inbox opens with the last known state
/// before the network answers. Operational data the server already holds (no clinical content); it is removed on
/// sign-out.
struct InboxSnapshot: Equatable, Codable, Sendable {
    var bookings: [IncomingBooking] = []
    var rescheduleRequests: [RescheduleRequest] = []
    var waitlist: [WaitlistRequest] = []
    var syncedAt: Date?
    /// Booking ids whose last server change she has seen in the inbox (new bookings, cancellations and client
    /// confirmations are shown until then).
    var seenUpdates: [String: Date] = [:]

    var pendingRequests: [IncomingBooking] {
        bookings.filter(\.isPendingRequest).sorted { $0.createdAt < $1.createdAt }
    }

    var pendingReschedules: [RescheduleRequest] {
        rescheduleRequests.filter(\.isPending).sorted { $0.createdAt < $1.createdAt }
    }

    var waiting: [WaitlistRequest] {
        waitlist.filter(\.isWaiting).sorted { $0.createdAt < $1.createdAt }
    }

    /// Confirmed, cancelled or client-confirmed bookings she has not looked at since they changed, newest first.
    var unseenChanges: [IncomingBooking] {
        bookings
            .filter { !$0.isPendingRequest && $0.status != .declined && (seenUpdates[$0.id] ?? .distantPast) < $0.updatedAt }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func booking(id: String) -> IncomingBooking? { bookings.first { $0.id == id } }
    func rescheduleRequest(id: String) -> RescheduleRequest? { rescheduleRequests.first { $0.id == id } }
}
