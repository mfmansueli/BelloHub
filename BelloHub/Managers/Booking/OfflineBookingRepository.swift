//
//  OfflineBookingRepository.swift
//  BelloHub
//

/// The booking server connection for previews and builds without a server: no networking at all. Every call says the
/// page
/// is not published, so a screen can show "once you go online" and never pretends an address was checked or a page is
/// live.
struct OfflineBookingRepository: BookingRepository {
    func isSlugAvailable(_ slug: String) async throws -> SlugAvailability {
        throw BookingRepositoryError.notPublishedYet
    }

    func ensureAccount(countryCode: String, locale: String) async throws -> AccountInfo {
        throw BookingRepositoryError.notPublishedYet
    }

    func claimSlug(_ slug: String) async throws {
        throw BookingRepositoryError.notPublishedYet
    }

    func publishProfile(_ request: PublishProfileRequest) async throws {
        throw BookingRepositoryError.notPublishedYet
    }

    func publishAvailability(_ request: PublishAvailabilityRequest) async throws {
        throw BookingRepositoryError.notPublishedYet
    }

    func setOnlineBookingStopped(phone: String, stopped: Bool) async throws {
        throw BookingRepositoryError.notPublishedYet
    }

    func updateInboxKey(_ key: InboxPublicKey, compromised: Bool) async throws {
        throw BookingRepositoryError.notPublishedYet
    }
}
