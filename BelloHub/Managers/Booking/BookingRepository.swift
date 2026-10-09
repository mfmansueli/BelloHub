//
//  BookingRepository.swift
//  BelloHub
//

/// The app's door to the booking server (docs/04-ARCHITECTURE.md section 3, boundary 2): everything the
/// **professional's
/// side** of her booking page needs from the network. Today that is her address, her page and her availability; the
/// incoming bookings and the mailbox come behind the same protocol in the next slice. Clinical data never goes
/// through it
/// (docs/06-PRIVACY-SECURITY.md).
///
/// `RemoteBookingRepository` calls the functions of firebase/functions/API.md; `OfflineBookingRepository` is the
/// stand-in
/// for previews and builds without a server. Every method throws `BookingRepositoryError`.
protocol BookingRepository: Sendable {
    /// Whether `slug` (already valid by `BookingSlug`) is free for her.
    func isSlugAvailable(_ slug: String) async throws -> SlugAvailability
    /// Creates her server account on the first call and returns it; idempotent, so it is safe on every launch.
    func ensureAccount(countryCode: String, locale: String) async throws -> AccountInfo
    /// Makes `slug` hers, replacing the previous one. Throws `slugTaken` or `slugInvalid`.
    func claimSlug(_ slug: String) async throws
    /// Replaces the public page. She must have claimed an address first.
    func publishProfile(_ request: PublishProfileRequest) async throws
    /// Replaces her availability.
    func publishAvailability(_ request: PublishAvailabilityRequest) async throws
    /// The "stop online booking" switch of one client (by phone).
    func setOnlineBookingStopped(phone: String, stopped: Bool) async throws
    /// Registers a new current inbox key (rotation) or the same one again (no change).
    func updateInboxKey(_ key: InboxPublicKey, compromised: Bool) async throws
}
