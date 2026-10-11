//
//  BookingSyncService.swift
//  BelloHub
//

import Foundation
import Observation

/// What arrives through her link, kept in step with the server: bookings go into the agenda (`BookingImporter`
/// decides how), requests wait for her answer, the waitlist is hers to offer. Read with
/// `@Environment(BookingSyncService.self)`; `startListening(userId:)` / `stopListening()` frame the signed-in,
/// unlocked session.
///
/// The server is the source of truth for every booking field (API.md section 8). The phone reads them (no live
/// listener without the SDK: it syncs on start, on a push, on foreground, on pull-to-refresh and every
/// `pollInterval`), mirrors them into the vault and answers requests through the `OutboundQueue`, so an answer given
/// offline still reaches the server. The last snapshot is cached per user so the inbox opens with what was known.
@MainActor
@Observable
final class BookingSyncService: LinkVisitChangeReporting {
    private(set) var snapshot = InboxSnapshot()
    private(set) var conflicts: [BookingConflict] = []
    /// True until the first sync finished (or the cache was loaded).
    private(set) var isLoading = true
    private(set) var isSyncing = false
    private(set) var errorMessage: String?
    /// Requests she answered that the server has not confirmed yet.
    private(set) var answering: Set<String> = []
    /// Bookings whose approval needs a plan first (D42): show the paywall, then approve again.
    private(set) var needsSubscription: Set<String> = []
    /// Reschedule requests whose requested time was taken before she accepted.
    private(set) var slotTaken: Set<String> = []
    /// The last write the server refused for good.
    private(set) var lastFailure: BookingRepositoryError?

    /// Bookings whose visit started up to this long ago are read (the server purges 7 days after the visit).
    static let lookBack: TimeInterval = 14 * 86_400
    /// At most this many visits whose booking left the list are looked up by id in one pass.
    static let lookUpLimit = 25

    @ObservationIgnored let repository: any InboxRepository
    @ObservationIgnored let queue: OutboundQueue
    @ObservationIgnored private let appointments: AppointmentService
    @ObservationIgnored let vault: VaultService
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored let now: @Sendable () -> Date
    @ObservationIgnored private let pollInterval: Duration?
    @ObservationIgnored private let sleeper: @Sendable (Duration) async throws -> Void
    @ObservationIgnored private var userID: String?
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var syncTask: Task<Void, Never>?
    @ObservationIgnored private var observerToken: UUID?
    /// A sync was asked for while one ran (a push during the poll): one more pass follows, so the newer change is read.
    @ObservationIgnored private var needsAnotherPass = false
    /// Her own link-visit changes, so a server read older than one of them never undoes it (+LinkVisits).
    @ObservationIgnored var ledger = LinkChangeLedger()

    init(
        repository: any InboxRepository,
        queue: OutboundQueue,
        appointments: AppointmentService,
        vault: VaultService,
        defaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = { Date() },
        pollInterval: Duration? = .seconds(90),
        sleeper: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.repository = repository
        self.queue = queue
        self.appointments = appointments
        self.vault = vault
        self.defaults = defaults
        self.now = now
        self.pollInterval = pollInterval
        self.sleeper = sleeper
        appointments.linkChanges = self
    }

    // MARK: - Listening

    /// Loads the cached snapshot, syncs now and keeps syncing every `pollInterval`. Safe to call again.
    func startListening(userId: String) {
        guard userID != userId else { return }
        stopListening()
        userID = userId
        if let cached = Self.load(defaults, key: Self.key(userId)) {
            snapshot = cached
            isLoading = false
        }
        observerToken = queue.observe { [weak self] action, outcome in self?.didFinish(action, outcome) }
        queue.start(userID: userId)
        syncNow()
        guard let pollInterval else { return }
        pollTask = Task { [weak self, sleeper] in
            while !Task.isCancelled {
                try? await sleeper(pollInterval)
                guard !Task.isCancelled else { return }
                await self?.syncAsync()
            }
        }
    }

    /// Stops syncing and forgets what was loaded (lock, sign-out). The cache stays for the next start.
    func stopListening() {
        pollTask?.cancel()
        syncTask?.cancel()
        pollTask = nil
        syncTask = nil
        queue.stopObserving(observerToken)
        observerToken = nil
        queue.stop()
        userID = nil
        snapshot = InboxSnapshot()
        conflicts = []
        answering = []
        needsSubscription = []
        slotTaken = []
        lastFailure = nil
        errorMessage = nil
        isLoading = true
        isSyncing = false
        needsAnotherPass = false
        ledger = LinkChangeLedger()
    }

    /// Sign-out: the cache and the queue of that user leave the phone.
    func clearForSignOut(userID: String) {
        defaults.removeObject(forKey: Self.key(userID))
        queue.clearForSignOut(userID: userID)
        stopListening()
    }

    // MARK: - Sync

    /// Fire-and-forget (a push, the app coming to the foreground). One sync at a time.
    func syncNow() {
        guard syncTask == nil else {
            needsAnotherPass = true
            return
        }
        syncTask = Task { [weak self] in
            await self?.syncAsync()
            self?.syncTask = nil
        }
    }

    /// For `.refreshable`: returns when the server answered or failed. Asked again while a pass runs, it runs one more
    /// pass when that one ends, so a change that arrived during a read is never left for the next poll.
    func syncAsync() async {
        guard let userID else { return }
        guard !isSyncing else {
            needsAnotherPass = true
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        repeat {
            needsAnotherPass = false
            await syncPass(userID: userID)
        } while needsAnotherPass && self.userID == userID
    }

    private func syncPass(userID: String) async {
        let since = now().addingTimeInterval(-Self.lookBack)
        let startedAt = ledger.tick
        do {
            async let bookings = repository.bookings(uid: userID, since: since)
            async let requests = repository.rescheduleRequests(uid: userID)
            async let waiting = repository.waitlist(uid: userID)
            let (fetchedBookings, fetchedRequests, fetchedWaitlist) = try await (bookings, requests, waiting)
            guard self.userID == userID else { return }
            snapshot.bookings = fetchedBookings
            snapshot.rescheduleRequests = fetchedRequests
            snapshot.waitlist = fetchedWaitlist
            snapshot.syncedAt = now()
            answering = answering.filter { id in
                fetchedBookings.contains { $0.id == id && $0.isPendingRequest }
                    || fetchedRequests.contains { $0.id == id && $0.isPending }
            }
            errorMessage = nil
            persist()
            await importIntoAgenda(fetchedBookings, userID: userID, readStartedAt: startedAt)
            queue.flush()
        } catch {
            errorMessage = Self.text(for: error)
        }
        isLoading = false
    }

    /// Mirrors the server's bookings into the vault: new clients, new visits, changed visits (`BookingImporter`).
    ///
    /// The visits are found by their booking, never by the bookings' times: a booking the client moved and then
    /// cancelled on the web sits at its new time, and its visit at the old one (the bug of fix-booking-status). A
    /// visit whose booking is not in the list at all (it moved before the window, or a page was cut) is looked up by
    /// id, so no visit stays stale out of sight. Bookings she changed here that the server has not taken yet, or whose
    /// answer came after this read started, are left alone: this read is older than her change.
    private func importIntoAgenda(_ bookings: [IncomingBooking], userID: String, readStartedAt: Int) async {
        guard let repository = vault.repository else {
            conflicts = []
            return
        }
        do {
            let linked = try await repository.linkedAppointments()
            let all = await bookings + lookUpMissing(linked: linked, listed: bookings, userID: userID)
            guard !all.isEmpty else {
                conflicts = []
                return
            }
            let start = (all.map(\.startsAt).min() ?? now()).addingTimeInterval(-86_400)
            let end = (all.map(\.endsAt).max() ?? now()).addingTimeInterval(86_400)
            // The window still matters for the visits she booked by hand: a conflict is an overlap with one of them.
            let nearby = try await repository.loadAppointments(in: DateInterval(start: start, end: max(end, start)))
            let clients = try await repository.allClients()
            let services = try await repository.services()
            let plan = BookingImporter.plan(
                bookings: all, appointments: linked + nearby, clients: clients, services: services, now: now(),
                heldLocally: heldLocally(since: readStartedAt)
            )
            // The server already counted a new phone for the free registrations (D42); saving her here mirrors it.
            for client in plan.newClients { try await repository.save(client) }
            for visit in plan.appointments { try await appointments.book(visit) }
            for id in plan.removals { try await repository.deleteAppointment(id: id) }
            conflicts = plan.conflicts
        } catch {
            errorMessage = Self.text(for: error)
        }
    }

    // MARK: - Answers

    /// Approves or declines a booking request (2.10). Decided now, sent when the server answers.
    func respond(toBooking bookingID: String, approve: Bool) {
        answering.insert(bookingID)
        needsSubscription.remove(bookingID)
        lastFailure = nil
        queue.enqueue(.respondBookingRequest(bookingId: bookingID, approve: approve))
    }

    /// Accepts or declines a reschedule request (2.11).
    func respond(toReschedule requestID: String, accept: Bool) {
        answering.insert(requestID)
        slotTaken.remove(requestID)
        lastFailure = nil
        queue.enqueue(.respondRescheduleRequest(requestId: requestID, accept: accept))
    }

    /// Her count starts from zero and online booking opens again for her (2.10).
    func resetNoShowCount(phone: String) {
        queue.enqueue(.resetNoShowCount(phone: phone))
    }

    /// Offers a time to somebody waiting (2.9). Needs the server's answer now, so it is not queued.
    func offer(_ offer: WaitlistOffer) async throws -> WaitlistOfferOutcome {
        let outcome = try await repository.offerWaitlistSlot(offer)
        if case .offered = outcome, let index = snapshot.waitlist.firstIndex(where: { $0.id == offer.waitlistId }) {
            snapshot.waitlist[index].status = .offered
            snapshot.waitlist[index].offeredAt = now()
            persist()
        }
        return outcome
    }

    /// "Suggest another time": needs the server's answer at once (the held time and its key), so it is not queued.
    /// The request reads as declined as soon as the server took the suggestion.
    func suggest(bookingID: String, startsAt: Date) async throws -> BookingSuggestionOutcome {
        let outcome = try await repository.suggestBookingTime(bookingId: bookingID, startsAt: startsAt)
        if case .suggested = outcome { update(booking: bookingID) { $0.status = .declined } }
        return outcome
    }

    func removeWaitlistEntry(id: String) {
        snapshot.waitlist.removeAll { $0.id == id }
        persist()
        queue.enqueue(.removeWaitlistEntry(waitlistId: id))
    }

    /// She looked at a booking's last change: it leaves the "new" list.
    func markSeen(bookingID: String) {
        guard let booking = snapshot.booking(id: bookingID) else { return }
        snapshot.seenUpdates[bookingID] = booking.updatedAt
        persist()
    }

    func markAllSeen() {
        for booking in snapshot.bookings { snapshot.seenUpdates[booking.id] = booking.updatedAt }
        persist()
    }
}

// MARK: - Outcomes

extension BookingSyncService {
    private func didFinish(_ action: OutboundAction, _ outcome: OutboundOutcome) {
        switch (action.kind, outcome) {
        case (.respondBookingRequest(let id, _), .bookingRequest(let answer)):
            answering.remove(id)
            didAnswer(booking: id, answer)
        case (.respondRescheduleRequest(let id, _), .reschedule(let answer)):
            answering.remove(id)
            didAnswer(request: id, answer)
        case (.respondBookingRequest(let id, _), .failed(let failure)),
             (.respondRescheduleRequest(let id, _), .failed(let failure)):
            answering.remove(id)
            lastFailure = failure
        case (let kind, _) where kind.changedBookingID != nil:
            // Taken, or refused for good (the booking had already changed there, BOOKING_NOT_ACTIVE): either way the
            // server now holds the truth, and the visit shows it after this sync. A refusal is not `lastFailure`: that
            // one is the request screens' error line, and this was no answer to a request.
            if let bookingID = kind.changedBookingID { ledger.noteChange(of: bookingID) }
            syncNow()
        case (_, .failed(let failure)):
            lastFailure = failure
        default:
            break
        }
    }

    private func didAnswer(booking id: String, _ answer: BookingRequestOutcome) {
        switch answer {
        case .confirmed:
            update(booking: id) {
                $0.status = .confirmed
                $0.pendingReason = nil
            }
        case .declined: update(booking: id) { $0.status = .declined }
        case .needsSubscription: needsSubscription.insert(id)
        }
        syncNow()
    }

    private func didAnswer(request id: String, _ answer: RescheduleOutcome) {
        switch answer {
        case .accepted: update(request: id) { $0.status = .accepted }
        case .declined: update(request: id) { $0.status = .declined }
        case .slotTaken: slotTaken.insert(id)
        }
        syncNow()
    }

    private func update(booking id: String, _ change: (inout IncomingBooking) -> Void) {
        guard let index = snapshot.bookings.firstIndex(where: { $0.id == id }) else { return }
        change(&snapshot.bookings[index])
        snapshot.bookings[index].updatedAt = now()
        persist()
    }

    private func update(request id: String, _ change: (inout RescheduleRequest) -> Void) {
        guard let index = snapshot.rescheduleRequests.firstIndex(where: { $0.id == id }) else { return }
        change(&snapshot.rescheduleRequests[index])
        persist()
    }
}

// MARK: - Cache

extension BookingSyncService {
    private func persist() {
        guard let userID else { return }
        defaults.set(try? JSONEncoder().encode(snapshot), forKey: Self.key(userID))
    }

    private static func load(_ defaults: UserDefaults, key: String) -> InboxSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(InboxSnapshot.self, from: data)
    }

    private static func key(_ userID: String) -> String { DefaultsKey.inboxSnapshot + "." + userID }
}
