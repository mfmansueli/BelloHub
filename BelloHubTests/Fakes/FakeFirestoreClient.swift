//
//  FakeFirestoreClient.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import os

/// Her Firestore documents in a test, already in the plain JSON `FirestoreDocumentDecoder` produces. A query honours
/// the `since` bound, orders by it and stops at `limit`, like the REST `runQuery` the app sends; each query is kept.
final class FakeFirestoreClient: FirestoreClient, Sendable {
    struct Row: Sendable {
        let id: String
        let startsAt: Date
        let json: Data
    }

    private struct State {
        var rows: [String: [Row]] = [:]
        var queries: [Date?] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    /// The `since` of each query, in order.
    var queries: [Date?] { state.withLock { $0.queries } }

    func set(_ collection: String, rows: [Row]) {
        state.withLock { $0.rows[collection] = rows }
    }

    func query(
        collection: String, ownerField: String, uid: String, since: FirestoreSince?, limit: Int
    ) async throws -> [Data] {
        state.withLock { state in
            state.queries.append(since?.date)
            let rows = (state.rows[collection] ?? [])
                .filter { row in since.map { row.startsAt >= $0.date } ?? true }
                .sorted { ($0.startsAt, $0.id) < ($1.startsAt, $1.id) }
            return rows.prefix(limit).map(\.json)
        }
    }

    func list(path: String, limit: Int) async throws -> [Data] { [] }

    func document(path: String) async throws -> Data? {
        let parts = path.split(separator: "/").map(String.init)
        guard parts.count == 2 else { return nil }
        return state.withLock { $0.rows[parts[0]]?.first { $0.id == parts[1] }?.json }
    }
}
