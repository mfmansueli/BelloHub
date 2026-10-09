//
//  OfflineBookingRepository.swift
//  BelloHub
//

/// The booking server connection until S8: no networking at all. Every call says the page is not published yet, so a
/// screen can show "once you go online" and never pretends an address was checked or a page is live. S8 replaces it
/// with the real implementation behind the same protocol; nothing above it changes.
struct OfflineBookingRepository: BookingRepository {
    func isSlugAvailable(_ slug: String) async throws -> SlugAvailability {
        throw BookingRepositoryError.notPublishedYet
    }
}
