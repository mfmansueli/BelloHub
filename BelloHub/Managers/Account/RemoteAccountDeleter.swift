//
//  RemoteAccountDeleter.swift
//  BelloHub
//

import Foundation

/// The server half of deleting her account, for real: the owner function `deleteAccount` (firebase/functions/API.md
/// section 6.7). The server removes everything under her uid (bookings, holds, sealed items and their Storage
/// objects, portals, requests, waitlist, contacts, devices, availability, public page, slug, registrations, account)
/// and her Auth user, and revokes the Sign in with Apple grant when a fresh authorization code travels (D44).
///
/// Any failure is thrown, so `AccountService` keeps the iPhone untouched and she can try again: a phone emptied while
/// the server account lives on is the one outcome the cascade must never produce. The call is idempotent on the
/// server, so a retry after a lost answer is safe.
struct RemoteAccountDeleter: AccountDeleting {
    private let client: any CallableClient

    init(client: any CallableClient) {
        self.client = client
    }

    func deleteAccount(_ request: AccountDeletionRequest) async throws -> AccountDeletionOutcome {
        let code = request.appleAuthorizationCode.flatMap { $0.isEmpty ? nil : $0 }
        let answer: Answer = try await client.call("deleteAccount", Body(confirm: true, appleAuthorizationCode: code))
        guard answer.ok else { throw ServerError.unexpected(code: "NOT_OK") }
        return Self.outcome(appleRevocation: answer.appleRevocation, sentAppleCode: code != nil)
    }

    /// `"skipped"` without a code is a phone account (nothing to revoke). With a code it means the Apple key is not
    /// configured on that server, so the grant is still alive and she is told to revoke it in Settings.
    static func outcome(appleRevocation: String, sentAppleCode: Bool) -> AccountDeletionOutcome {
        switch appleRevocation {
        case "revoked": .deleted
        case "skipped": sentAppleCode ? .deletedWithoutAppleRevocation : .deleted
        default: .deletedWithoutAppleRevocation
        }
    }

    // MARK: - Wire shapes

    /// `confirm` is the literal `true` the contract asks for; a nil code is left out of the JSON (strict schema).
    private struct Body: Encodable {
        let confirm: Bool
        let appleAuthorizationCode: String?
    }

    private struct Answer: Decodable {
        let ok: Bool
        let appleRevocation: String
    }
}
