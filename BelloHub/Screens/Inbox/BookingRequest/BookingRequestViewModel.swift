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
    /// That client cancels often (`CancelsOftenLookup`): the chip next to the name.
    private(set) var cancelsOften = false

    // "Suggest another time"
    var isSuggestSheetPresented = false
    var suggestedStart = Date()
    private(set) var isSuggesting = false
    private(set) var suggestion: BookingSuggestionOutcome?
    private(set) var suggestionErrorMessage: String?

    @ObservationIgnored private let sync: BookingSyncService
    @ObservationIgnored private let vault: VaultService
    @ObservationIgnored private let link: BookingLink?
    @ObservationIgnored private let now: @Sendable () -> Date

    /// `link` is her booking page, for the link of a suggested time; nil before she chose an address.
    init(
        bookingID: String, sync: BookingSyncService, vault: VaultService, link: BookingLink? = nil,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.bookingID = bookingID
        self.sync = sync
        self.vault = vault
        self.link = link
        self.now = now
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

    /// "Not verified": the client confirmed on WhatsApp because the e-mail code never came (verify-fallback). nil for a
    /// verified request. Approving works the same; the badge asks her to check the message first.
    var unverifiedBadge: UnverifiedRequestBadge? { booking.flatMap(UnverifiedRequestBadge.make) }

    /// Whether the "why it waits" notice shows (an unverified request without a server reason shows only the badge).
    var showsReason: Bool { booking.map(UnverifiedRequestBadge.showsReason) ?? true }

    /// The answer is saved but the server cannot be reached: it goes out once she is online.
    var isWaitingForNetwork: Bool { sync.queue.waitingOn != nil }

    var errorMessage: String? { sync.lastFailure.map { BookingSyncService.text(for: $0) } }

    // MARK: - Actions

    func load() {
        Task { await loadAsync() }
    }

    /// Finds her client with the same phone, so the no-show notice can open the history and the chip can show.
    func loadAsync() async {
        guard let phone = booking?.client.phone.trimmingCharacters(in: .whitespaces), !phone.isEmpty,
              let repository = vault.repository,
              let clients = try? await repository.allClients() else { return }
        historyClientID = clients.first { $0.phoneE164?.trimmingCharacters(in: .whitespaces) == phone }?.id
        guard let clientID = historyClientID, let visits = try? await repository.appointments(for: clientID),
              let zone = booking.flatMap({ TimeZone(identifier: $0.timeZoneID) }) else { return }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let phones = CancelsOftenLookup.phones(
            clients: clients.filter { $0.id == clientID }, appointments: visits, now: now(), calendar: calendar
        )
        cancelsOften = CancelsOftenLookup.cancelsOften(phone: phone, in: phones)
    }

    // MARK: - Suggest another time

    /// The server held the suggested time (the request is declined).
    var isSuggested: Bool {
        if case .suggested? = suggestion { true } else { false }
    }

    /// The link the client opens for the suggested time; nil until the server held it.
    var suggestionURL: URL? {
        guard case .suggested(let holdKey, _)? = suggestion, let link else { return nil }
        return BookingSuggestionOutcome.offerURL(link: link, holdKey: holdKey)
    }

    /// Opens the sheet on the same time a day later, a starting point she changes.
    func beginSuggestion() {
        guard phase.canAnswer, let booking else { return }
        suggestedStart = booking.startsAt.addingTimeInterval(86_400)
        suggestion = nil
        suggestionErrorMessage = nil
        isSuggestSheetPresented = true
    }

    func suggest() {
        Task { await suggestAsync() }
    }

    /// Needs the server's answer at once (the held time and its key): offline it fails and says so.
    func suggestAsync() async {
        guard !isSuggesting, suggestion == nil, suggestedStart > now() else { return }
        isSuggesting = true
        suggestionErrorMessage = nil
        defer { isSuggesting = false }
        do {
            suggestion = try await sync.suggest(bookingID: bookingID, startsAt: suggestedStart)
            if suggestion == .slotTaken {
                suggestion = nil
                suggestionErrorMessage = Self.slotTakenMessage
            }
        } catch {
            suggestionErrorMessage = BookingSyncService.text(for: error)
        }
    }

    private static var slotTakenMessage: String {
        String(
            localized: "bookingRequest.suggest.slotTaken", defaultValue: "That time is not free. Choose another one."
        )
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
