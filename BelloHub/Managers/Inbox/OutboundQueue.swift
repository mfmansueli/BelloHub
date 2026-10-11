//
//  OutboundQueue.swift
//  BelloHub
//

import Foundation
import Observation

/// Writes to the server that were decided on the phone (docs/04-ARCHITECTURE.md section 3, "offline first"): each
/// one is kept in `UserDefaults` per user until the server took it, sent in order per aggregate, retried by itself
/// after a growing pause when the network or the server is away, and dropped (with its outcome reported) when the
/// server refuses it for good. Ids are idempotent: a replay after a crash never becomes a second write.
///
/// `BookingSyncService` and `MailboxService` enqueue; they learn how an action ended through `observe`.
@MainActor
@Observable
final class OutboundQueue {
    private(set) var pending: [OutboundAction] = []
    private(set) var isFlushing = false
    /// The last transient failure, while actions wait for the retry.
    private(set) var waitingOn: BookingRepositoryError?

    @ObservationIgnored private var observers: [UUID: @MainActor (OutboundAction, OutboundOutcome) -> Void] = [:]

    @ObservationIgnored private let repository: any InboxRepository
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let retryDelays: [Duration]
    @ObservationIgnored private let sleeper: @Sendable (Duration) async throws -> Void
    @ObservationIgnored private var userID: String?
    @ObservationIgnored private var flushTask: Task<Void, Never>?
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    @ObservationIgnored private var attempt = 0

    init(
        repository: any InboxRepository,
        defaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = { Date() },
        retryDelays: [Duration] = [.seconds(15), .seconds(60), .seconds(300)],
        sleeper: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.repository = repository
        self.defaults = defaults
        self.now = now
        self.retryDelays = retryDelays.isEmpty ? [.seconds(60)] : retryDelays
        self.sleeper = sleeper
    }

    // MARK: - Lifecycle

    /// Loads what was left for `userID` and sends it.
    func start(userID: String) {
        guard self.userID != userID else { return }
        stop()
        self.userID = userID
        pending = Self.load(defaults, key: Self.key(userID))
        flush()
    }

    /// Stops sending; the actions stay on disk for the next start.
    func stop() {
        flushTask?.cancel()
        retryTask?.cancel()
        flushTask = nil
        retryTask = nil
        userID = nil
        pending = []
        isFlushing = false
        waitingOn = nil
        attempt = 0
    }

    /// Sign-out: nothing of hers stays queued for the next person on this phone.
    func clearForSignOut(userID: String) {
        defaults.removeObject(forKey: Self.key(userID))
        stop()
    }

    // MARK: - Outcomes

    /// Calls `handler` for every action that ends, until `stopObserving`. Returns the token to stop with.
    @discardableResult
    func observe(_ handler: @escaping @MainActor (OutboundAction, OutboundOutcome) -> Void) -> UUID {
        let token = UUID()
        observers[token] = handler
        return token
    }

    func stopObserving(_ token: UUID?) {
        guard let token else { return }
        observers[token] = nil
    }

    // MARK: - Actions

    /// Adds the action and sends it as soon as the server answers. Returns it so the caller can match its outcome.
    @discardableResult
    func enqueue(_ kind: OutboundAction.Kind) -> OutboundAction {
        let action = OutboundAction(kind: kind, createdAt: now())
        pending.append(action)
        persist()
        flush()
        return action
    }

    /// Sends everything pending, in order, one at a time. Fire-and-forget; safe to call while a flush runs.
    func flush() {
        guard flushTask == nil else { return }
        retryTask?.cancel()
        retryTask = nil
        flushTask = Task { [weak self] in
            await self?.flushAsync()
            self?.flushTask = nil
        }
    }

    /// Sends everything pending and returns when the queue is empty or a transient failure stopped it.
    func flushAsync() async {
        guard userID != nil, !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }
        var blocked: Set<String> = []
        for action in pending {
            guard !Task.isCancelled, userID != nil else { return }
            guard !blocked.contains(action.aggregate) else { continue }
            do {
                let outcome = try await perform(action)
                remove(action)
                attempt = 0
                waitingOn = nil
                report(action, outcome)
            } catch let error as BookingRepositoryError where error == .unreachable || error == .busy {
                // The same action can succeed later without anybody changing anything: keep it, wait, try again.
                bump(action)
                blocked.insert(action.aggregate)
                waitingOn = error
                scheduleRetry()
                return
            } catch {
                let failure = (error as? BookingRepositoryError) ?? .rejected
                remove(action)
                report(action, .failed(failure))
            }
        }
    }

    // MARK: - Private

    private func report(_ action: OutboundAction, _ outcome: OutboundOutcome) {
        for handler in observers.values { handler(action, outcome) }
    }

    private func perform(_ action: OutboundAction) async throws -> OutboundOutcome {
        switch action.kind {
        case .respondBookingRequest(let bookingId, let approve):
            return .bookingRequest(try await repository.respondBookingRequest(id: bookingId, approve: approve))
        case .respondRescheduleRequest(let requestId, let accept):
            return .reschedule(try await repository.respondRescheduleRequest(id: requestId, accept: accept))
        case .acknowledgeMailboxItem(let itemId):
            try await repository.acknowledgeMailboxItem(id: itemId)
        case .removeWaitlistEntry(let waitlistId):
            try await repository.removeWaitlistEntry(id: waitlistId)
        case .resetNoShowCount(let phone):
            try await repository.resetNoShowCount(phone: phone)
        case .registerDevice(let fcmToken, let locale):
            try await repository.registerDevice(fcmToken: fcmToken, locale: locale)
        case .unregisterDevice(let fcmToken):
            try await repository.unregisterDevice(fcmToken: fcmToken)
        case .deleteClientServerData(let phone, let bookingIds):
            try await repository.deleteClientServerData(phone: phone, bookingIds: bookingIds)
        case .reserveRegistrations(let claims):
            return .registrations(try await repository.reserveRegistrations(claims))
        case .cancelBookingByOwner(let bookingId):
            try await repository.cancelBookingByOwner(id: bookingId)
        case .moveBookingByOwner(let bookingId, let startsAt):
            try await repository.moveBookingByOwner(id: bookingId, startsAt: startsAt)
        case .markNoShow(let bookingId, let phone, let markId, let markedAt):
            try await repository.markNoShow(phone: phone, markId: markId, markedAt: markedAt, bookingId: bookingId)
        case .forgiveNoShow(_, let phone, let markId):
            try await repository.forgiveNoShow(phone: phone, markId: markId)
        }
        return .done
    }

    private func scheduleRetry() {
        guard retryTask == nil else { return }
        let delay = retryDelays[min(attempt, retryDelays.count - 1)]
        attempt += 1
        retryTask = Task { [weak self, sleeper] in
            try? await sleeper(delay)
            guard let self, !Task.isCancelled else { return }
            retryTask = nil
            flush()
        }
    }

    private func remove(_ action: OutboundAction) {
        pending.removeAll { $0.id == action.id }
        persist()
    }

    private func bump(_ action: OutboundAction) {
        guard let index = pending.firstIndex(where: { $0.id == action.id }) else { return }
        pending[index].attempts += 1
        persist()
    }

    private func persist() {
        guard let userID else { return }
        defaults.set(try? JSONEncoder().encode(pending), forKey: Self.key(userID))
    }

    private static func load(_ defaults: UserDefaults, key: String) -> [OutboundAction] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([OutboundAction].self, from: data)) ?? []
    }

    private static func key(_ userID: String) -> String { DefaultsKey.outboundQueue + "." + userID }
}
