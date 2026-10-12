//
//  LinkChangeLedger.swift
//  BelloHub
//

/// What the booking sync remembers about her own changes to link visits, so a server read is never trusted over a
/// change it may predate (fix-booking-status). Each change of hers, and each server answer to one, gets the next tick;
/// a read remembers the tick it started at, and a booking changed after that tick is left alone by its import.
/// Also the bookings the server no longer has, so they are not looked up again. Pure; owned by `BookingSyncService`.
struct LinkChangeLedger: Equatable, Sendable {
    /// The current tick: a read started now remembers this value.
    private(set) var tick = 0
    private var lastChange: [String: Int] = [:]
    /// Bookings the server answered "not there" for (purged, deleted).
    private(set) var gone: Set<String> = []

    /// She changed the booking's visit, or the server answered about that change.
    mutating func noteChange(of bookingID: String) {
        tick += 1
        lastChange[bookingID] = tick
    }

    mutating func noteGone(_ bookingID: String) {
        gone.insert(bookingID)
    }

    /// Bookings changed after a read that started at `tick`: that read may still show their older state.
    func changed(after tick: Int) -> Set<String> {
        Set(lastChange.filter { $0.value > tick }.keys)
    }
}
