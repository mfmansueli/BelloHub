//
//  WaitlistViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of 2.9 Waitlist: the time that opened up and the people waiting. An offer needs the server's
/// answer at once (the first to accept gets the time), so it is not queued: offline, it fails and says so. Once the
/// server holds the time, "Send" opens WhatsApp with the offer and its one-time link (D14: she presses send).
@MainActor
@Observable
final class WaitlistViewModel {
    /// What happened to an offer she made from this screen.
    enum OfferResult: Equatable, Sendable {
        /// The server holds the time for this person until `until`; `holdKey` makes their one-time link.
        case offered(until: Date, holdKey: String)
        case slotTaken
    }

    private(set) var offering: Set<String> = []
    private(set) var results: [String: OfferResult] = [:]
    private(set) var errorMessage: String?
    /// Phones of her clients who cancel often (`CancelsOftenLookup`), for the chip on their rows.
    private(set) var cancelsOftenPhones: Set<String> = []
    /// Offers whose chat she opened in this visit of the screen.
    private(set) var sent: Set<String> = []
    /// Neither WhatsApp nor Messages opened: the text waits in the share sheet card.
    private(set) var shareText: String?

    let timeZone: TimeZone
    @ObservationIgnored private let sync: BookingSyncService
    @ObservationIgnored private let vault: VaultService?
    @ObservationIgnored private let messages: MessageService?
    @ObservationIgnored private let link: BookingLink?
    @ObservationIgnored private let business: AgendaBusinessContext?
    @ObservationIgnored private let now: @Sendable () -> Date

    init(
        sync: BookingSyncService, timeZone: TimeZone, vault: VaultService? = nil, messages: MessageService? = nil,
        link: BookingLink? = nil, business: AgendaBusinessContext? = nil,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.sync = sync
        self.timeZone = timeZone
        self.vault = vault
        self.messages = messages
        self.link = link
        self.business = business
        self.now = now
    }

    // MARK: - Reading

    func board(now: Date) -> WaitlistBoard {
        WaitlistBoard.make(snapshot: sync.snapshot, timeZone: timeZone, now: now)
    }

    var isLoading: Bool { sync.isLoading && sync.snapshot.syncedAt == nil }

    var syncErrorMessage: String? { sync.errorMessage }

    func cancelsOften(_ entry: WaitlistRequest) -> Bool {
        CancelsOftenLookup.cancelsOften(phone: entry.phone, in: cancelsOftenPhones)
    }

    /// Reads her clients and visits once, for the "Cancels often" chip.
    func loadHabits() async {
        guard let repository = vault?.repository,
              let clients = try? await repository.allClients(),
              let visits = try? await repository.loadAppointments(in: Self.anyTime)
        else { return }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        cancelsOftenPhones = CancelsOftenLookup.phones(
            clients: clients, appointments: visits, now: now(), calendar: calendar
        )
    }

    private static let anyTime = DateInterval(start: .distantPast, end: .distantFuture)

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
            case .offered(let holdKey, let expiresAt): results[entry.id] = .offered(until: expiresAt, holdKey: holdKey)
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

    /// Send can work: she has a booking address (an offer needs her page online anyway) and a way to open a chat.
    var canSend: Bool { link != nil && messages != nil && business != nil }

    /// The offer's text for this person, or nil before the server held the time (or without her booking address).
    func offerText(for entry: WaitlistRequest, now: Date) -> String? {
        guard case .offered(let until, let holdKey)? = results[entry.id], let link, let business,
              let open = board(now: now).openTime else { return nil }
        let input = WaitlistOfferMessage.Input(
            personName: entry.name, serviceName: open.serviceName, startsAt: open.startsAt, heldUntil: until,
            link: BookingSuggestionOutcome.offerURL(link: link, holdKey: holdKey)
        )
        return WaitlistOfferMessage.text(
            input, localization: business.localization, formatters: business.messageFormatters
        )
    }

    func send(_ entry: WaitlistRequest) {
        Task { await sendAsync(entry) }
    }

    /// Opens WhatsApp (or Messages, or the share sheet) with the offer ready; she presses send.
    func sendAsync(_ entry: WaitlistRequest) async {
        let moment = now()
        guard let messages, let text = offerText(for: entry, now: moment) else { return }
        let outcome = await messages.send(
            text: text, to: nil, phoneE164: entry.phone, template: "waitlistOffer",
            preferred: business?.preferredChannel ?? .whatsapp, now: moment
        )
        sent.insert(entry.id)
        if case .needsShareSheet(let shared) = outcome { shareText = shared } else { shareText = nil }
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
