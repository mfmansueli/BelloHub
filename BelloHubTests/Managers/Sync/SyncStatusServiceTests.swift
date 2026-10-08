//
//  SyncStatusServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import CloudKit
import Foundation
import Testing

/// A source the test feeds by hand.
final class FakeSyncSource: SyncEventSource, Sendable {
    private let continuation: AsyncStream<SyncEvent>.Continuation
    private let stream: AsyncStream<SyncEvent>

    init() {
        (stream, continuation) = AsyncStream.makeStream(of: SyncEvent.self)
    }

    func events() -> AsyncStream<SyncEvent> { stream }
    func send(_ event: SyncEvent) { continuation.yield(event) }
}

@MainActor
@Suite("SyncStatusService")
struct SyncStatusServiceTests {
    private let now = TestClock.now

    @Test("It starts local-only, follows the events it is given, and resets when it stops listening")
    func lifecycle() async {
        let source = FakeSyncSource()
        let service = SyncStatusService(source: source)
        #expect(service.status == .localOnly)

        service.startListening()
        source.send(SyncEvent(isFinished: false, failure: nil, date: now))
        #expect(await Wait.until { await service.status == .syncing })
        source.send(SyncEvent(isFinished: true, failure: nil, date: now))
        #expect(await Wait.until { await service.status == .synced(now) })
        source.send(SyncEvent(isFinished: true, failure: .quotaExceeded, date: now))
        #expect(await Wait.until { await service.status == .iCloudFull })

        service.stopListening()
        #expect(service.status == .localOnly)
    }

    @Test("Listening twice does not duplicate the observation")
    func startTwice() async {
        let source = FakeSyncSource()
        let service = SyncStatusService(source: source)

        service.startListening()
        service.startListening()
        source.send(SyncEvent(isFinished: true, failure: nil, date: now))

        #expect(await Wait.until { await service.status == .synced(now) })
        service.stopListening()
    }

    @Test("The network monitor can mark the phone offline and bring it back to syncing")
    func offline() {
        let service = SyncStatusService(source: FakeSyncSource(), initial: .synced(now))

        service.setOffline(true)
        #expect(service.status == .offline)
        service.setOffline(false)
        #expect(service.status == .syncing)
    }

    @Test("Regaining the network never overrides a different state")
    func onlineKeepsOtherStates() {
        let service = SyncStatusService(source: FakeSyncSource(), initial: .iCloudFull)

        service.setOffline(false)

        #expect(service.status == .iCloudFull)
    }
}
