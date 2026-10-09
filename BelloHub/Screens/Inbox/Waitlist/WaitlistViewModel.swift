//
//  WaitlistViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of 2.9 Waitlist: the time that opened up and the people waiting. An offer needs the server's
/// answer at once (the first to accept gets the time), so it is not queued: offline, it fails and says so.
@MainActor
@Observable
final class WaitlistViewModel {
    /// What happened to an offer she made from this screen.
    enum OfferResult: Equatable, Sendable {
        case offered(until: Date)
        case slotTaken
    }

    private(set) var offering: Set<String> = []
    private(set) var results: [String: OfferResult] = [:]
    private(set) var errorMessage: String?

    let timeZone: TimeZone
    @ObservationIgnored private let sync: BookingSyncService

    init(sync: BookingSyncService, timeZone: TimeZone) {
        self.sync = sync
        self.timeZone = timeZone
    }

    // MARK: - Reading

    func board(now: Date) -> WaitlistBoard {
        WaitlistBoard.make(snapshot: sync.snapshot, timeZone: timeZone, now: now)
    }

    var isLoading: Bool { sync.isLoading && sync.snapshot.syncedAt == nil }

    var syncErrorMessage: String? { sync.errorMessage }

    /// The time was given to somebody else, or the server said it is gone: no more offers.
    var isTimeTaken: Bool { results.values.contains(.slotTaken) }

    // MARK: - Actions

    func offer(_ entry: WaitlistRequest, now: Date = Date()) {
        Task { await offerAsync(entry, now: now) }
    }

    func offerAsync(_ entry: WaitlistRequest, now: Date = Date()) async {
        guard let open = board(now: now).openTime, entry.isWaiting, !offering.contains(entry.id), !isTimeTaken else {
            return
        }
        offering.insert(entry.id)
        errorMessage = nil
        defer { offering.remove(entry.id) }
        do {
            let offer = WaitlistOffer(waitlistId: entry.id, serviceId: open.serviceID, startsAt: open.startsAt)
            switch try await sync.offer(offer) {
            case .offered(_, let expiresAt): results[entry.id] = .offered(until: expiresAt)
            case .slotTaken: results[entry.id] = .slotTaken
            }
        } catch {
            errorMessage = BookingSyncService.text(for: error)
        }
    }

    /// Offers the open time to everybody waiting for that day, one after the other; stops when it is taken.
    func offerAll(now: Date = Date()) {
        Task { await offerAllAsync(now: now) }
    }

    func offerAllAsync(now: Date = Date()) async {
        for entry in board(now: now).offerable {
            guard !isTimeTaken, errorMessage == nil else { return }
            await offerAsync(entry, now: now)
        }
    }

    func remove(_ entry: WaitlistRequest) {
        sync.removeWaitlistEntry(id: entry.id)
    }

    func dismissError() {
        errorMessage = nil
    }

    func refreshAsync() async {
        await sync.syncAsync()
    }
}
