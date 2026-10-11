//
//  BookingSetupRepository.swift
//  BelloHub
//

import Foundation

/// How clients can book her: availability, the booking page switches, cancel and no-show policies and quick replies
/// (S5). Non-clinical, stored in the clear (docs/05-DATA-MODEL.md section 1). Publishing to the server is
/// `BookingRepository`'s job (offline until S8), not this one's: everything here stays on her iPhone and in her iCloud.
protocol BookingSetupRepository: Sendable {
    /// Her weekly hours, breaks, days off and buffer. Nil until she (or the first change) stored them.
    func availability() async throws -> AvailabilitySettings?
    func save(_ availability: AvailabilitySettings) async throws

    /// The page switches, policies and chosen address. Nil until stored.
    func bookingSetup() async throws -> BookingSetup?
    func save(_ setup: BookingSetup) async throws

    /// Her quick replies in the order she keeps them.
    func quickReplies() async throws -> [QuickReply]
    func save(_ reply: QuickReply) async throws
    /// Stores several replies **together**: a reorder or the first set of defaults must not leave half of them behind.
    func save(_ replies: [QuickReply]) async throws
    func deleteQuickReply(id: UUID) async throws
}
