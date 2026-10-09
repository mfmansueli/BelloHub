//
//  RepositoryBookingSetupContractTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// What storing the booking setup must do in every vault implementation: her availability, the page switches with the
/// two policies and the chosen address, and her quick replies. Run against both flavors, like the other contract
/// suites, so the in-memory repository can never promise something the real one does not.
@Suite("Repository contract: booking setup", .serialized)
struct RepositoryBookingSetupContractTests {
    private let fixture = ContractFixture()

    private func reply(_ title: String, position: Int, builtIn: String? = nil) -> QuickReply {
        QuickReply(
            id: UUID(), builtInKey: builtIn, title: title, text: "Hi {name}, \(title)", position: position,
            updatedAt: fixture.clock.now
        )
    }

    // MARK: - Availability

    @Test("There is no availability until one is stored", arguments: RepositoryFlavor.allCases)
    func noAvailability(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        #expect(try await repository.availability() == nil)
    }

    @Test("Availability comes back exactly as stored: hours, breaks, days off, buffer, notice, window and zone",
          arguments: RepositoryFlavor.allCases)
    func availabilityRoundTrip(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        var settings = makeAvailability(timeZoneID: "Europe/Lisbon", bufferMinutes: 20, minNoticeHours: 4,
            maxDaysAhead: 90)
        settings.weekly.append(AvailabilityRule(weekday: 3, startMinutes: 1200, endMinutes: 1260))
        settings.breaks.append(BreakRule(weekday: 6, startMinutes: 990, endMinutes: 1005, label: "Coffee break"))
        settings.daysOff = [
            DayOff(id: UUID(), startDate: TestClock.date("2026-12-22 00:00"),
                endDate: TestClock.date("2027-01-05 00:00"), kind: .vacation),
            DayOff(id: UUID(), startDate: TestClock.date("2026-10-12 00:00"),
                endDate: TestClock.date("2026-10-12 00:00"), kind: .dayOff)
        ]

        try await repository.save(settings)

        #expect(try await repository.availability() == settings)
    }

    @Test("Saving availability again replaces it: there is one per vault", arguments: RepositoryFlavor.allCases)
    func availabilityReplaced(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        try await repository.save(makeAvailability(bufferMinutes: 10))
        let second = makeAvailability(weekdays: [2, 3], bufferMinutes: 30)
        try await repository.save(second)
        #expect(try await repository.availability() == second)
    }

    // MARK: - Booking setup

    @Test("There is no booking setup until one is stored", arguments: RepositoryFlavor.allCases)
    func noSetup(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        #expect(try await repository.bookingSetup() == nil)
    }

    @Test("The page switches, both policies and the address come back as stored, stamped with the clock",
          arguments: RepositoryFlavor.allCases)
    func setupRoundTrip(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        var setup = BookingSetup.starter(now: TestClock.days(-3))
        setup.page = BookingPageSettings(
            acceptingBookings: false, pausedUntil: TestClock.date("2026-10-20 00:00"), confirmNewClients: true,
            maxGuests: 2
        )
        setup.cancellation = CancellationPolicy(
            freeWindowHours: 48, clientCanReschedule: false, maxReschedules: nil, afterWindowCancel: .message,
            afterWindowReschedule: .message, askConfirmation: true, graceMinutes: 20
        )
        setup.noShow = NoShowPolicy(isOn: true, limit: 5, action: .pauseOnline, lateCancelCounts: true,
            countingMonths: 6)
        setup.slug = "maria-beauty"

        try await repository.save(setup)

        let stored = try #require(try await repository.bookingSetup())
        #expect(stored.page == setup.page && stored.cancellation == setup.cancellation && stored.noShow == setup.noShow)
        #expect(stored.slug == "maria-beauty")
        #expect(stored.updatedAt == fixture.clock.now)
    }

    @Test("A second save replaces the first: there is one booking setup per vault",
        arguments: RepositoryFlavor.allCases)
    func setupReplaced(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        var setup = BookingSetup.starter(now: fixture.clock.now)
        setup.slug = "first"
        try await repository.save(setup)
        fixture.clock.advance(by: 60)
        setup.slug = "second"
        try await repository.save(setup)
        let stored = try #require(try await repository.bookingSetup())
        #expect(stored.slug == "second" && stored.updatedAt == fixture.clock.now)
    }

    @Test("A setup with no address and the standard policies round-trips", arguments: RepositoryFlavor.allCases)
    func starterRoundTrip(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        try await repository.save(BookingSetup.starter(now: fixture.clock.now))
        let stored = try #require(try await repository.bookingSetup())
        #expect(stored.slug == nil && stored.page == .standard)
        #expect(stored.cancellation == .standard && stored.noShow == .standard)
    }

    // MARK: - Quick replies

    @Test("There are no quick replies until some are stored", arguments: RepositoryFlavor.allCases)
    func noReplies(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        #expect(try await repository.quickReplies().isEmpty)
    }

    @Test("Quick replies are listed in the order she keeps them", arguments: RepositoryFlavor.allCases)
    func repliesOrder(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        let first = reply("Confirm", position: 0, builtIn: "confirm")
        let second = reply("Late", position: 1, builtIn: "late")
        let third = reply("Mine", position: 2)
        try await repository.save([third, first, second])
        #expect(try await repository.quickReplies().map(\.title) == ["Confirm", "Late", "Mine"])
        #expect(try await repository.quickReplies().first?.builtInKey == "confirm")
    }

    @Test("Several replies are stored together and a reorder renumbers them", arguments: RepositoryFlavor.allCases)
    func repliesReorder(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        var items = [reply("A", position: 0), reply("B", position: 1), reply("C", position: 2)]
        try await repository.save(items)
        items = [items[2], items[0], items[1]]
        for index in items.indices { items[index].position = index }
        try await repository.save(items)
        #expect(try await repository.quickReplies().map(\.title) == ["C", "A", "B"])
    }

    @Test("Saving a reply replaces the one with its id", arguments: RepositoryFlavor.allCases)
    func replyReplaced(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        var item = reply("Late", position: 0)
        try await repository.save(item)
        item.text = "Hi {name}, I am 20 minutes late."
        try await repository.save(item)
        let stored = try await repository.quickReplies()
        #expect(stored.count == 1 && stored[0].text == "Hi {name}, I am 20 minutes late.")
    }

    @Test("Deleting a reply removes it; deleting it again or one that does not exist is safe",
          arguments: RepositoryFlavor.allCases)
    func replyDeleted(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        let keep = reply("Keep", position: 0)
        let drop = reply("Drop", position: 1)
        try await repository.save([keep, drop])
        try await repository.deleteQuickReply(id: drop.id)
        try await repository.deleteQuickReply(id: drop.id)
        try await repository.deleteQuickReply(id: UUID())
        #expect(try await repository.quickReplies().map(\.id) == [keep.id])
    }

    @Test("Saving no replies does nothing", arguments: RepositoryFlavor.allCases)
    func saveNone(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        try await repository.save([QuickReply]())
        #expect(try await repository.quickReplies().isEmpty)
    }

    @Test("The default replies are stored with their fixed ids, so two devices agree",
        arguments: RepositoryFlavor.allCases)
    func defaultsStable(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        let defaults = BuiltInQuickReply.allCases.map { $0.reply(in: .en, now: fixture.clock.now) }
        try await repository.save(defaults)
        try await repository.save(defaults)
        let stored = try await repository.quickReplies()
        #expect(stored.count == 6)
        #expect(stored.map(\.id) == BuiltInQuickReply.allCases.map(\.id))
    }

    // MARK: - Separation

    @Test("The booking setup is separate from the rest of the vault", arguments: RepositoryFlavor.allCases)
    func separate(flavor: RepositoryFlavor) async throws {
        let (repository, client) = try fixture.seeded(flavor)
        try await repository.save(client)
        try await repository.save(makeAvailability())
        try await repository.save(BookingSetup.starter(now: fixture.clock.now))
        try await repository.save(reply("Mine", position: 0))
        #expect(try await repository.allClients().count == 1)
        #expect(try await repository.registrationLedger().count == 1)
        #expect(try await repository.tags().isEmpty)
        #expect(try await repository.profile() == nil)
    }
}
