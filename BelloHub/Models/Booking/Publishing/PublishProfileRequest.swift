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
