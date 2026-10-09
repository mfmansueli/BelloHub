//
//  RepositoryTimeBlockContractTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("Repository contract: time blocks", .serialized)
struct RepositoryTimeBlockContractTests {
    private let fixture = ContractFixture()

    private func block(_ start: String, minutes: Int = 120, reason: String? = nil) -> TimeBlock {
        makeBlock(start: TestClock.date(start), minutes: minutes, reason: reason)
    }

    private var day: DateInterval {
        DateInterval(start: TestClock.date("2026-10-08 00:00"), end: TestClock.date("2026-10-09 00:00"))
    }

    @Test("Blocks are found by the range they overlap, in time order", arguments: RepositoryFlavor.allCases)
    func range(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        let morning = block("2026-10-08 09:00")
        let evening = block("2026-10-08 18:00")
        let nextDay = block("2026-10-09 09:00")
        let overnight = block("2026-10-07 23:00", minutes: 180)
        for item in [evening, nextDay, morning, overnight] { try await repository.save(item) }

        #expect(try await repository.loadTimeBlocks(in: day).map(\.id) == [overnight.id, morning.id, evening.id])
    }

    @Test("A block that only touches the range is outside it", arguments: RepositoryFlavor.allCases)
    func touching(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        try await repository.save(block("2026-10-07 22:00", minutes: 120))
        try await repository.save(block("2026-10-09 00:00", minutes: 60))
        #expect(try await repository.loadTimeBlocks(in: day).isEmpty)
    }

    @Test("The reason comes back, and saving the same id changes the block", arguments: RepositoryFlavor.allCases)
    func updateAndReason(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        var stored = block("2026-10-08 09:00", reason: "Sentinel-REASON")
        try await repository.save(stored)
        #expect(try await repository.loadTimeBlocks(in: day).first?.reason == "Sentinel-REASON")
        stored.endsAt = stored.startsAt.addingTimeInterval(3_600)
        stored.reason = nil
        try await repository.save(stored)
        let again = try await repository.loadTimeBlocks(in: day)
        #expect(again.count == 1 && again.first?.reason == nil)
        #expect(again.first?.endsAt == stored.endsAt)
    }

    @Test("Several blocks are stored together, and a block can be deleted twice", arguments: RepositoryFlavor.allCases)
    func severalAndDelete(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        let first = block("2026-10-08 09:00")
        let second = block("2026-10-08 15:00")
        try await repository.save([first, second])
        #expect(try await repository.loadTimeBlocks(in: day).count == 2)
        try await repository.deleteTimeBlock(id: first.id)
        try await repository.deleteTimeBlock(id: first.id)
        #expect(try await repository.loadTimeBlocks(in: day).map(\.id) == [second.id])
    }

    @Test("The stream delivers the blocks now and again after each change", arguments: RepositoryFlavor.allCases)
    func stream(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        let first = block("2026-10-08 09:00")
        try await repository.save(first)
        var iterator = repository.timeBlocks(in: day).makeAsyncIterator()
        #expect(await iterator.next()?.map(\.id) == [first.id])
        let second = block("2026-10-08 15:00")
        try await repository.save(second)
        #expect(await iterator.next()?.map(\.id) == [first.id, second.id])
    }

    @Test("A block is never an appointment: the agenda reads do not show it", arguments: RepositoryFlavor.allCases)
    func separateFromAppointments(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        try await repository.save(block("2026-10-08 09:00"))
        #expect(try await repository.loadAppointments(in: day).isEmpty)
    }
}
