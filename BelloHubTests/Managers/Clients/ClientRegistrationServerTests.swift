//
//  ClientRegistrationServerTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// D42 with the server as the authority: a new client is saved only after `reserveRegistrations` counted her; the
/// vault ledger and the last server count are the cache; offline, the claim waits in the outbound queue and is
/// replayed; the 11th client without a plan meets the paywall whichever side knows it first.
@MainActor
@Suite("ClientRegistrationService: server count")
struct ClientRegistrationServerTests {
    private func make(_ rig: InboxRig) -> ClientRegistrationService {
        ClientRegistrationService(vault: rig.vault, server: rig.repository, queue: rig.queue)
    }

    private func savedCount(_ rig: InboxRig) async throws -> Int {
        try await #require(rig.vault.repository).allClients().count
    }

    @Test("The server counts the new client before she is saved")
    func serverCounts() async throws {
        let rig = InboxRig(repository: FakeInboxRepository())
        defer { rig.cleanUp() }
        await rig.start()
        let service = make(rig)
        let ana = makeClient(name: "Ana Costa")

        #expect(try await service.register(ana) == .registered)

        #expect(await rig.repository.registered == [ana.id])
        #expect(await rig.repository.writes.contains("reserveRegistrations:1"))
        #expect(service.serverCount == 1)
        #expect(try await savedCount(rig) == 1)
    }

    @Test("Ten clients counted elsewhere (bookings from the link): the 11th here meets the paywall and is not saved")
    func serverSaysPaywall() async throws {
        let rig = InboxRig(repository: FakeInboxRepository())
        defer { rig.cleanUp() }
        await rig.start()
        await rig.repository.preRegister((0..<10).map { _ in UUID() })
        let service = make(rig)

        #expect(try await service.register(makeClient(name: "Bea Lima")) == .needsSubscription)

        #expect(try await savedCount(rig) == 0)
        #expect(service.usage.used == 10)
        #expect(service.usage.isFreeAllowanceUsed)
    }

    @Test("Once the cache knows the limit is reached, the server is not even asked")
    func cacheAnswersFirst() async throws {
        let rig = InboxRig(repository: FakeInboxRepository())
        defer { rig.cleanUp() }
        await rig.start()
        let service = make(rig)
        for index in 1...10 {
            #expect(try await service.register(makeClient(name: "Client \(index)")) == .registered)
        }
        let callsBefore = await rig.repository.writes.count

        #expect(try await service.register(makeClient(name: "Client 11")) == .needsSubscription)

        #expect(await rig.repository.writes.count == callsBefore)
    }

    @Test("With a plan on the server the count goes on past ten")
    func planOnServer() async throws {
        let rig = InboxRig(repository: FakeInboxRepository())
        defer { rig.cleanUp() }
        await rig.start()
        await rig.repository.setServerHasPlan(true)
        await rig.repository.preRegister((0..<10).map { _ in UUID() })
        let subscription = FakeSubscriptionStatus(hasActivePlan: true)
        let service = ClientRegistrationService(
            vault: rig.vault, subscription: subscription, server: rig.repository, queue: rig.queue
        )

        #expect(try await service.register(makeClient(name: "Client 11")) == .registered)
        #expect(service.serverCount == 11)
    }

    @Test("Offline: saved on the cache's word, the claim waits in the queue and the server counts it later")
    func offlineReplay() async throws {
        let rig = InboxRig(repository: FakeInboxRepository())
        defer { rig.cleanUp() }
        await rig.start()
        await rig.repository.setWriteFailure(.unreachable)
        let service = make(rig)
        let ana = makeClient(name: "Ana Costa")

        #expect(try await service.register(ana) == .registered)

        #expect(try await savedCount(rig) == 1)
        let queue = rig.queue
        #expect(await Wait.untilMain { !queue.pending.isEmpty && !queue.isFlushing })
        #expect(queue.pending.map(\.kind) == [.reserveRegistrations(claims: [RegistrationClaim(ana)])])

        await rig.repository.setWriteFailure(nil)
        await queue.flushAsync()

        #expect(queue.pending.isEmpty)
        #expect(await rig.repository.registered == [ana.id])
        #expect(await Wait.untilMain { service.serverCount == 1 })
    }

    @Test("A server that refuses the call for good (no account, a refused token) leaves the cache's word")
    func permanentFailureFallsBack() async throws {
        let rig = InboxRig(repository: FakeInboxRepository())
        defer { rig.cleanUp() }
        await rig.start()
        await rig.repository.setWriteFailure(.unauthenticated)
        let service = make(rig)

        #expect(try await service.register(makeClient(name: "Ana Costa")) == .registered)
        #expect(rig.queue.pending.isEmpty)
    }

    @Test("An import takes what the server allows: 8 counted elsewhere, 5 imported, 2 saved and 3 blocked")
    func importUsesServer() async throws {
        let rig = InboxRig(repository: FakeInboxRepository())
        defer { rig.cleanUp() }
        await rig.start()
        await rig.repository.preRegister((0..<8).map { _ in UUID() })
        let service = make(rig)
        let clients = (1...5).map { makeClient(name: "Imported \($0)") }

        let result = try await service.importClients(clients)

        #expect(result.registered == 2)
        #expect(result.blocked == 3)
        #expect(try await savedCount(rig) == 2)
    }

    @Test("The claim carries the phone so the same person is never counted twice")
    func claimCarriesPhone() {
        var client = makeClient(name: "Ana Costa")
        client.phoneE164 = " +5511981234410 "
        #expect(RegistrationClaim(client).phone == "+5511981234410")
        client.phoneE164 = "   "
        #expect(RegistrationClaim(client).phone == nil)
    }
}
