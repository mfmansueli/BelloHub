//
//  FakeHTTPTransport.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import os

/// One scripted HTTP answer, or a thrown error, and the requests it saw. No network.
final class FakeHTTPTransport: HTTPTransport, Sendable {
    private struct State {
        var requests: [URLRequest] = []
        var status = 200
        var body = Data(#"{"result":{}}"#.utf8)
        var error: (any Error)?
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    var requests: [URLRequest] { state.withLock { $0.requests } }

    func respond(status: Int, body: String) {
        state.withLock {
            $0.status = status
            $0.body = Data(body.utf8)
            $0.error = nil
        }
    }

    func fail(with error: any Error) {
        state.withLock { $0.error = error }
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let outcome = state.withLock { state -> State in
            state.requests.append(request)
            return state
        }
        if let error = outcome.error { throw error }
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: outcome.status, httpVersion: nil, headerFields: nil)
        else { throw URLError(.badServerResponse) }
        return (outcome.body, response)
    }
}
