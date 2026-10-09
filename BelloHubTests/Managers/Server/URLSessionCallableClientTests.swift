//
//  URLSessionCallableClientTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("URLSessionCallableClient")
struct URLSessionCallableClientTests {
    private struct Tokens: IDTokenProviding {
        var token: String? = "firebase-token"

        func idToken() async throws -> String {
            guard let token else { throw ServerError.unauthenticated }
            return token
        }
    }

    private struct Ping: Codable, Equatable {
        let value: Int
    }

    private let config = ServerConfig(info: [
        ServerConfig.functionsKey: "https://europe-west1-demo.cloudfunctions.net",
        ServerConfig.webKey: "https://demo.web.app"
    ])

    private func make(
        _ transport: FakeHTTPTransport, tokens: Tokens = Tokens()
    ) -> URLSessionCallableClient {
        URLSessionCallableClient(config: config, tokens: tokens, transport: transport)
    }

    @Test("A call is a POST of {data} to the function with the bearer token")
    func requestShape() async throws {
        let transport = FakeHTTPTransport()
        transport.respond(status: 200, body: #"{"result":{"value":7}}"#)
        let answer: Ping = try await make(transport).call("ping", Ping(value: 3))
        #expect(answer == Ping(value: 7))

        let request = try #require(transport.requests.first)
        #expect(request.url?.absoluteString == "https://europe-west1-demo.cloudfunctions.net/ping")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer firebase-token")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try #require(request.httpBody)
        #expect(String(bytes: body, encoding: .utf8) == #"{"data":{"value":3}}"#)
    }

    @Test("The token is read for every call, so a refreshed one is used")
    func tokenPerCall() async throws {
        let transport = FakeHTTPTransport()
        let client = make(transport)
        _ = try await client.send(function: "a", data: Data("{}".utf8))
        _ = try await client.send(function: "b", data: Data())
        #expect(transport.requests.count == 2)
        let second = try #require(transport.requests[1].httpBody)
        #expect(String(bytes: second, encoding: .utf8) == #"{"data":{}}"#)
    }

    @Test("Without a signed-in user nothing is sent")
    func noToken() async {
        let transport = FakeHTTPTransport()
        let client = make(transport, tokens: Tokens(token: nil))
        await #expect(throws: ServerError.unauthenticated) { try await client.send(function: "a", data: Data()) }
        #expect(transport.requests.isEmpty)
    }

    @Test("A failure body becomes the typed error", arguments: [
        (409, #"{"error":{"status":"ALREADY_EXISTS","message":"SLUG_TAKEN"}}"#, ServerError.slugTaken),
        (400, #"{"error":{"status":"INVALID_ARGUMENT","message":"INVALID_ARGUMENT","details":{"fields":["slug"]}}}"#,
         ServerError.invalidArgument(fields: ["slug"])),
        (503, #"{"error":{"status":"UNAVAILABLE","message":"TRY_AGAIN"}}"#, ServerError.unavailable),
        (401, #"{"error":{"status":"UNAUTHENTICATED","message":"UNAUTHENTICATED"}}"#, ServerError.unauthenticated)
    ])
    func failures(status: Int, body: String, expected: ServerError) async {
        let transport = FakeHTTPTransport()
        transport.respond(status: status, body: body)
        let client = make(transport)
        await #expect(throws: expected) { try await client.send(function: "a", data: Data()) }
    }

    @Test("A phone that cannot reach the server gets .network")
    func offline() async {
        let transport = FakeHTTPTransport()
        transport.fail(with: URLError(.notConnectedToInternet))
        let client = make(transport)
        await #expect(throws: ServerError.network) { try await client.send(function: "a", data: Data()) }
    }

    @Test("A success without a result, or a result of the wrong shape, is unexpected")
    func unreadable() async {
        let transport = FakeHTTPTransport()
        transport.respond(status: 200, body: #"{"nothing":true}"#)
        let client = make(transport)
        await #expect(throws: ServerError.unexpected(code: "RESULT")) {
            try await client.send(function: "a", data: Data())
        }
        transport.respond(status: 200, body: #"{"result":{"value":"seven"}}"#)
        await #expect(throws: ServerError.unexpected(code: "DECODE")) {
            let _: Ping = try await client.call("a", Ping(value: 1))
        }
    }

    @Test("Instants travel as ISO-8601 UTC with milliseconds and come back")
    func instants() throws {
        let date = Date(timeIntervalSince1970: 1_790_000_000.5)
        #expect(CallableJSON.instant(date) == "2026-09-21T14:13:20.500Z")
        #expect(CallableJSON.parse("2026-09-21T14:13:20.500Z") == date)
        #expect(CallableJSON.parse("2026-09-21T14:13:20Z") == Date(timeIntervalSince1970: 1_790_000_000))
        #expect(CallableJSON.parse("yesterday") == nil)
    }
}
