//
//  PublishingServiceFailureTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("PublishingService: failures, stopping and resuming")
@MainActor
struct PublishingServiceFailureTests {
    private let userID = PublishingRig.userID

    private func make(inputs: PublishInputs = makePublishInputs()) -> PublishingRig {
        PublishingRig(inputs: inputs)
    }

    // MARK: - Failing honestly

    @Test("An address somebody else owns is reported and not retried")
    func addressTaken() async {
        let rig = make()
        defer { rig.cleanUp() }
        await rig.repository.script("claimSlug", failures: [.slugTaken])
        rig.service.start(userID: userID)
        await rig.service.goOnlineAsync()
        #expect(rig.service.state == .error(.addressTaken, wasOnline: false))
        try? await Task.sleep(for: .milliseconds(60))
        #expect(await rig.repository.calls.filter { $0.hasPrefix("claimSlug") }.count == 1)
        #expect(await rig.repository.profiles.isEmpty)
        // She picks another one and it goes through.
        rig.source.update { $0.setup.slug = "maria-silva" }
        rig.source.fireChange()
        #expect(await Wait.untilMain { rig.service.state == .online })
    }

    @Test("Offline before the page exists: an honest error, then it retries by itself")
    func offlineFirst() async {
        let rig = make()
        defer { rig.cleanUp() }
        await rig.repository.script("publishProfile", failures: [.unreachable, .unreachable])
        rig.service.start(userID: userID)
        let first = Task { await rig.service.goOnlineAsync() }
        await first.value
        #expect(await Wait.untilMain { rig.service.state == .online })
        let profileCalls = await rig.repository.calls.filter { $0 == "publishProfile" }
        #expect(profileCalls.count == 3)
        #expect(await rig.repository.profiles.count == 1)
    }

    @Test("Offline with a page already online keeps the link live and says the changes are waiting")
    func offlineLive() async {
        let rig = make()
        defer { rig.cleanUp() }
        rig.service.start(userID: userID)
        await rig.service.goOnlineAsync()
        // The retry timer must not fire while the test looks at the error state.
        let held = PublishingService(
            repository: rig.repository, source: rig.source, defaults: rig.defaults, now: { TestClock.now },
            debounce: .zero, retryDelays: [.seconds(3_600)],
            sleeper: { _ in try await Task.sleep(for: .seconds(3_600)) }
        )
        held.start(userID: userID)
        await rig.repository.setFailure(.unreachable)
        rig.source.update { $0.availability.bufferMinutes = 20 }
        await held.retryAsync()
        #expect(held.state == .error(.offline, wasOnline: true))
        #expect(held.state.isLive)
        await rig.repository.setFailure(nil)
        await held.retryAsync()
        #expect(held.state == .online)
        held.clear()
    }

    @Test("Failures map to what the screens explain", arguments: [
        (BookingRepositoryError.unreachable, PublishFailure.offline),
        (.busy, .busy),
        (.unauthenticated, .signedOut),
        (.slugTaken, .addressTaken),
        (.slugInvalid, .rejected),
        (.rejected, .rejected),
        (.notPublishedYet, .offline)
    ])
    func failureMapping(error: BookingRepositoryError, expected: PublishFailure) {
        #expect(PublishingService.failure(for: error) == expected)
    }

    @Test("Other errors map too: the vault, the source and the server")
    func otherErrors() {
        #expect(PublishingService.failure(for: VaultError.locked) == .locked)
        #expect(PublishingService.failure(for: PublishSourceError.locked) == .locked)
        #expect(PublishingService.failure(for: PublishSourceError.noProfile) == .rejected)
        #expect(PublishingService.failure(for: ServerError.network) == .offline)
        #expect(PublishingService.failure(for: ServerError.unavailable) == .busy)
        #expect(PublishingService.failure(for: ServerError.unauthenticated) == .signedOut)
        #expect(PublishingService.failure(for: ServerError.slugTaken) == .addressTaken)
        struct Unknown: Error {}
        #expect(PublishingService.failure(for: Unknown()) == .rejected)
    }

    @Test("Only offline, busy and locked are retried by themselves")
    func retryable() {
        let retried: Set<PublishFailure> = [.offline, .busy, .locked]
        for failure in PublishFailure.allCasesForTests {
            #expect(failure.isRetryable == retried.contains(failure))
        }
    }

    @Test("A signed-out token is reported and not retried; the next change tries again")
    func signedOut() async {
        let rig = make()
        defer { rig.cleanUp() }
        await rig.repository.script("ensureAccount", failures: [.unauthenticated])
        rig.service.start(userID: userID)
        await rig.service.goOnlineAsync()
        #expect(rig.service.state == .error(.signedOut, wasOnline: false))
        try? await Task.sleep(for: .milliseconds(60))
        #expect(await rig.repository.calls.filter { $0.hasPrefix("ensureAccount") }.count == 1)
        rig.source.fireChange()
        #expect(await Wait.untilMain { rig.service.state == .online })
    }

    @Test("A locked vault is reported and retried")
    func locked() async {
        let rig = make()
        defer { rig.cleanUp() }
        rig.source.error = PublishSourceError.locked
        rig.service.start(userID: userID)
        let attempt = Task { await rig.service.goOnlineAsync() }
        await attempt.value
        #expect(await Wait.untilMain { rig.source.readCount >= 3 })
        rig.source.error = nil
        #expect(await Wait.untilMain { rig.service.state == .online })
    }

    // MARK: - Stopping, clearing, resuming

    @Test("Stopping publishes the page as not taking bookings, forgets the choice and stops publishing changes")
    func stop() async {
        let rig = make()
        defer { rig.cleanUp() }
        rig.service.start(userID: userID)
        await rig.service.goOnlineAsync()
        let stopped = await rig.service.stop()
        #expect(stopped)
        #expect(rig.service.state == .notOnline && !rig.service.state.isLive)
        #expect(await rig.repository.profiles.last?.profile.booking.acceptingBookings == false)
        #expect(rig.defaults.string(forKey: DefaultsKey.publishingOnlineUserID) == nil)

        let published = await rig.repository.profiles.count
        rig.source.update { $0.availability.bufferMinutes = 5 }
        rig.source.fireChange()
        try? await Task.sleep(for: .milliseconds(80))
        #expect(await rig.repository.profiles.count == published)
        #expect(await rig.repository.availabilities.count == 1)
    }

    @Test("Stopping a page that was never online needs no server")
    func stopNeverOnline() async {
        let rig = make()
        defer { rig.cleanUp() }
        rig.service.start(userID: userID)
        #expect(await rig.service.stop())
        #expect(await rig.repository.calls.isEmpty)
    }

    @Test("If stopping fails the page stays online and the choice is kept")
    func stopFails() async {
        let rig = make()
        defer { rig.cleanUp() }
        rig.service.start(userID: userID)
        await rig.service.goOnlineAsync()
        await rig.repository.setFailure(.unreachable)
        #expect(await rig.service.stop() == false)
        #expect(rig.service.state == .error(.offline, wasOnline: true))
        #expect(rig.defaults.string(forKey: DefaultsKey.publishingOnlineUserID) == userID)
    }

    @Test("Clearing (lock) forgets the session but not her choice; starting again resumes")
    func clearAndResume() async {
        let rig = make()
        defer { rig.cleanUp() }
        rig.service.start(userID: userID)
        await rig.service.goOnlineAsync()
        rig.service.clear()
        #expect(rig.service.state == .notOnline && rig.service.account == nil)
        #expect(rig.defaults.string(forKey: DefaultsKey.publishingOnlineUserID) == userID)

        rig.service.start(userID: userID)
        #expect(rig.service.state == .publishing(wasOnline: true))
        #expect(await Wait.untilMain { rig.source.subscriptions == 2 })
        rig.source.update { $0.availability.bufferMinutes = 25 }
        rig.source.fireChange()
        #expect(await Wait.untilMain { rig.service.state == .online })
        #expect(await rig.repository.availabilities.last?.bufferMinutes == 25)
    }

    @Test("Signing out forgets that she was online, only for that user")
    func signOut() async {
        let rig = make()
        defer { rig.cleanUp() }
        rig.service.start(userID: userID)
        await rig.service.goOnlineAsync()
        rig.service.clearForSignOut(userID: "somebody-else")
        #expect(rig.defaults.string(forKey: DefaultsKey.publishingOnlineUserID) == userID)
        rig.service.clearForSignOut(userID: userID)
        #expect(rig.defaults.string(forKey: DefaultsKey.publishingOnlineUserID) == nil)
        rig.service.start(userID: userID)
        #expect(rig.service.state == .notOnline)
    }

    @Test("A different user on the same phone does not inherit the page")
    func otherUser() async {
        let rig = make()
        defer { rig.cleanUp() }
        rig.service.start(userID: userID)
        await rig.service.goOnlineAsync()
        rig.service.start(userID: "user-2")
        #expect(rig.service.state == .notOnline)
        rig.source.fireChange()
        try? await Task.sleep(for: .milliseconds(60))
        #expect(await rig.repository.profiles.count == 1)
    }
}
