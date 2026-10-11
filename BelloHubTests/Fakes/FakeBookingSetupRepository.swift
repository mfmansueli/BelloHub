//
//  FakeBookingSetupRepository.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// The booking half of the vault in memory, for tests of `BookingSetupService` and the ViewModels above it. Unlike
/// the real repositories it can be told to fail every read or write, which is how the error paths are tested; the
/// contract tests cover the real behavior against both vaults.
actor FakeBookingSetupRepository: BookingSetupRepository {
    struct Failure: Error, Equatable {}

    private var storedAvailability: AvailabilitySettings?
    private var storedSetup: BookingSetup?
    private var repliesByID: [UUID: QuickReply] = [:]
    private var failsWrites = false
    private var failsReads = false
    private var delay: Duration?
    private(set) var writeCount = 0
    /// The order writes arrived in, as short names, so a test can prove they were queued.
    private(set) var writeLog: [String] = []

    /// While true, every write throws `Failure` and changes nothing.
    func setFailsWrites(_ value: Bool) { failsWrites = value }

    /// While true, every read throws `Failure`.
    func setFailsReads(_ value: Bool) { failsReads = value }

    /// Makes each write take this long, so a test can start a second one before the first finishes.
    func setDelay(_ value: Duration?) { delay = value }

    /// Puts values in as if an earlier session stored them, without counting a write.
    func seed(availability: AvailabilitySettings? = nil, setup: BookingSetup? = nil, replies: [QuickReply] = []) {
        if let availability { storedAvailability = availability }
        if let setup { storedSetup = setup }
        replies.forEach { repliesByID[$0.id] = $0 }
    }

    func storedQuickReplies() -> [QuickReply] {
        repliesByID.values.sorted { $0.position < $1.position }
    }

    // MARK: - BookingSetupRepository

    func availability() throws -> AvailabilitySettings? {
        try beginRead()
        return storedAvailability
    }

    func save(_ availability: AvailabilitySettings) async throws {
        try await beginWrite("availability")
        storedAvailability = availability
    }

    func bookingSetup() throws -> BookingSetup? {
        try beginRead()
        return storedSetup
    }

    func save(_ setup: BookingSetup) async throws {
        try await beginWrite("setup")
        storedSetup = setup
    }

    func quickReplies() throws -> [QuickReply] {
        try beginRead()
        return storedQuickReplies()
    }

    func save(_ reply: QuickReply) async throws {
        try await beginWrite("reply")
        repliesByID[reply.id] = reply
    }

    func save(_ replies: [QuickReply]) async throws {
        try await beginWrite("replies")
        replies.forEach { repliesByID[$0.id] = $0 }
    }

    func deleteQuickReply(id: UUID) async throws {
        try await beginWrite("delete")
        repliesByID[id] = nil
    }

    // MARK: - Private

    private func beginRead() throws {
        if failsReads { throw Failure() }
    }

    private func beginWrite(_ name: String) async throws {
        if let delay { try? await Task.sleep(for: delay) }
        if failsWrites { throw Failure() }
        writeCount += 1
        writeLog.append(name)
    }
}
