//
//  SyncStatusReducerTests.swift
//  BelloHubTests
//

@testable import BelloHub
import CloudKit
import Foundation
import Testing

@Suite("SyncStatusReducer and CloudKitSyncMonitor")
struct SyncStatusReducerTests {
    private let now = TestClock.now

    @Test("A running step is syncing, a finished one is synced with its time")
    func progress() {
        let running = SyncEvent(isFinished: false, failure: nil, date: now)
        let done = SyncEvent(isFinished: true, failure: nil, date: now)

        #expect(SyncStatusReducer.reduce(.localOnly, with: running) == .syncing)
        #expect(SyncStatusReducer.reduce(.syncing, with: done) == .synced(now))
    }

    @Test("Every failure maps to the state the professional can act on",
          arguments: [(SyncFailure.notSignedIn, SyncStatus.iCloudUnavailable), (.quotaExceeded, .iCloudFull),
                      (.networkUnavailable, .offline), (.other, .error)])
    func failures(failure: SyncFailure, expected: SyncStatus) {
        let event = SyncEvent(isFinished: true, failure: failure, date: now)

        #expect(SyncStatusReducer.reduce(.synced(now), with: event) == expected)
    }

    @Test("A failure wins over progress, and recovery shows as synced again")
    func recovery() {
        let failed = SyncEvent(isFinished: false, failure: .networkUnavailable, date: now)
        let recovered = SyncEvent(isFinished: true, failure: nil, date: now.addingTimeInterval(60))

        #expect(SyncStatusReducer.reduce(.syncing, with: failed) == .offline)
        #expect(SyncStatusReducer.reduce(.offline, with: recovered) == .synced(now.addingTimeInterval(60)))
    }

    @Test("CloudKit errors map to failures: signed out, full iCloud, no network, anything else",
          arguments: [(CKError.Code.notAuthenticated, SyncFailure.notSignedIn),
                      (.accountTemporarilyUnavailable, .notSignedIn), (.quotaExceeded, .quotaExceeded),
                      (.networkUnavailable, .networkUnavailable), (.networkFailure, .networkUnavailable),
                      (.serverRecordChanged, .other), (.internalError, .other)])
    func cloudKitErrors(code: CKError.Code, expected: SyncFailure) {
        #expect(CloudKitSyncMonitor.failure(for: CKError(code)) == expected)
    }

    @Test("An error that is not from CloudKit is a generic failure")
    func foreignError() {
        #expect(CloudKitSyncMonitor.failure(for: CocoaError(.fileReadUnknown)) == .other)
    }

    @Test("A notification without an end date is a step still running")
    func monitorMapping() {
        #expect(CloudKitSyncMonitor.map(finishedAt: nil, error: nil).isFinished == false)
        let finished = SyncEvent(isFinished: true, failure: nil, date: now)

        #expect(CloudKitSyncMonitor.map(finishedAt: now, error: nil) == finished)
        #expect(CloudKitSyncMonitor.map(finishedAt: now, error: CKError(.quotaExceeded)).failure == .quotaExceeded)
    }
}
