//
//  BookingSuggestionOutcome.swift
//  BelloHub
//

import Foundation

/// What `suggestBookingTime` answered (API.md 6.3, "Suggest another time" on 2.10): the request was declined and the
/// proposed time is held for the client behind a one-time key, or the time is not free by her own rules.
enum BookingSuggestionOutcome: Equatable, Sendable {
    case suggested(holdKey: String, expiresAt: Date)
    case slotTaken

    /// The link the client opens to take the held time: `<web>/<slug>/time?offer=<holdKey>` (API.md 5.4).
    static func offerURL(link: BookingLink, holdKey: String) -> URL {
        link.url.appending(path: "time").appending(queryItems: [URLQueryItem(name: "offer", value: holdKey)])
    }
}
