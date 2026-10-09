//
//  BookingRepository.swift
//  BelloHub
//

/// The app's door to the booking server (docs/04-ARCHITECTURE.md section 3, boundary 2): everything the **client side**
/// of her booking page needs from the network. Today only the address check; S8 adds publishing the page and her
/// availability, the incoming bookings and the mailbox behind the same protocol. Clinical data never goes through it
/// (docs/06-PRIVACY-SECURITY.md).
///
/// `OfflineBookingRepository` is the implementation until S8: it says plainly that nothing is published yet.
protocol BookingRepository: Sendable {
    /// Whether `slug` (already valid by `BookingSlug`) is free for her. Throws `BookingRepositoryError.notPublishedYet`
    /// while the server is not connected.
    func isSlugAvailable(_ slug: String) async throws -> SlugAvailability
}
