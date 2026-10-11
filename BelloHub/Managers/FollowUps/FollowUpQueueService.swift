//
//  FollowUpQueueService.swift
//  BelloHub
//

import Foundation
import Observation

/// The follow-up queue's own state for the signed-in user (routine-a items 5, 6 and 7): what she decided about each
/// suggestion (snoozed, dismissed, marked as sent), the visits she is closing in steps (`VisitClosing`), and the chats
/// opened lately (the vault's `MessageLog`, read so "Conversation opened" survives a relaunch). Decisions and closings
/// are local to this iPhone (`UserDefaults`, per user: ids, dates and flags only, nothing clinical). Created once in
/// `RootView`; `start(userID:)` when the app is unlocked, `stop()` when it locks or she signs out.
@MainActor
@Observable
final class FollowUpQueueService {
    private(set) var decisions: [String: FollowUpDecision] = [:]
    private(set) var closings: [UUID: VisitClosing] = [:]
    private(set) var messageLogs: [MessageLog] = []

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let vault: VaultService
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var userID: String?

    /// How far back the chats opened are read.
    static let logWindowDays = 120

    init(defaults: UserDefaults, vault: VaultService, now: @escaping @Sendable () -> Date = { Date() }) {
        self.defaults = defaults
        self.vault = vault
        self.now = now
    }

    // MARK: - Session

    func start(userID: String) {
        guard self.userID != userID else { return }
        self.userID = userID
        decisions = load([String: FollowUpDecision].self, key: Self.decisionsKey(userID)) ?? [:]
        let stored = load([VisitClosing].self, key: Self.closingsKey(userID)) ?? []
        closings = Dictionary(stored.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        Task { await refreshLogs() }
    }

    /// Forgets everything in memory (what is stored stays for the next unlock).
    func stop() {
        userID = nil
        decisions = [:]
        closings = [:]
        messageLogs = []
    }

    /// Reads the chats opened in the last months again (after a message sheet closes, a pull to refresh).
    func refreshLogs() async {
        guard let repository = vault.repository else { return }
        let since = now().addingTimeInterval(-Double(Self.logWindowDays) * 86_400)
        if let logs = try? await repository.messageLogs(since: since) { messageLogs = logs }
    }

    // MARK: - Decisions

    /// "Later": out of the list for a week.
    func snooze(_ occurrence: String) {
        update(occurrence) {
            $0.snoozedUntil = now().addingTimeInterval(Double(FollowUpDecision.snoozeDays) * 86_400)
        }
    }

    func dismiss(_ occurrence: String) {
        update(occurrence) { $0.dismissedAt = now() }
    }

    /// She says she sent the message herself; the suggestion rests for two weeks.
    func markSent(_ occurrence: String) {
        let moment = now()
        update(occurrence) {
            $0.markedSentAt = moment
            $0.snoozedUntil = moment.addingTimeInterval(Double(FollowUpDecision.afterSentDays) * 86_400)
        }
    }

    /// Back into the list.
    func restore(_ occurrence: String) {
        decisions[occurrence] = nil
        persistDecisions()
    }

    // MARK: - Visit closing

    func closing(for recordID: UUID) -> VisitClosing? {
        closings[recordID]
    }

    func save(_ closing: VisitClosing) {
        closings[closing.id] = closing
        persistClosings()
    }

    /// She finished (or chose to finish) closing the visit: it leaves the queue.
    func complete(recordID: UUID) {
        guard var closing = closings[recordID] else { return }
        closing.settled = Set(VisitClosing.Step.allCases)
        closing.isDeferred = false
        closings[recordID] = closing
        persistClosings()
    }

    // MARK: - Private

    private func update(_ occurrence: String, _ change: (inout FollowUpDecision) -> Void) {
        var decision = decisions[occurrence] ?? FollowUpDecision()
        change(&decision)
        decisions[occurrence] = decision
        persistDecisions()
    }

    private func persistDecisions() {
        guard let userID else { return }
        store(decisions, key: Self.decisionsKey(userID))
    }

    /// Finished closings older than a month are dropped, so the list never grows without end.
    private func persistClosings() {
        guard let userID else { return }
        let cutoff = now().addingTimeInterval(-30 * 86_400)
        let kept = closings.values.filter { !$0.isComplete || $0.recordCreatedAt > cutoff }
        store(kept.sorted { $0.recordCreatedAt < $1.recordCreatedAt }, key: Self.closingsKey(userID))
    }

    private func load<Value: Decodable>(_ type: Value.Type, key: String) -> Value? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    private func store(_ value: some Encodable, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func decisionsKey(_ userID: String) -> String { DefaultsKey.followUpDecisions + "." + userID }
    private static func closingsKey(_ userID: String) -> String { DefaultsKey.visitClosings + "." + userID }
}
