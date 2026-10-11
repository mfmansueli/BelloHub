//
//  SwiftDataClientRecordRepository+TimeBlocks.swift
//  BelloHub
//

import Foundation

extension SwiftDataClientRecordRepository {
    nonisolated func timeBlocks(in range: DateInterval) -> AsyncStream<[TimeBlock]> {
        changes.stream { [self] in (try? await loadTimeBlocks(in: range)) ?? [] }
    }

    func loadTimeBlocks(in range: DateInterval) throws -> [TimeBlock] {
        let inRange = try items(kind: .timeBlock).filter { item in
            guard let start = item.dateA, let end = item.dateB else { return false }
            return start < range.end && end > range.start
        }
        return try values(TimeBlock.self, from: inRange).sorted { $0.startsAt < $1.startsAt }
    }

    func save(_ block: TimeBlock) throws {
        try upsert(block)
        try commit()
    }

    func save(_ blocks: [TimeBlock]) throws {
        try blocks.forEach { try upsert($0) }
        try commit()
    }

    func deleteTimeBlock(id: UUID) throws {
        if let found = try item(kind: .timeBlock, id: id) { delete([found]) }
        try commit()
    }
}
