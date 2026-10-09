//
//  URLSessionTransport.swift
//  BelloHub
//

import Foundation

/// The real transport: an ephemeral `URLSession` (no cookies, no disk cache: nothing about her page or her calls is
/// worth keeping on disk).
struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    init(timeout: TimeInterval = 20) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}
