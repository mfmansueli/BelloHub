//
//  TimeBlockService.swift
//  BelloHub
//

import Foundation
import Observation

/// The stretches she closed in the calendar. Like `AppointmentService` it keeps no copy: the calendar reads
/// `stream(in:)` (the vault pushes every change) and the free-slot calculation reads `blocks(in:)`, so there is
/// nothing to clear on lock or sign-out. Cancelling the visits a block covers is `AppointmentService`'s job
/// (`BlockTimeViewModel` sequences the two).
@MainActor
@Observable
final class TimeBlockService {
    /// Looked up on each use, because the vault may be unavailable (nil) when the store could not be opened.
    private let source: @MainActor () -> (any TimeBlockRepository)?

    init(vault: VaultService) {
        source = { vault.repository }
    }

    init(repository: any TimeBlockRepository) {
        source = { repository }
    }

    // MARK: - Reading

    /// Blocks that overlap `range`, now and after every change; empty when the vault is unavailable.
    func stream(in range: DateInterval) -> AsyncStream<[TimeBlock]> {
        source()?.timeBlocks(in: range) ?? AsyncStream { $0.finish() }
    }

    func blocks(in range: DateInterval) async throws -> [TimeBlock] {
        try await requireRepository().loadTimeBlocks(in: range)
    }

    // MARK: - Writing

    /// Stores the blocks together: one decision, never half of it.
    func block(_ blocks: [TimeBlock]) async throws {
        try await requireRepository().save(blocks)
    }

    func removeBlock(id: UUID) async throws {
        try await requireRepository().deleteTimeBlock(id: id)
    }

    // MARK: - Private

    private func requireRepository() throws -> any TimeBlockRepository {
        guard let repository = source() else { throw VaultRepositoryError.unavailable }
        return repository
    }
}
