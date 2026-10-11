//
//  URLSessionFirestoreClient.swift
//  BelloHub
//

import Foundation

/// Reads the owner's documents over the Firestore REST API with her ID token (the rules in `firebase/firestore.rules`
/// apply as they would to the SDK). Only reads: every write of the app goes through a callable function.
struct URLSessionFirestoreClient: FirestoreClient {
    private let config: ServerConfig
    private let tokens: any IDTokenProviding
    private let transport: any HTTPTransport

    init(
        config: ServerConfig = .current,
        tokens: any IDTokenProviding,
        transport: any HTTPTransport = URLSessionTransport()
    ) {
        self.config = config
        self.tokens = tokens
        self.transport = transport
    }

    func query(
        collection: String, ownerField: String, uid: String, since: FirestoreSince?, limit: Int
    ) async throws -> [Data] {
        // `documents:runQuery` is one path segment with a colon, not a component of its own.
        guard let url = URL(string: config.firestoreDocumentsURL.absoluteString + ":runQuery") else {
            throw ServerError.unexpected(code: "URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try Self.queryBody(
            collection: collection, ownerField: ownerField, uid: uid, since: since, limit: limit
        )
        return try await send(request)
    }

    func list(path: String, limit: Int) async throws -> [Data] {
        var url = config.firestoreDocumentsURL.appending(path: path)
        url.append(queryItems: [URLQueryItem(name: "pageSize", value: String(limit))])
        return try await send(URLRequest(url: url))
    }

    func document(path: String) async throws -> Data? {
        let (body, status) = try await answer(URLRequest(url: config.firestoreDocumentsURL.appending(path: path)))
        // Firestore says 404 for a missing document and 403 when the rules refuse a read of a missing one.
        if status == 404 || status == 403 { return nil }
        if let failure = CallableErrorMapper.error(httpStatus: status, body: body) { throw failure }
        guard let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { return nil }
        return FirestoreDocumentDecoder.data(fromDocument: object)
    }

    // MARK: - Wire shape

    /// The `structuredQuery` of `runQuery`: owner filter, optional lower bound on `since.field` (ordered by it, which
    /// the composite index of `bookings` supports), and a limit.
    static func queryBody(
        collection: String, ownerField: String, uid: String, since: FirestoreSince?, limit: Int
    ) throws -> Data {
        var filters: [[String: Any]] = [
            ["fieldFilter": ["field": ["fieldPath": ownerField], "op": "EQUAL", "value": ["stringValue": uid]]]
        ]
        var query: [String: Any] = ["from": [["collectionId": collection]], "limit": limit]
        if let since {
            filters.append([
                "fieldFilter": [
                    "field": ["fieldPath": since.field], "op": "GREATER_THAN_OR_EQUAL",
                    "value": ["timestampValue": CallableJSON.instant(since.date)]
                ]
            ])
            query["orderBy"] = [["field": ["fieldPath": since.field], "direction": "ASCENDING"]]
        }
        query["where"] = ["compositeFilter": ["op": "AND", "filters": filters]]
        return try JSONSerialization.data(withJSONObject: ["structuredQuery": query], options: [.sortedKeys])
    }

    private func send(_ request: URLRequest) async throws -> [Data] {
        let (body, status) = try await answer(request)
        if let failure = CallableErrorMapper.error(httpStatus: status, body: body) { throw failure }
        return FirestoreDocumentDecoder.documents(fromResponse: body)
    }

    private func answer(_ request: URLRequest) async throws -> (body: Data, status: Int) {
        var request = request
        let token = try await tokens.idToken()
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let body: Data
        let status: Int
        do {
            let (responseBody, response) = try await transport.send(request)
            body = responseBody
            status = response.statusCode
        } catch {
            throw CallableErrorMapper.error(transport: error)
        }
        return (body, status)
    }
}
