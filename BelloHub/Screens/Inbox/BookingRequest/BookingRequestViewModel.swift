//
//  BookingRequestViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of 2.10 BookingRequest: one booking that waits for her yes. The request itself lives in
/// `BookingSyncService` (the server is the source of truth); this screen only reads it and answers through the
/// service, which queues the answer so it reaches the server even when she is offline.
@MainActor
@Observable
final class BookingRequestViewModel {
    let bookingID: String
    /// "Start the count from zero": sent with the approval when the request waits because of the no-show limit.
    var resetsCount = false
    var isPaywallPresented = false
    /// Her client with the request's phone, for "See history"; nil when the phone is new to her.
    private(set) var historyClientID: UUID?

    @ObservationIgnored private let sync: BookingSyncService
    @ObservationIgnored private let vault: VaultService

    init(bookingID: String, sync: BookingSyncService, vault: VaultService) {
        self.bookingID = bookingID
        self.sync = sync
        self.vault = vault
    }

    // MARK: - Reading

    var booking: IncomingBooking? { sync.snapshot.booking(id: bookingID) }

    var phase: InboxRequestPhase {
        .booking(
            booking, isLoading: sync.isLoading, isSending: sync.answering.contains(bookingID),
            needsPlan: sync.needsSubscription.contains(bookingID)
        )
    }

    /// Only a request held by the no-show limit offers to start the count again.
    var offersCountReset: Bool { booking?.pendingReason == .noShowLimit }

    /// The answer is saved but the server cannot be reached: it goes out once she is online.
    var isWaitingForNetwork: Bool { sync.queue.waitingOn != nil }

    var errorMessage: String? { sync.lastFailure.map { BookingSyncService.text(for: $0) } }

    // MARK: - Actions

    func load() {
        Task { await loadAsync() }
    }

    /// Finds her client with the same phone, so the no-show notice can open the history.
    func loadAsync() async {
        guard let phone = booking?.client.phone.trimmingCharacters(in: .whitespaces), !phone.isEmpty,
              let repository = vault.repository,
              let clients = try? await repository.allClients() else { return }
        historyClientID = clients.first { $0.phoneE164?.trimmingCharacters(in: .whitespaces) == phone }?.id
    }

    func approve() {
        guard phase.canAnswer, let booking else { return }
        if offersCountReset, resetsCount { sync.resetNoShowCount(phone: booking.client.phone) }
        sync.respond(toBooking: bookingID, approve: true)
    }

    func decline() {
        guard phase.canAnswer else { return }
        sync.respond(toBooking: bookingID, approve: false)
    }

    func showPlans() {
        isPaywallPresented = true
    }

    func refreshAsync() async {
        await sync.syncAsync()
    }
}
