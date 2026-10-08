//
//  SyncEventSource.swift
//  BelloHub
//

/// Where sync steps come from: CloudKit in the app, a fake in tests.
protocol SyncEventSource: Sendable {
    func events() -> AsyncStream<SyncEvent>
}
