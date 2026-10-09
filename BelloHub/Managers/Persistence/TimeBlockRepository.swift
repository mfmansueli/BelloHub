//
//  TimeBlockRepository.swift
//  BelloHub
//

import Foundation

/// The stretches she closed ("I cannot work"). Part of the calendar's data, kept apart from `AgendaRepository` so a
/// fake of the appointments and services does not have to know about blocks.
protocol TimeBlockRepository: Sendable {
    /// Blocks that overlap `range`, now and after every change.
    func timeBlocks(in range: DateInterval) -> AsyncStream<[TimeBlock]>
    func loadTimeBlocks(in range: DateInterval) async throws -> [TimeBlock]
    func save(_ block: TimeBlock) async throws
    /// Stores several blocks **together**: blocking three days is one decision, never a half.
    func save(_ blocks: [TimeBlock]) async throws
    func deleteTimeBlock(id: UUID) async throws
}
