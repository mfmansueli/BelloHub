//
//  TimeBlockServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("TimeBlockService")
@MainActor
struct TimeBlockServiceTests {
    private var range: DateInterval {
        DateInterval(start: TestClock.date("2026-10-08 00:00"), end: TestClock.date("2026-10-09 00:00"))
    }

    @Test("Blocks are stored together, read back and removed")
    func lifecycle() async throws {
        let service = TimeBlockService(repository: InMemoryClientRecordRepository())
        let first = makeBlock(start: TestClock.date("2026-10-08 09:00"), reason: "Family")
        let second = makeBlock(start: TestClock.date("2026-10-08 15:00"))
        try await service.block([first, second])
        #expect(try await service.blocks(in: range).map(\.id) == [first.id, second.id])
        try await service.removeBlock(id: first.id)
        #expect(try await service.blocks(in: range).map(\.id) == [second.id])
    }

    @Test("The stream pushes a change made through the service")
    func stream() async throws {
        let service = TimeBlockService(repository: InMemoryClientRecordRepository())
        var iterator = service.stream(in: range).makeAsyncIterator()
        #expect(await iterator.next()?.isEmpty == true)
        let item = makeBlock(start: TestClock.date("2026-10-08 09:00"))
        try await service.block([item])
        #expect(await iterator.next()?.map(\.id) == [item.id])
    }

    @Test("Without a vault every call is unavailable and the stream is empty")
    func unavailable() async throws {
        let service = TimeBlockService(vault: VaultService(repository: nil))
        await #expect(throws: VaultRepositoryError.unavailable) { try await service.blocks(in: range) }
        await #expect(throws: VaultRepositoryError.unavailable) {
            try await service.block([makeBlock(start: TestClock.date("2026-10-08 09:00"))])
        }
        var iterator = service.stream(in: range).makeAsyncIterator()
        #expect(await iterator.next() == nil)
    }
}
