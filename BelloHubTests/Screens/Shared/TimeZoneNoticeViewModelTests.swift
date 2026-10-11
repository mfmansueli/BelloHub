//
//  TimeZoneNoticeViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// tz-mismatch-notice: the owners' business is in São Paulo while their iPhone is in Rome. The notice says so, and only
/// her tap changes the business zone; her hours keep their wall-clock meaning and the page publishes the new zone.
@MainActor
@Suite("TimeZoneNoticeViewModel")
struct TimeZoneNoticeViewModelTests {
    private struct World {
        let repository: InMemoryClientRecordRepository
        let profile: ProfileService
        let bookingSetup: BookingSetupService
        let notice: TimeZoneNoticeService
        let viewModel: TimeZoneNoticeViewModel
        let defaults: UserDefaults
        let suite: String

        func cleanUp() {
            notice.stop()
            defaults.removePersistentDomain(forName: suite)
        }
    }

    private static let dayOff = DayOff(
        id: UUID(), startDate: TestClock.date("2026-10-20 00:00"), endDate: TestClock.date("2026-10-21 00:00"),
        kind: .vacation
    )

    private func makeProfile(zone: String = "America/Sao_Paulo") -> ProfessionalProfile {
        ProfessionalProfile(
            displayName: "Maria Silva", regionCode: "BR", timeZoneID: zone, currencyCode: "BRL",
            appLocaleID: "pt-BR", bookingLocaleIDs: ["pt-BR"], createdAt: TestClock.now
        )
    }

    private func makeWorld(
        phoneZone: String = "Europe/Rome", storesHours: Bool = true, enabled: Bool = true, seedsProfile: Bool = true
    ) async throws -> World {
        let repository = InMemoryClientRecordRepository()
        if seedsProfile { try await repository.save(makeProfile()) }
        if storesHours { try await repository.save(makeAvailability(daysOff: [Self.dayOff])) }
        let profile = ProfileService(repository: repository)
        await profile.load()
        let bookingSetup = BookingSetupService(repository: repository, now: { TestClock.now })
        let suite = "test.timeZoneNoticeVM.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        let zone = MutablePhoneZone(phoneZone)
        let notice = TimeZoneNoticeService(
            defaults: defaults, regions: try RegionCatalog.loadBundled(), isEnabled: enabled,
            phoneZone: { zone.zone }
        )
        notice.start(userID: "maria")
        let viewModel = TimeZoneNoticeViewModel(notice: notice, profile: profile, bookingSetup: bookingSetup)
        return World(
            repository: repository, profile: profile, bookingSetup: bookingSetup, notice: notice,
            viewModel: viewModel, defaults: defaults, suite: suite
        )
    }

    // MARK: - Showing

    @Test("An iPhone in Rome and a business in São Paulo: the notice shows, with the region note")
    func showsForTheOwners() async throws {
        let world = try await makeWorld()
        defer { world.cleanUp() }
        let mismatch = try #require(world.viewModel.mismatch(now: TestClock.now))
        #expect(mismatch.phoneAheadMinutes == 300)
        #expect(world.viewModel.showsRegionNote(for: mismatch))
    }

    @Test("Another Brazilian zone: the notice shows without the region note")
    func sameCountry() async throws {
        let world = try await makeWorld(phoneZone: "America/Manaus")
        defer { world.cleanUp() }
        let mismatch = try #require(world.viewModel.mismatch(now: TestClock.now))
        #expect(mismatch.phoneAheadMinutes == -60)
        #expect(!world.viewModel.showsRegionNote(for: mismatch))
    }

    @Test("Nothing shows with the same hour, before her profile exists (setup), or when the notice is off")
    func hidden() async throws {
        let sameHour = try await makeWorld(phoneZone: "America/Argentina/Buenos_Aires")
        defer { sameHour.cleanUp() }
        #expect(sameHour.viewModel.mismatch(now: TestClock.now) == nil)

        let settingUp = try await makeWorld(seedsProfile: false)
        defer { settingUp.cleanUp() }
        #expect(settingUp.viewModel.mismatch(now: TestClock.now) == nil)

        let off = try await makeWorld(enabled: false)
        defer { off.cleanUp() }
        #expect(off.viewModel.mismatch(now: TestClock.now) == nil)
    }

    // MARK: - Keep it

    @Test("Keep it hides the notice and changes nothing in her business")
    func keepIt() async throws {
        let world = try await makeWorld()
        defer { world.cleanUp() }
        let mismatch = try #require(world.viewModel.mismatch(now: TestClock.now))

        world.viewModel.keep(mismatch)

        #expect(world.viewModel.mismatch(now: TestClock.now) == nil)
        #expect(try await world.repository.profile()?.timeZoneID == "America/Sao_Paulo")
        #expect(try await world.repository.availability()?.timeZoneID == "America/Sao_Paulo")
    }

    // MARK: - Use my iPhone's time zone

    @Test("Use my iPhone's time zone: the business zone becomes Rome, the hours keep their times and dates")
    func usePhoneZone() async throws {
        let world = try await makeWorld()
        defer { world.cleanUp() }
        let before = try #require(try await world.repository.availability())
        let mismatch = try #require(world.viewModel.mismatch(now: TestClock.now))

        await world.viewModel.usePhoneZoneAsync(mismatch)

        #expect(world.viewModel.errorMessage == nil)
        #expect(!world.viewModel.isSaving)
        #expect(world.profile.profile?.timeZoneID == "Europe/Rome")
        #expect(try await world.repository.profile()?.timeZoneID == "Europe/Rome")
        #expect(world.viewModel.mismatch(now: TestClock.now) == nil, "nothing left to say")

        let after = try #require(try await world.repository.availability())
        #expect(after.timeZoneID == "Europe/Rome")
        #expect(after.weekly == before.weekly && after.breaks == before.breaks, "09:00 to 19:00 stays 09:00 to 19:00")
        #expect(after.daysOff.map(\.startDate) == [TestClock.date("2026-10-20 00:00", zone: "Europe/Rome")])
        #expect(world.bookingSetup.availability == after)
    }

    @Test("After the change the page publishes Rome on both payloads, with the same hours and the same days off")
    func publishedPayloadsFollow() async throws {
        let world = try await makeWorld()
        defer { world.cleanUp() }
        var inputs = makePublishInputs()
        inputs.profile = try #require(try await world.repository.profile())
        inputs.availability = try #require(try await world.repository.availability())
        let before = PublishPayloads.availability(inputs, now: TestClock.now)

        await world.viewModel.usePhoneZoneAsync(try #require(world.viewModel.mismatch(now: TestClock.now)))

        inputs.profile = try #require(try await world.repository.profile())
        inputs.availability = try #require(try await world.repository.availability())
        let after = PublishPayloads.availability(inputs, now: TestClock.now)
        #expect(PublishPayloads.profile(inputs, now: TestClock.now).profile.timeZoneID == "Europe/Rome")
        #expect(after.timeZoneID == "Europe/Rome")
        #expect(after != before, "a changed payload is what makes the page publish again")
        #expect(after.weekly == before.weekly && after.breaks == before.breaks)
        #expect(after.daysOff == before.daysOff, "20 October stays 20 October")
    }

    @Test("Without stored hours only the profile changes; the starter follows the profile")
    func noStoredHours() async throws {
        let world = try await makeWorld(storesHours: false)
        defer { world.cleanUp() }
        await world.viewModel.usePhoneZoneAsync(try #require(world.viewModel.mismatch(now: TestClock.now)))
        #expect(try await world.repository.profile()?.timeZoneID == "Europe/Rome")
        #expect(try await world.repository.availability() == nil, "nothing is stored on her behalf")
    }

    @Test("A failed save says so and leaves the business zone as it was")
    func failedSave() async throws {
        let repository = FakeBusinessRepository()
        try await repository.save(makeProfile())
        await repository.setFailsWrites(true)
        let profile = ProfileService(repository: repository)
        await profile.load()
        let suite = "test.timeZoneNoticeVM.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defer { defaults.removePersistentDomain(forName: suite) }
        let notice = TimeZoneNoticeService(
            defaults: defaults, regions: RegionCatalog(presets: []), phoneZone: { TimeZone(identifier: "Europe/Rome") ?? .gmt }
        )
        let viewModel = TimeZoneNoticeViewModel(
            notice: notice, profile: profile,
            bookingSetup: BookingSetupService(repository: FakeBookingSetupRepository(), now: { TestClock.now })
        )
        let mismatch = try #require(viewModel.mismatch(now: TestClock.now))

        await viewModel.usePhoneZoneAsync(mismatch)

        #expect(viewModel.errorMessage != nil)
        #expect(profile.profile?.timeZoneID == "America/Sao_Paulo")
        #expect(viewModel.mismatch(now: TestClock.now) != nil, "the notice stays so she can try again")
    }

    @Test("The fire-and-forget action reaches the same end")
    func fireAndForget() async throws {
        let world = try await makeWorld()
        defer { world.cleanUp() }
        world.viewModel.usePhoneZone(try #require(world.viewModel.mismatch(now: TestClock.now)))
        #expect(await Wait.untilMain { world.profile.profile?.timeZoneID == "Europe/Rome" && !world.viewModel.isSaving })
    }
}
