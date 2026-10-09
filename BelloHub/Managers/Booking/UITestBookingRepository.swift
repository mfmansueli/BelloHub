//
//  UITestBookingRepository.swift
//  BelloHub
//

#if DEBUG
import Foundation

/// A booking server in memory for UI-test launches (`-uiOnline fake`): the same answers the real one gives, with no
/// network, so a test can walk "go online" end to end. DEBUG only; no test plan calls the live backend.
actor UITestBookingRepository: BookingRepository {
    /// Addresses somebody else owns on this fake server.
    static let takenSlugs: Set<String> = ["ana", "taken"]
    /// A word nobody may own (a few of the server's reserved list).
    static let reservedSlugs: Set<String> = ["admin", "help", "support"]

    private(set) var publishedProfile: PublishProfileRequest?
    private(set) var publishedAvailability: PublishAvailabilityRequest?
    private var slug: String?

    func isSlugAvailable(_ slug: String) async throws -> SlugAvailability {
        if Self.reservedSlugs.contains(slug) { return .reserved }
        return Self.takenSlugs.contains(slug) ? .taken : .available
    }

    func ensureAccount(countryCode: String, locale: String) async throws -> AccountInfo {
        AccountInfo(
            uid: "fake-uid", appAccountToken: UUID().uuidString.lowercased(),
            registrations: .init(count: 0, freeLimit: 10), slug: slug
        )
    }

    func claimSlug(_ slug: String) async throws {
        if Self.takenSlugs.contains(slug) { throw BookingRepositoryError.slugTaken }
        self.slug = slug
    }

    func publishProfile(_ request: PublishProfileRequest) async throws {
        guard slug != nil else { throw BookingRepositoryError.rejected }
        publishedProfile = request
    }

    func publishAvailability(_ request: PublishAvailabilityRequest) async throws {
        publishedAvailability = request
    }

    func setOnlineBookingStopped(phone: String, stopped: Bool) async throws {}

    func updateInboxKey(_ key: InboxPublicKey, compromised: Bool) async throws {}
}
#endif
