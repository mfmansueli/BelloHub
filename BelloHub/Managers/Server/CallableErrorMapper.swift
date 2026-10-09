//
//  CallableErrorMapper.swift
//  BelloHub
//

import Foundation

/// Turns what came back from a function into a `ServerError`, in one pure place (API.md section 1 and 3): the body of a
/// failure is `{"error": {"status", "message": CODE, "details"}}`. The code, not the HTTP number, decides; the number
/// only helps when the body is not ours (a gateway page, an empty body).
enum CallableErrorMapper {
    /// The error for a response that was not a success, or nil for a 2xx.
    static func error(httpStatus: Int, body: Data) -> ServerError? {
        guard !(200..<300).contains(httpStatus) else { return nil }
        if let envelope = try? JSONDecoder().decode(Envelope.self, from: body), let code = envelope.error.message {
            return map(code: code, details: envelope.error.details)
        }
        return byStatus(httpStatus)
    }

    /// A `URLError` (or anything thrown before an answer) as the app understands it.
    static func error(transport error: any Error) -> ServerError {
        if let serverError = error as? ServerError { return serverError }
        if error is URLError || (error as NSError).domain == NSURLErrorDomain { return .network }
        return .unexpected(code: "TRANSPORT")
    }

    private static let simpleCodes: [String: ServerError] = [
        "UNAUTHENTICATED": .unauthenticated, "FORBIDDEN": .forbidden, "APP_CHECK_REQUIRED": .forbidden,
        "NOT_FOUND": .notFound, "TOKEN_EXPIRED": .notFound, "SLUG_TAKEN": .slugTaken, "TRY_AGAIN": .unavailable,
        "INTERNAL": .unavailable, "NOT_CONFIGURED": .notConfigured, "CONFLICT": .conflict,
        "PAYLOAD_TOO_LARGE": .payloadTooLarge
    ]

    static func map(code: String, details: Details? = nil) -> ServerError {
        if let known = simpleCodes[code] { return known }
        switch code {
        case "INVALID_ARGUMENT": return .invalidArgument(fields: details?.fields ?? [])
        case "RATE_LIMITED": return .rateLimited(retryAfterSeconds: details?.retryAfterSeconds)
        default: return .unexpected(code: code)
        }
    }

    private static func byStatus(_ status: Int) -> ServerError {
        switch status {
        case 401: .unauthenticated
        case 403: .forbidden
        case 404: .notFound
        case 429: .rateLimited(retryAfterSeconds: nil)
        case 500...599: .unavailable
        default: .unexpected(code: "HTTP\(status)")
        }
    }

    // MARK: - Wire shape

    struct Details: Decodable, Equatable {
        let fields: [String]?
        let retryAfterSeconds: Int?
    }

    private struct EnvelopeBody: Decodable {
        let message: String?
        let details: Details?
    }

    private struct Envelope: Decodable {
        let error: EnvelopeBody
    }
}
