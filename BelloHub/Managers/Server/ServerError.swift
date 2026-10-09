//
//  ServerError.swift
//  BelloHub
//

import Foundation

/// What a call to the booking server can end in, in terms the app can act on (firebase/functions/API.md section 3).
/// `CallableErrorMapper` is the only place that turns the wire's `error.message` code into one of these; screens never
/// see a code or an HTTP status, and never show server text (the codes are not prose).
enum ServerError: Error, Equatable, Sendable {
    /// No signed-in professional, or the token was refused.
    case unauthenticated
    /// Signed in but not allowed (`FORBIDDEN`, `APP_CHECK_REQUIRED`).
    case forbidden
    case notFound
    /// `claimSlug`: somebody else owns the address.
    case slugTaken
    /// The input did not match the contract; `fields` are the paths the server named, never values.
    case invalidArgument(fields: [String])
    /// Too many calls; try again after this many seconds.
    case rateLimited(retryAfterSeconds: Int?)
    /// A transient contention or outage (`TRY_AGAIN`, `INTERNAL`, 5xx): worth retrying later.
    case unavailable
    /// The environment lacks a provider (`NOT_CONFIGURED`).
    case notConfigured
    /// The same id was used with different content (`CONFLICT`).
    case conflict
    /// A document is over its cap (`PAYLOAD_TOO_LARGE`).
    case payloadTooLarge
    /// The phone could not reach the server at all (offline, timeout, TLS).
    case network
    /// An answer the app cannot read, or a code it does not know.
    case unexpected(code: String)

    /// Whether the same request can succeed later without anybody changing anything.
    var isTransient: Bool {
        switch self {
        case .network, .unavailable, .rateLimited: true
        default: false
        }
    }
}
