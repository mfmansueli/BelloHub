//
//  VaultPublishingSource.swift
//  BelloHub
//

import Foundation

/// Reads her profile, services, hours, policies, agenda and blocks from the vault, and her inbox key from the key
/// manager.
/// The agenda is read from a day back to the end of the booking window (the server drops the past itself).
@MainActor
struct VaultPublishingSource: PublishingSource {
    private let vault: VaultService
    private let keys: any InboxKeyProviding
    private let windowDays: Int

    init(vault: VaultService, keys: any InboxKeyProviding, windowDays: Int = 400) {
        self.vault = vault
        self.keys = keys
        self.windowDays = windowDays
    }

    func inputs(now: Date) async throws -> PublishInputs {
        guard let repository = vault.repository else { throw VaultRepositoryError.unavailable }
        guard let profile = try await repository.profile() else { throw PublishSourceError.noProfile }
        let inboxKey: InboxPublicKey
        do {
            inboxKey = try keys.currentInboxPublicKey()
        } catch {
            throw PublishSourceError.locked
        }
        let range = DateInterval(start: now.addingTimeInterval(-86_400), duration: Double(windowDays) * 86_400)
        let stored = try await repository.availability()
        return PublishInputs(
            profile: profile,
            services: try await repository.services(),
            addOns: try await repository.addOns(),
            credentials: try await repository.credentials(),
            setup: try await repository.bookingSetup() ?? .starter(now: now),
            availability: stored ?? .starter(timeZoneID: profile.timeZoneID),
            appointments: try await repository.loadAppointments(in: range),
            blocks: try await repository.loadTimeBlocks(in: range),
            inboxKey: inboxKey
        )
    }

    func changes() -> AsyncStream<Void> {
        guard let repository = vault.repository else { return AsyncStream { $0.finish() } }
        // Any vault write re-emits the appointments stream, which makes it a change signal for everything.
        let source = repository.appointments(in: DateInterval(start: .distantPast, end: .distantPast))
        return AsyncStream { continuation in
            let task = Task {
                for await _ in source { continuation.yield() }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
