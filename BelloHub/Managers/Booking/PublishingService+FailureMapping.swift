//
//  PublishingService+FailureMapping.swift
//  BelloHub
//

import Foundation

/// Every error a publish can end in, as the `PublishFailure` the screens explain: the one place a server, vault or
/// key-integrity error becomes a failure of her page.
extension PublishingService {
    /// Any error a publish can end in, as the failure the screens explain.
    static func failure(for error: any Error) -> PublishFailure {
        switch error {
        case let error as BookingRepositoryError: failure(for: error)
        case let error as ServerError: failure(for: error)
        case let error as PublishSourceError: error == .locked ? .locked : .rejected
        case is InboxKeyMismatchError: .keyMismatch
        case VaultError.locked: .locked
        default: .rejected
        }
    }

    private static func failure(for error: BookingRepositoryError) -> PublishFailure {
        switch error {
        case .unreachable, .notPublishedYet: .offline
        case .busy: .busy
        case .unauthenticated: .signedOut
        case .slugTaken: .addressTaken
        case .slugInvalid, .rejected: .rejected
        }
    }

    private static func failure(for error: ServerError) -> PublishFailure {
        switch error {
        case .network: .offline
        case .unavailable, .rateLimited: .busy
        case .unauthenticated, .forbidden: .signedOut
        case .slugTaken: .addressTaken
        default: .rejected
        }
    }
}
