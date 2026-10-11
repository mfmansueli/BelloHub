//
//  ClientDataDeletionServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// Deleting a client's data (D30): the vault forgets her at once, and the server is told through the outbound queue,
/// so the request survives being offline and a relaunch.
@MainActor
@Suite("ClientDataDeletionService")
struct ClientDataDeletionServiceTests {
    private static let phone = "+5511981234410"

    private func seed(_ rig: InboxRig, bookingIDs: [String] = ["bk-1", "bk-2"]) async throws -> UUID {
        let repository = try #require(rig.vault.repository)
        var client = makeClient(name: "Ana Costa")
        client.phoneE164 = Self.phone
        _ = try await repository.save(client)
        for (index, bookingID) in bookingIDs.enumerated() {
            var visit = makeAppointment(clientID: client.id, daysFromNow: index + 1, status: .confirmed)
            visit.bookingID = bookingID
            try await repository.save(visit)
        }
        try await repository.save(makeAppointment(clientID: client.id, daysFromNow: -3))
        return client.id
    }

    @Test("The phone forgets her at once and the server is asked with her phone and her booking ids")
    func deletesEverywhere() async throws {
        let rig = InboxRig(repository: FakeInboxRepository())
        defer { rig.cleanUp() }
        await rig.start()
        let clientID = try await seed(rig)
        let service = ClientDataDeletionService(vault: rig.vault, queue: rig.queue)

        try await service.deleteClientData(clientID: clientID)

        let repository = try #require(rig.vault.repository)
        #expect(try await repository.client(id: clientID) == nil)
        #expect(try await repository.appointments(for: clientID).isEmpty)
        let server = rig.repository
        let expected = "deleteClientServerData:\(Self.phone):bk-1,bk-2"
        #expect(await Wait.until { await server.writes == [expected] })
        #expect(await Wait.untilMain { rig.queue.pending.isEmpty })
    }

    @Test("Offline, the server deletion waits in the queue, survives a relaunch and is sent when the server answers")
    func offlineReplay() async throws {
        let rig = InboxRig(repository: FakeInboxRepository())
        defer { rig.cleanUp() }
        await rig.start()
        await rig.repository.setWriteFailure(.unreachable)
        let clientID = try await seed(rig, bookingIDs: ["bk-9"])
        let service = ClientDataDeletionService(vault: rig.vault, queue: rig.queue)

        try await service.deleteClientData(clientID: clientID)

        let queue = rig.queue
        #expect(await Wait.untilMain { queue.waitingOn == .unreachable && !queue.isFlushing })
        #expect(queue.pending.map(\.kind) == [.deleteClientServerData(phone: Self.phone, bookingIds: ["bk-9"])])

        rig.sync.stopListening()
        await rig.repository.setWriteFailure(nil)
        let relaunched = OutboundQueue(
            repository: rig.repository, defaults: rig.defaults, now: { TestClock.now }, retryDelays: [.seconds(600)]
        )
        relaunched.start(userID: InboxRig.userID)
        defer { relaunched.stop() }
        let server = rig.repository
        #expect(await Wait.until { await server.writes == ["deleteClientServerData:\(Self.phone):bk-9"] })
    }

    @Test("A client with no phone and no online booking needs nothing from the server")
    func nothingToSend() async throws {
        let rig = InboxRig(repository: FakeInboxRepository())
        defer { rig.cleanUp() }
        await rig.start()
        let repository = try #require(rig.vault.repository)
        let client = makeClient(name: "Bea Lima")
        _ = try await repository.save(client)
        let service = ClientDataDeletionService(vault: rig.vault, queue: rig.queue)

        try await service.deleteClientData(clientID: client.id)

        #expect(try await repository.client(id: client.id) == nil)
        #expect(rig.queue.pending.isEmpty)
        #expect(await rig.repository.writes.isEmpty)
    }

    @Test("With no vault nothing is deleted and nothing is queued")
    func noVault() async {
        let rig = InboxRig(repository: FakeInboxRepository())
        defer { rig.cleanUp() }
        let service = ClientDataDeletionService(vault: VaultService(repository: nil), queue: rig.queue)

        await #expect(throws: VaultRepositoryError.unavailable) { try await service.deleteClientData(clientID: UUID()) }
        #expect(rig.queue.pending.isEmpty)
    }
}
