//
//  PublishingServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("PublishingService: going online and staying up to date")
@MainActor
struct PublishingServiceTests {
    private let userID = PublishingRig.userID

    private func make(inputs: PublishInputs = makePublishInputs()) -> PublishingRig {
        PublishingRig(inputs: inputs)
    }

    // MARK: - Going online

    @Test("Going online makes the account, claims the address, then publishes the page and the availability")
    func goOnline() async {
        let rig = make()
        defer { rig.cleanUp() }
        rig.service.start(userID: userID)
        #expect(rig.service.state == .notOnline)

        await rig.service.goOnlineAsync()

        #expect(rig.service.state == .online)
        #expect(await rig.repository.calls == [
            "ensureAccount:BR/pt-BR", "claimSlug:maria", "publishProfile", "publishAvailability"
        ])
        #expect(rig.service.state.isLive)
        #expect(rig.service.account?.uid == "uid")
        #expect(rig.service.lastPublishedAt == TestClock.now)
        #expect(rig.defaults.string(forKey: DefaultsKey.publishingOnlineUserID) == userID)
    }

    @Test("An address the account already owns is not claimed again")
    func addressAlreadyHers() async {
        let rig = make()
        defer { rig.cleanUp() }
        await rig.repository.setAccountSlug("maria")
        rig.service.start(userID: userID)
        await rig.service.goOnlineAsync()
        #expect(await rig.repository.claimedSlugs.isEmpty)
        #expect(rig.service.state == .online)
    }

    @Test("Without an address nothing is called and the state says what is missing")
    func needsAddress() async {
        let rig = make(inputs: makePublishInputs(slug: nil))
        defer { rig.cleanUp() }
        rig.service.start(userID: userID)
        await rig.service.goOnlineAsync()
        #expect(rig.service.state == .error(.needsAddress, wasOnline: false))
        #expect(await rig.repository.calls.isEmpty)
    }

    @Test("Without an active service the page cannot go online")
    func needsService() async {
        let rig = make(inputs: makePublishInputs(services: []))
        defer { rig.cleanUp() }
        rig.service.start(userID: userID)
        await rig.service.goOnlineAsync()
        #expect(rig.service.state == .error(.needsService, wasOnline: false))
        #expect(await rig.repository.calls.isEmpty)
    }

    @Test("Once she chose to go online, picking the missing address publishes by itself")
    func addressArrivesLater() async {
        let rig = make(inputs: makePublishInputs(slug: nil))
        defer { rig.cleanUp() }
        rig.service.start(userID: userID)
        await rig.service.goOnlineAsync()
        rig.source.update { $0.setup.slug = "maria" }
        rig.source.fireChange()
        #expect(await Wait.untilMain { rig.service.state == .online })
        #expect(await rig.repository.claimedSlugs == ["maria"])
    }

    @Test("A paused page is published as paused, with the return day")
    func paused() async {
        let back = TestClock.days(10)
        let page = BookingPause.pausing(.standard, until: back, now: TestClock.now, timeZone: TestClock.saoPaulo)
        let rig = make(inputs: makePublishInputs(page: page))
        defer { rig.cleanUp() }
        rig.service.start(userID: userID)
        await rig.service.goOnlineAsync()
        #expect(rig.service.state == .paused(until: TestClock.calendar().startOfDay(for: back)))
        #expect(rig.service.state.isLive)
    }

    // MARK: - Keeping it up to date

    @Test("A change is published once; the same payload again publishes nothing")
    func idempotent() async {
        let rig = make()
        defer { rig.cleanUp() }
        rig.service.start(userID: userID)
        await rig.service.goOnlineAsync()
        await rig.service.retryAsync()
        #expect(await rig.repository.profiles.count == 1)
        #expect(await rig.repository.availabilities.count == 1)

        rig.source.update { $0.availability.bufferMinutes = 30 }
        await rig.service.retryAsync()
        #expect(await rig.repository.profiles.count == 1)
        #expect(await rig.repository.availabilities.count == 2)
        #expect(await rig.repository.availabilities.last?.bufferMinutes == 30)

        rig.source.update { $0.setup.cancellation.freeWindowHours = 48 }
        await rig.service.retryAsync()
        #expect(await rig.repository.profiles.count == 2)
        #expect(await rig.repository.availabilities.count == 2)
    }

    @Test("A vault change after going online is picked up by itself")
    func autoPublish() async {
        let rig = make()
        defer { rig.cleanUp() }
        rig.service.start(userID: userID)
        await rig.service.goOnlineAsync()
        rig.source.update { $0.services.append(Service(name: "Peeling", durationMinutes: 30, position: 5)) }
        rig.source.fireChange()
        #expect(await Wait.untilMain { rig.service.lastPublishedAt != nil })
        let repository = rig.repository
        #expect(await Wait.until { await repository.profiles.count == 2 })
        #expect(await rig.repository.profiles.last?.profile.services.count == 2)
    }

    @Test("Changes before she went online publish nothing")
    func nothingBeforeGoOnline() async {
        let rig = make()
        defer { rig.cleanUp() }
        rig.service.start(userID: userID)
        #expect(await Wait.untilMain { rig.source.subscriptions == 1 })
        rig.source.fireChange()
        try? await Task.sleep(for: .milliseconds(100))
        #expect(await rig.repository.calls.isEmpty)
        #expect(rig.service.state == .notOnline)
    }

    @Test("Edits made during a publish queue behind it and the last one wins")
    func queued() async {
        let rig = make()
        defer { rig.cleanUp() }
        await rig.repository.setDelay(.milliseconds(60))
        rig.service.start(userID: userID)
        let first = Task { await rig.service.goOnlineAsync() }
        #expect(await Wait.untilMain { rig.service.state == .publishing(wasOnline: false) })
        rig.source.update { $0.availability.bufferMinutes = 45 }
        rig.source.fireChange()
        await first.value
        let repository = rig.repository
        #expect(await Wait.until { await repository.availabilities.last?.bufferMinutes == 45 })
        let calls = await rig.repository.calls
        // One account, one claim; the profile is built from the same inputs both times, so it goes out once.
        #expect(calls.filter { $0 == "ensureAccount:BR/pt-BR" }.count == 1)
        #expect(calls.filter { $0.hasPrefix("claimSlug") }.count == 1)
        #expect(await rig.repository.profiles.count == 1)
        #expect(rig.service.state == .online)
    }

    @Test("Choosing another address claims it before the page is republished")
    func newAddress() async {
        let rig = make()
        defer { rig.cleanUp() }
        rig.service.start(userID: userID)
        await rig.service.goOnlineAsync()
        rig.source.update { $0.setup.slug = "maria-silva" }
        await rig.service.retryAsync()
        #expect(await rig.repository.claimedSlugs == ["maria", "maria-silva"])
        let calls = await rig.repository.calls
        // The old page goes away with the old address, so the page is published again; the hours are untouched.
        #expect(calls.suffix(2) == ["claimSlug:maria-silva", "publishProfile"])
        #expect(await rig.repository.availabilities.count == 1)
    }
}
