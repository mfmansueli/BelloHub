//
//  BookingSyncService+LinkVisits.swift
//  BelloHub
//

import Foundation

/// Her own changes to link visits on their way to the server, and the reads that keep every mirrored visit in step
/// with its booking (docs/agent-notes/fix-booking-status.md).
extension BookingSyncService {
    // MARK: - Her changes to link visits

    /// Sends a change she made to a link visit to the server, through the queue (so it also leaves when the network
    /// comes back, and after a relaunch). Until the server took it, the sync leaves that booking alone.
    func linkVisitChanged(_ change: LinkVisitChange) {
        ledger.noteChange(of: change.bookingID)
        switch change {
        case .cancelled(let bookingID):
            queue.enqueue(.cancelBookingByOwner(bookingId: bookingID))
        case .moved(let bookingID, let startsAt):
            queue.enqueue(.moveBookingByOwner(bookingId: bookingID, startsAt: startsAt))
        case .noShow(let bookingID, let clientID, let markID, let markedAt, let forgiven):
            Task {
                guard let phone = await phone(bookingID: bookingID, clientID: clientID) else { return }
                queue.enqueue(.markNoShow(bookingId: bookingID, phone: phone, markId: markID, markedAt: markedAt))
                if forgiven { queue.enqueue(.forgiveNoShow(bookingId: bookingID, phone: phone, markId: markID)) }
            }
        case .noShowForgiven(let bookingID, let clientID, let markID):
            Task {
                guard let phone = await phone(bookingID: bookingID, clientID: clientID) else { return }
                queue.enqueue(.forgiveNoShow(bookingId: bookingID, phone: phone, markId: markID))
            }
        }
    }

    /// The phone the server counts no-shows by: the booking's, else the one on her client record. Without one the
    /// server is not told (its count is per phone); her visit still says no-show, and a "confirmed" from the server
    /// never reopens it.
    private func phone(bookingID: String, clientID: UUID) async -> String? {
        if let phone = snapshot.booking(id: bookingID)?.client.phone, !phone.isEmpty { return phone }
        let client = try? await vault.repository?.client(id: clientID)
        return client?.phoneE164.flatMap { $0.isEmpty ? nil : $0 }
    }

    // MARK: - Reads for the import

    /// Bookings whose server state a read that started at `tick` may not show yet: a change of hers still queued, or
    /// one whose answer came after the read started.
    func heldLocally(since tick: Int) -> Set<String> {
        Set(queue.pending.compactMap(\.kind.changedBookingID)).union(ledger.changed(after: tick))
    }

    /// The bookings of visits that still hold time but were not in the list (moved before the window, a page cut
    /// short): read one by one, a few per pass. A failed read waits for the next pass; it never stops the import.
    func lookUpMissing(linked: [Appointment], listed: [IncomingBooking], userID: String) async -> [IncomingBooking] {
        let listedIDs = Set(listed.map(\.id))
        let horizon = now().addingTimeInterval(-Self.lookBack)
        let missing = Set(linked.compactMap { visit -> String? in
            guard let id = visit.bookingID, visit.status.holdsTime, visit.endsAt > horizon,
                  !listedIDs.contains(id), !ledger.gone.contains(id) else { return nil }
            return id
        })
        var found: [IncomingBooking] = []
        for id in missing.sorted().prefix(Self.lookUpLimit) {
            do {
                if let booking = try await repository.booking(uid: userID, id: id) {
                    found.append(booking)
                } else {
                    ledger.noteGone(id)
                }
            } catch {
                continue
            }
        }
        return found
    }
}
