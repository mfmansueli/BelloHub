//
//  InMemoryClientRecordRepository+TimeBlocks.swift
//  BelloHub
//

#if DEBUG
import Foundation

extension InMemoryClientRecordRepository {
    nonisolated func timeBlocks(in range: DateInterval) -> AsyncStream<[TimeBlock]> {
        changes.stream { [self] in await loadTimeBlocks(in: range) }
    }

    func loadTimeBlocks(in range: DateInterval) -> [TimeBlock] {
        timeBlocksByID.values.filter { $0.startsAt < range.end && $0.endsAt > range.start }
            .sorted { $0.startsAt < $1.startsAt }
    }

    func save(_ block: TimeBlock) {
        timeBlocksByID[block.id] = block
        changes.notify()
    }

    func save(_ blocks: [TimeBlock]) {
        blocks.forEach { timeBlocksByID[$0.id] = $0 }
        changes.notify()
    }

    func deleteTimeBlock(id: UUID) {
        timeBlocksByID[id] = nil
        changes.notify()
    }
}
#endif
