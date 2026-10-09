//
//  BookingSetupServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("BookingSetupService")
@MainActor
struct BookingSetupServiceTests {
    private let now = TestClock.now

    private func make() -> (BookingSetupService, FakeBookingSetupRepository) {
        let repository = FakeBookingSetupRepository()
        return (BookingSetupService(repository: repository, now: { TestClock.now }), repository)
    }

    // MARK: - Loading

    @Test("With nothing stored she starts from the suggested week and the standard policies")
    func loadsStarter() async throws {
        let (service, _) = make()
        try await service.load(timeZoneID: "America/Sao_Paulo")
        #expect(service.hasLoaded && service.isStarterAvailability)
        #expect(service.availability == .starter(timeZoneID: "America/Sao_Paulo"))
        #expect(service.availability.weekly.map(\.weekday) == [2, 3, 4, 5, 6])
        #expect(service.setup.cancellation == .standard && service.setup.noShow == .standard)
        #expect(service.setup.page == .standard && service.setup.slug == nil)
    }

    @Test("What is stored wins over the starter")
    func loadsStored() async throws {
        let (service, repository) = make()
        let stored = makeAvailability(weekdays: [3, 4], bufferMinutes: 30)
        var setup = BookingSetup.starter(now: now)
        setup.slug = "maria"
        await repository.seed(availability: stored, setup: setup)
        try await service.load(timeZoneID: "America/Sao_Paulo")
        #expect(service.availability == stored && !service.isStarterAvailability)
        #expect(service.setup.slug == "maria")
    }

    @Test("A failed read throws and leaves what was showing")
    func loadFailure() async throws {
        let (service, repository) = make()
        let stored = makeAvailability(weekdays: [3])
        await repository.seed(availability: stored)
        try await service.load(timeZoneID: "America/Sao_Paulo")
        await repository.setFailsReads(true)
        await #expect(throws: FakeBookingSetupRepository.Failure.self) { try await service.load(timeZoneID: "UTC") }
        #expect(service.availability == stored)
    }

    @Test("Without a vault everything throws unavailable")
    func noVault() async {
        let service = BookingSetupService(vault: VaultService(repository: nil))
        await #expect(throws: VaultRepositoryError.unavailable) { try await service.load(timeZoneID: "UTC") }
        await #expect(throws: VaultRepositoryError.unavailable) { try await service.saveSetup(.starter(now: Date())) }
        await #expect(throws: VaultRepositoryError.unavailable) {
            try await service.loadQuickReplies(localization: .en)
        }
    }

    // MARK: - Writing

    @Test("Availability changes only after the vault confirmed the write")
    func saveAvailability() async throws {
        let (service, repository) = make()
        try await service.load(timeZoneID: "America/Sao_Paulo")
        let updated = makeAvailability(weekdays: [3, 4, 5], bufferMinutes: 5)
        try await service.saveAvailability(updated)
        #expect(service.availability == updated && !service.isStarterAvailability)
        #expect(try await repository.availability() == updated)

        await repository.setFailsWrites(true)
        await #expect(throws: FakeBookingSetupRepository.Failure.self) {
            try await service.saveAvailability(makeAvailability(weekdays: [2]))
        }
        #expect(service.availability == updated, "a failed write leaves the published value alone")
    }

    @Test("The booking setup is saved and the stored copy is what she sees")
    func saveSetup() async throws {
        let (service, repository) = make()
        try await service.load(timeZoneID: "UTC")
        var setup = service.setup
        setup.slug = "maria"
        setup.noShow.limit = 5
        try await service.saveSetup(setup)
        #expect(service.setup.slug == "maria" && service.setup.noShow.limit == 5)
        #expect(try await repository.bookingSetup()?.slug == "maria")

        await repository.setFailsWrites(true)
        var other = setup
        other.slug = "other"
        await #expect(throws: FakeBookingSetupRepository.Failure.self) { try await service.saveSetup(other) }
        #expect(service.setup.slug == "maria")
    }

    @Test("Writes wait for each other: the last one asked is the one stored")
    func writesAreQueued() async throws {
        let (service, repository) = make()
        try await service.load(timeZoneID: "UTC")
        await repository.setDelay(.milliseconds(60))
        var first = service.setup
        first.slug = "first"
        var second = service.setup
        second.slug = "second"
        // Unstructured tasks start in the order they are made; `async let` gives no such promise.
        let one = Task { try await service.saveSetup(first) }
        let two = Task { try await service.saveSetup(second) }
        try await one.value
        try await two.value
        #expect(try await repository.bookingSetup()?.slug == "second")
        #expect(service.setup.slug == "second")
        #expect(await repository.writeCount == 2)
    }

    @Test("A failed write does not stop the ones queued after it")
    func queueSurvivesFailure() async throws {
        let (service, repository) = make()
        try await service.load(timeZoneID: "UTC")
        await repository.setFailsWrites(true)
        var broken = service.setup
        broken.slug = "broken"
        await #expect(throws: FakeBookingSetupRepository.Failure.self) { try await service.saveSetup(broken) }
        await repository.setFailsWrites(false)
        var fine = service.setup
        fine.slug = "fine"
        try await service.saveSetup(fine)
        #expect(service.setup.slug == "fine")
    }

    // MARK: - Quick replies

    @Test("The first time the six built-in replies are written in her language")
    func seedsDefaults() async throws {
        let (service, repository) = make()
        try await service.loadQuickReplies(localization: .ptBR)
        #expect(service.quickReplies.count == 6)
        #expect(service.quickReplies.map(\.title) == BuiltInQuickReply.allCases.map { $0.title(in: .ptBR) })
        #expect(service.quickReplies.allSatisfy { $0.builtIn != nil })
        #expect(await repository.storedQuickReplies().count == 6)
    }

    @Test("A second read does not write again, even in another language")
    func seedsOnce() async throws {
        let (service, repository) = make()
        try await service.loadQuickReplies(localization: .en)
        let writes = await repository.writeCount
        try await service.loadQuickReplies(localization: .de)
        #expect(await repository.writeCount == writes)
        #expect(service.quickReplies.map(\.title) == BuiltInQuickReply.allCases.map { $0.title(in: .en) })
    }

    @Test("Her own replies are added, edited and deleted, and the list stays in order")
    func ownReplies() async throws {
        let (service, _) = make()
        try await service.loadQuickReplies(localization: .en)
        let mine = QuickReply(id: UUID(), builtInKey: nil, title: "Mine", text: "Hi {name}", position: 6,
            updatedAt: now)
        try await service.saveQuickReply(mine)
        #expect(service.quickReplies.map(\.title).last == "Mine" && service.quickReplies.count == 7)

        var edited = mine
        edited.text = "Hello {name}"
        try await service.saveQuickReply(edited)
        #expect(service.quickReplies.last?.text == "Hello {name}" && service.quickReplies.count == 7)

        try await service.deleteQuickReply(id: mine.id)
        #expect(service.quickReplies.count == 6)
    }

    @Test("Several replies are saved together and listed by their new positions")
    func reorder() async throws {
        let (service, _) = make()
        try await service.loadQuickReplies(localization: .en)
        var replies = service.quickReplies
        replies.reverse()
        for index in replies.indices { replies[index].position = index }
        try await service.saveQuickReplies(replies)
        #expect(service.quickReplies.map(\.id) == replies.map(\.id))
    }

    @Test("A failed reply write changes nothing")
    func replyFailure() async throws {
        let (service, repository) = make()
        try await service.loadQuickReplies(localization: .en)
        await repository.setFailsWrites(true)
        let mine = QuickReply(id: UUID(), builtInKey: nil, title: "Mine", text: "Hi", position: 6, updatedAt: now)
        await #expect(throws: FakeBookingSetupRepository.Failure.self) { try await service.saveQuickReply(mine) }
        #expect(service.quickReplies.count == 6)
    }

    // MARK: - Clearing

    @Test("Clearing forgets everything so the next account starts clean")
    func clear() async throws {
        let (service, repository) = make()
        var setup = BookingSetup.starter(now: now)
        setup.slug = "maria"
        await repository.seed(availability: makeAvailability(weekdays: [3]), setup: setup)
        try await service.load(timeZoneID: "UTC")
        try await service.loadQuickReplies(localization: .en)
        service.clear()
        #expect(!service.hasLoaded && service.setup.slug == nil && service.quickReplies.isEmpty)
        #expect(service.isStarterAvailability)
    }
}
