//
//  PublishProfileRequest.swift
//  BelloHub
//

import Foundation

/// The request of `publishProfile` (firebase/functions/API.md section 6.2): the public page as a whole. The server
/// replaces the page with it, validates every field and ignores nothing it does not know (unknown keys are refused), so
/// the names here are the contract's. Only what she chose to show travels: no note, no client, nothing clinical.
struct PublishProfileRequest: Encodable, Equatable, Sendable {
    var profile: Profile

    struct Profile: Encodable, Equatable, Sendable {
        var displayName: String
        var businessName: String?
        var regionCode: String
        var timeZoneID: String
        var currencyCode: String
        /// Booking page languages, the business language first.
        var locales: [String]
        var credentials: [Credential]
        var services: [Service]
        var addOns: [AddOn]
        var booking: Booking
        var policy: Policy
        /// One text per booking language, produced by `PolicyRuleText`.
        var rulesText: [String: String]
        var inboxKey: InboxPublicKey
        /// Her health form for the page (nil: the page offers no form, `getFormContext` answers NOT_FOUND).
        var intake: Intake?
        /// Where she works (nil: no address anywhere). The server keeps it out of the public page unless `visibility`
        /// is `public`.
        var location: Location?
    }

    /// The address as `BusinessLocationFormat` writes it: the server and the page print these lines and links as they
    /// are, so there is one way to write an address.
    struct Location: Encodable, Equatable, Sendable {
        var lines: [String]
        var directions: String?
        var maps: Maps
        /// `confirmed` (only clients with a confirmed booking) or `public` (also the booking page).
        var visibility: String
    }

    struct Maps: Encodable, Equatable, Sendable {
        var apple: String
        var google: String
    }

    struct Credential: Encodable, Equatable, Sendable {
        var title: String
        var institution: String?
        var year: Int?
        var registrationNumber: String?
    }

    struct Service: Encodable, Equatable, Sendable {
        var id: String
        var name: String
        var category: String?
        var durationMinutes: Int
        var price: Price?
        /// D56: blocked before and after the visit, never shown; sent only when not 0.
        var prepMinutes: Int?
        var cleanupMinutes: Int?
        /// D56: she is free inside the visit for this long, from this many minutes after it starts.
        var processingStartMinutes: Int?
        var processingMinutes: Int?
    }

    struct Price: Encodable, Equatable, Sendable {
        /// `show`, `startingFrom` or `onRequest`; a hidden price is not sent at all.
        var display: String
        var amount: Decimal?
    }

    struct AddOn: Encodable, Equatable, Sendable {
        var id: String
        var name: String
        var minutes: Int
        var priceText: String?
    }

    struct Booking: Encodable, Equatable, Sendable {
        var acceptingBookings: Bool
        var pausedUntil: Date?
        var requiresApproval: Bool
        var maxGuests: Int
        var maxDaysAhead: Int
    }

    struct Policy: Encodable, Equatable, Sendable {
        var freeWindowHours: Int
        var clientCanReschedule: Bool
        var maxReschedules: Int?
        var afterWindowCancel: String
        var afterWindowReschedule: String
        var askConfirmation: Bool
        var graceMinutes: Int
    }
}
