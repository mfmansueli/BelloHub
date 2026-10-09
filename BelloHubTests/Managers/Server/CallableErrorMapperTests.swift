//
//  CallableErrorMapperTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("CallableErrorMapper")
struct CallableErrorMapperTests {
    private func body(_ code: String, details: String = "") -> Data {
        let extra = details.isEmpty ? "" : #","details":\#(details)"#
        return Data(#"{"error":{"status":"X","message":"\#(code)"\#(extra)}}"#.utf8)
    }

    @Test("Every code of API.md section 3 maps to one error", arguments: [
        ("UNAUTHENTICATED", ServerError.unauthenticated),
        ("APP_CHECK_REQUIRED", .forbidden),
        ("FORBIDDEN", .forbidden),
        ("NOT_FOUND", .notFound),
        ("TOKEN_EXPIRED", .notFound),
        ("SLUG_TAKEN", .slugTaken),
        ("TRY_AGAIN", .unavailable),
        ("INTERNAL", .unavailable),
        ("NOT_CONFIGURED", .notConfigured),
        ("CONFLICT", .conflict),
        ("PAYLOAD_TOO_LARGE", .payloadTooLarge),
        ("SOMETHING_NEW", .unexpected(code: "SOMETHING_NEW"))
    ])
    func codes(code: String, expected: ServerError) {
        #expect(CallableErrorMapper.error(httpStatus: 400, body: body(code)) == expected)
    }

    @Test("INVALID_ARGUMENT carries the field paths, RATE_LIMITED the wait")
    func details() {
        let invalid = CallableErrorMapper.error(
            httpStatus: 400, body: body("INVALID_ARGUMENT", details: #"{"fields":["profile.services"]}"#)
        )
        #expect(invalid == .invalidArgument(fields: ["profile.services"]))
        let limited = CallableErrorMapper.error(
            httpStatus: 429, body: body("RATE_LIMITED", details: #"{"retryAfterSeconds":30}"#)
        )
        #expect(limited == .rateLimited(retryAfterSeconds: 30))
        let bare = CallableErrorMapper.error(httpStatus: 400, body: body("INVALID_ARGUMENT"))
        #expect(bare == .invalidArgument(fields: []))
    }

    @Test("A body that is not ours is judged by the HTTP status", arguments: [
        (401, ServerError.unauthenticated), (403, .forbidden), (404, .notFound),
        (429, .rateLimited(retryAfterSeconds: nil)), (500, .unavailable), (502, .unavailable), (503, .unavailable),
        (418, .unexpected(code: "HTTP418"))
    ])
    func byStatus(status: Int, expected: ServerError) {
        #expect(CallableErrorMapper.error(httpStatus: status, body: Data("<html>gateway</html>".utf8)) == expected)
        #expect(CallableErrorMapper.error(httpStatus: status, body: Data()) == expected)
    }

    @Test("A success is not an error", arguments: [200, 201, 204])
    func success(status: Int) {
        #expect(CallableErrorMapper.error(httpStatus: status, body: Data("{}".utf8)) == nil)
    }

    @Test("Transport failures are the network, anything else is unexpected")
    func transport() {
        #expect(CallableErrorMapper.error(transport: URLError(.notConnectedToInternet)) == .network)
        #expect(CallableErrorMapper.error(transport: URLError(.timedOut)) == .network)
        #expect(CallableErrorMapper.error(transport: ServerError.unauthenticated) == .unauthenticated)
        struct Other: Error {}
        #expect(CallableErrorMapper.error(transport: Other()) == .unexpected(code: "TRANSPORT"))
    }

    @Test("Only network trouble, a busy server and limits are worth retrying later")
    func transient() {
        #expect(ServerError.network.isTransient && ServerError.unavailable.isTransient)
        #expect(ServerError.rateLimited(retryAfterSeconds: nil).isTransient)
        #expect(!ServerError.slugTaken.isTransient && !ServerError.unauthenticated.isTransient)
        #expect(!ServerError.invalidArgument(fields: []).isTransient)
    }
}
