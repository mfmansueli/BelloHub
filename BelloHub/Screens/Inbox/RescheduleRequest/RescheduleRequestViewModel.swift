//
//  RescheduleRequestViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of 2.11 RescheduleRequest: a client asks to move a confirmed visit. The current time stays
/// booked until she accepts; the answer goes through `BookingSyncService`'s queue.
@MainActor
@Observable
final class RescheduleRequestViewModel {
    let requestID: String

    @ObservationIgnored private let sync: BookingSyncService

    init(requestID: String, sync: BookingSyncService) {
        self.requestID = requestID
        self.sync = sync
    }

    // MARK: - Reading

    var request: RescheduleRequest? { sync.snapshot.rescheduleRequest(id: requestID) }

    var phase: InboxRequestPhase {
        .reschedule(
            request, isLoading: sync.isLoading, isSending: sync.answering.contains(requestID),
            slotTaken: sync.slotTaken.contains(requestID)
        )
    }

    /// The booking it moves, for her rules and the service length.
    var booking: IncomingBooking? { request.flatMap { sync.snapshot.booking(id: $0.bookingId) } }

    var timing: RescheduleTiming? {
        request.map { RescheduleTiming.make(request: $0, policy: booking?.policy) }
    }

    var isWaitingForNetwork: Bool { sync.queue.waitingOn != nil }

    var errorMessage: String? { sync.lastFailure.map { BookingSyncService.text(for: $0) } }

    // MARK: - Actions

    /// Accepting a time that was taken in the meantime is not offered again: the request stays, she declines it.
    func accept() {
        guard phase == .open else { return }
        sync.respond(toReschedule: requestID, accept: true)
    }

    func decline() {
        guard phase.canAnswer else { return }
        sync.respond(toReschedule: requestID, accept: false)
    }

    func refreshAsync() async {
        await sync.syncAsync()
    }
}
