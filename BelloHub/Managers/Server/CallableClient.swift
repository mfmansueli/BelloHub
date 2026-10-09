//
//  CallableClient.swift
//  BelloHub
//

import Foundation

/// The door to the Firebase callable functions (firebase/functions/API.md section 1): `POST {data}` and `{result}`
/// back.
/// `RemoteBookingRepository` is its only user. The primitive works on JSON bytes so a fake in the tests records exactly
/// what would travel; the typed `call` below is what callers use.
protocol CallableClient: Sendable {
    /// Calls `function` with `data` (already the JSON of the request object) and returns the JSON of `result`.
    /// Throws `ServerError`.
    func send(function: String, data: Data) async throws -> Data
}

extension CallableClient {
    /// Encodes `request`, calls `function` and decodes the response. Throws `ServerError` (`unexpected` when the answer
    /// is not what the contract says).
    func call<Request: Encodable, Response: Decodable>(
        _ function: String, _ request: Request, as type: Response.Type = Response.self
    ) async throws -> Response {
        let body: Data
        do {
            body = try CallableJSON.encoder.encode(request)
        } catch {
            throw ServerError.unexpected(code: "ENCODE")
        }
        let result = try await send(function: function, data: body)
        do {
            return try CallableJSON.decoder.decode(Response.self, from: result)
        } catch {
            throw ServerError.unexpected(code: "DECODE")
        }
    }
}
