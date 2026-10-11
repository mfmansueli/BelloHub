//
//  UnverifiedRequestBadge.swift
//  BelloHub
//

import Foundation

/// The "Not verified" badge of 2.10 (verify-fallback): a request the client made with "I didn't get the code" ->
/// "Confirm on WhatsApp" carries no proof of her phone or e-mail (`verification == "whatsapp"`, API.md 5.8). The
/// professional should check that the WhatsApp message came from the number on the request and quotes its reference
/// before approving; approving itself works as for any request. The server is the only source of these fields.
struct UnverifiedRequestBadge: Equatable, Sendable {
    /// The code the client quotes in her message; nil when the server sent none or one of an unexpected shape.
    let reference: String?
    /// The phone the request was made with, to compare with the WhatsApp sender.
    let phone: String
    /// When the server releases the request unanswered; nil when it did not say.
    let releasedAt: Date?

    /// Five characters from 23456789ABCDEFGHJKMNPQRSTUVWXYZ (API.md 5.8).
    private static let referenceAlphabet = Set("23456789ABCDEFGHJKMNPQRSTUVWXYZ")

    /// The badge for a request that still waits and was not verified; nil for anything else (a verified request, an
    /// unverified one she already answered, a booking that is not a request).
    static func make(for booking: IncomingBooking) -> UnverifiedRequestBadge? {
        guard booking.status.isRequest, booking.verification == "whatsapp" else { return nil }
        return UnverifiedRequestBadge(
            reference: booking.reference.flatMap(normalizedReference),
            phone: booking.client.phone,
            releasedAt: booking.pendingExpiresAt
        )
    }

    /// Upper-cased and checked, so what she reads is exactly what the client was shown.
    static func normalizedReference(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard value.count == 5, value.allSatisfy(referenceAlphabet.contains) else { return nil }
        return value
    }

    /// An unverified request has no other reason to show unless the server gave one: "new client" is the fallback of
    /// a missing reason, and it would be a guess here.
    static func showsReason(for booking: IncomingBooking) -> Bool {
        make(for: booking) == nil || booking.pendingReason != nil
    }
}
