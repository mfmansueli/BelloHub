//
//  PayloadInstant.swift
//  BelloHub
//

import Foundation

/// The one reader of the times inside a sealed payload. The browser writes `Date.toISOString()`, which always has
/// milliseconds ("2026-10-08T14:03:21.000Z"); Foundation's plain `.iso8601` strategy refuses fractions, which once
/// left every web check-in and data request without its sent time.
enum PayloadInstant {
    /// ISO-8601 with or without fractional seconds; nil for anything else.
    static func parse(_ text: String) -> Date? {
        if let date = try? Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
            return date
        }
        return try? Date(text, strategy: Date.ISO8601FormatStyle())
    }
}
