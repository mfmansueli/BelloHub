//
//  BookingSetupService.swift
//  BelloHub
//

import Foundation
import Observation

/// How clients can book her, as the signed-in professional sees it: her weekly hours, breaks and days off, the booking
/// page switches with the two policies and her chosen address, and her quick replies. Screens read it for what to show
/// and write through it; nothing else touches the vault for this data. Created once at the root and read with
/// `@Environment(BookingSetupService.self)`.
///
/// The published values change **only after the vault confirms a write** (CLAUDE.md section 2); a failed save leaves
/// them as they were and the caller decides what to tell her. Writes are queued one behind the other, so two quick taps
/// can never land out of order.
///
/// It needs only the booking half of the vault (`BookingSetupRepository`).
@MainActor
@Observable
final class BookingSetupService {
    /// Her hours. Until she (or a first change) stores them this is `AvailabilitySettings.starter`.
    private(set) var availability: AvailabilitySettings
    /// True while `availability` is only the suggested starting week and nothing has been stored.
    private(set) var isStarterAvailability = true
    private(set) var setup: BookingSetup
    private(set) var quickReplies: [QuickReply] = []
    /// Whether `load` has read the vault at least once, so a screen can tell "not read yet" from "nothing stored".
    private(set) var hasLoaded = false

    /// Looked up on each use, because the vault may be unavailable (nil) when the store could not be opened.
    private let source: @MainActor () -> (any BookingSetupRepository)?
    private let now: @Sendable () -> Date
    /// The last queued write; the next one waits for it.
    private var writeTail: Task<Void, Never>?

    init(vault: VaultService, now: @escaping @Sendable () -> Date = { Date() }) {
        source = { vault.repository }
        self.now = now
        availability = .starter(timeZoneID: TimeZone.current.identifier)
        setup = .starter(now: now())
    }

    init(repository: any BookingSetupRepository, now: @escaping @Sendable () -> Date = { Date() }) {
        source = { repository }
        self.now = now
        availability = .starter(timeZoneID: TimeZone.current.identifier)
        setup = .starter(now: now())
    }

    // MARK: - Reading

    /// Reads her availability and booking setup. `timeZoneID` is the business time zone, used for the starting week
    /// when nothing is stored yet. A failure throws and leaves the previous values: a locked vault must not blank a
    /// screen that is already showing.
    func load(timeZoneID: String) async throws {
        let repository = try requireRepository()
        let storedAvailability = try await repository.availability()
        let storedSetup = try await repository.bookingSetup()
        if let storedAvailability {
            availability = storedAvailability
            isStarterAvailability = false
        } else {
            availability = .starter(timeZoneID: timeZoneID)
            isStarterAvailability = true
        }
        setup = storedSetup ?? .starter(now: now())
        hasLoaded = true
    }

    /// Reads her quick replies and, the first time, writes the six built-in ones in her business language. A pure read
    /// afterwards: replies she deleted do not come back (the built-in ones cannot be deleted, so an empty vault always
    /// means "never opened").
    func loadQuickReplies(localization: AppLocalization) async throws {
        let repository = try requireRepository()
        var stored = try await repository.quickReplies()
        if stored.isEmpty {
            let defaults = BuiltInQuickReply.allCases.map { $0.reply(in: localization, now: now()) }
            try await repository.save(defaults)
            stored = try await repository.quickReplies()
        }
        let upgraded = QuickReplyUpgrade.upgraded(stored, localization: localization, now: now())
        if !upgraded.isEmpty {
            try await repository.save(upgraded)
            stored = try await repository.quickReplies()
        }
        quickReplies = stored
    }

    /// Forgets everything (sign-out). The next `load` starts from the vault again.
    func clear() {
        availability = .starter(timeZoneID: TimeZone.current.identifier)
        isStarterAvailability = true
        setup = .starter(now: now())
        quickReplies = []
        hasLoaded = false
    }

    // MARK: - Writing

    func saveAvailability(_ updated: AvailabilitySettings) async throws {
        let repository = try requireRepository()
        try await queued {
            try await repository.save(updated)
            self.availability = updated
            self.isStarterAvailability = false
        }
    }

    /// Stores the page switches, policies and address. The repository stamps `updatedAt`; the stored copy is read back,
    /// and what was just written is kept if that read fails.
    func saveSetup(_ updated: BookingSetup) async throws {
        let repository = try requireRepository()
        try await queued {
            try await repository.save(updated)
            self.setup = (try? await repository.bookingSetup()) ?? updated
        }
    }

    func saveQuickReply(_ reply: QuickReply) async throws {
        let repository = try requireRepository()
        try await queued {
            try await repository.save(reply)
            self.quickReplies = Self.ordered(self.quickReplies.filter { $0.id != reply.id } + [reply])
        }
    }

    /// Stores several replies in one write (a new order renumbers many of them).
    func saveQuickReplies(_ replies: [QuickReply]) async throws {
        let repository = try requireRepository()
        try await queued {
            try await repository.save(replies)
            let ids = Set(replies.map(\.id))
            self.quickReplies = Self.ordered(self.quickReplies.filter { !ids.contains($0.id) } + replies)
        }
    }

    func deleteQuickReply(id: UUID) async throws {
        let repository = try requireRepository()
        try await queued {
            try await repository.deleteQuickReply(id: id)
            self.quickReplies.removeAll { $0.id == id }
        }
    }

    // MARK: - Helpers

    private func requireRepository() throws -> any BookingSetupRepository {
        guard let repository = source() else { throw VaultRepositoryError.unavailable }
        return repository
    }

    /// Runs `work` after every earlier write has finished, whether those succeeded or not.
    private func queued(_ work: @escaping @MainActor () async throws -> Void) async throws {
        let previous = writeTail
        let task = Task { @MainActor in
            await previous?.value
            try await work()
        }
        writeTail = Task { _ = await task.result }
        try await task.value
    }

    private static func ordered(_ replies: [QuickReply]) -> [QuickReply] {
        replies.sorted { ($0.position, $0.title, $0.id.uuidString) < ($1.position, $1.title, $1.id.uuidString) }
    }
}
