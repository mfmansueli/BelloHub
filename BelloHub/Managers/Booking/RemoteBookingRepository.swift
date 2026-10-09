//
//  RemoteBookingRepository.swift
//  BelloHub
//

import Foundation

/// The booking server for real: each method is one owner function of firebase/functions/API.md section 6, called
/// through
/// the `CallableClient`. It builds nothing and decides nothing (`PublishPayloads` and `PublishingService` do); it only
/// speaks the contract and turns `ServerError` into `BookingRepositoryError`.
struct RemoteBookingRepository: BookingRepository {
    private let client: any CallableClient

    init(client: any CallableClient) {
        self.client = client
    }

    func isSlugAvailable(_ slug: String) async throws -> SlugAvailability {
        let answer: SlugAnswer = try await perform("isSlugAvailable", SlugRequest(slug: slug))
        if answer.available { return .available }
        switch answer.reason {
        case "taken": return .taken
        case "reserved": return .reserved
        default: return .invalid
        }
    }

    func ensureAccount(countryCode: String, locale: String) async throws -> AccountInfo {
        try await perform("ensureAccount", EnsureAccountRequest(countryCode: countryCode, locale: locale))
    }

    func claimSlug(_ slug: String) async throws {
        let _: SlugRequest = try await perform("claimSlug", SlugRequest(slug: slug), invalidIsSlug: true)
    }

    func publishProfile(_ request: PublishProfileRequest) async throws {
        let _: Published = try await perform("publishProfile", request)
    }

    func publishAvailability(_ request: PublishAvailabilityRequest) async throws {
        let _: Published = try await perform("publishAvailability", request)
    }

    func setOnlineBookingStopped(phone: String, stopped: Bool) async throws {
        let request = StoppedRequest(phone: phone, stopped: stopped)
        let _: Acknowledged = try await perform("setOnlineBookingStopped", request)
    }

    func updateInboxKey(_ key: InboxPublicKey, compromised: Bool) async throws {
        let _: Keyring = try await perform(
            "updateInboxKey", InboxKeyRequest(inboxKey: key, compromised: compromised ? true : nil)
        )
    }

    // MARK: - Mapping

    private func perform<Request: Encodable, Response: Decodable>(
        _ function: String, _ request: Request, invalidIsSlug: Bool = false
    ) async throws -> Response {
        do {
            return try await client.call(function, request)
        } catch let error as ServerError {
            throw Self.map(error, invalidIsSlug: invalidIsSlug)
        }
    }

    /// The one place a `ServerError` becomes a `BookingRepositoryError`.
    static func map(_ error: ServerError, invalidIsSlug: Bool = false) -> BookingRepositoryError {
        switch error {
        case .network: .unreachable
        case .unavailable, .rateLimited: .busy
        case .unauthenticated, .forbidden: .unauthenticated
        case .slugTaken: .slugTaken
        case .invalidArgument: invalidIsSlug ? .slugInvalid : .rejected
        case .notFound, .notConfigured, .conflict, .payloadTooLarge, .unexpected: .rejected
        }
    }

    // MARK: - Wire shapes

    private struct SlugRequest: Codable { let slug: String }
    private struct SlugAnswer: Decodable {
        let available: Bool
        let reason: String?
    }

    private struct EnsureAccountRequest: Encodable {
        let countryCode: String
        let locale: String
    }

    private struct StoppedRequest: Encodable {
        let phone: String
        let stopped: Bool
    }

    private struct InboxKeyRequest: Encodable {
        let inboxKey: InboxPublicKey
        let compromised: Bool?
    }

    private struct Published: Decodable {
        let updatedAt: Date
    }

    private struct Acknowledged: Decodable {
        let ok: Bool
    }

    private struct KeyringEntry: Decodable {
        let keyId: String
    }

    private struct Keyring: Decodable {
        let keyring: [KeyringEntry]
    }
}
