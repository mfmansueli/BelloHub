//
//  BusinessLocationFormat.swift
//  BelloHub
//

import Foundation

/// The one owner of how her address is written and linked (owner, 2026-10-11: "the confirmation should say where the
/// place is"). The app formats it once and publishes the lines and the map links; the server and the booking page only
/// print what she published, so the three can never disagree. Map links are built from the text alone: no SDK, no
/// geocoding call, nothing sent anywhere until a client taps one. Pure.
enum BusinessLocationFormat {
    /// Regions that write the city before the postal code ("Austin 78701", "London SW1A 1AA", "São Paulo 01310-100").
    /// Everywhere else the code comes first ("1000-001 Lisboa", "28013 Madrid", "10115 Berlin").
    static let cityFirstRegions: Set<String> = [
        "US", "GB", "IE", "CA", "AU", "NZ", "ZA", "IN", "ID", "BR", "AE", "SA"
    ]

    /// Street and city are the minimum a client can find.
    static func isComplete(_ location: BusinessLocation) -> Bool {
        !clean(location.street).isEmpty && !clean(location.city).isEmpty && !location.countryCode.isEmpty
    }

    /// Whether a field is longer than the server takes; the screen says so instead of saving.
    static func tooLong(_ location: BusinessLocation) -> Bool {
        location.street.count > BusinessLocation.streetLimit
            || location.postalCode.count > BusinessLocation.postalCodeLimit
            || location.city.count > BusinessLocation.cityLimit
            || location.directions.count > BusinessLocation.directionsLimit
    }

    /// One to two lines: the street, then the postal code and the city in the region's order. The country is left out:
    /// the client is almost always in it.
    static func lines(_ location: BusinessLocation) -> [String] {
        let street = clean(location.street)
        let city = clean(location.city)
        let postal = clean(location.postalCode)
        let place: String = if postal.isEmpty {
            city
        } else if cityFirstRegions.contains(location.countryCode.uppercased()) {
            "\(city) \(postal)"
        } else {
            "\(postal) \(city)"
        }
        return [street, place].filter { !$0.isEmpty }
    }

    /// The address on one line, for a calendar entry's location.
    static func oneLine(_ location: BusinessLocation) -> String {
        lines(location).joined(separator: ", ")
    }

    /// What the map apps search for: the lines and the country's English name, so the right country wins.
    static func query(_ location: BusinessLocation) -> String {
        let country = Locale(identifier: "en_US").localizedString(forRegionCode: location.countryCode.uppercased())
        return (lines(location) + [country].compactMap { $0 }).joined(separator: ", ")
    }

    /// `https://maps.apple.com/?address=…`: opens Apple Maps on an iPhone, Apple's map page elsewhere.
    static func appleMapsURL(_ location: BusinessLocation) -> URL? {
        URL(string: "https://maps.apple.com/?address=\(MessageLinks.encoded(query(location)))")
    }

    /// `https://www.google.com/maps/search/?api=1&query=…`: opens Google Maps (the app on Android or iOS if installed,
    /// the website elsewhere).
    static func googleMapsURL(_ location: BusinessLocation) -> URL? {
        URL(string: "https://www.google.com/maps/search/?api=1&query=\(MessageLinks.encoded(query(location)))")
    }

    /// What `{address}` puts in a message: the lines and the "how to find us" note, each on its own line;
    /// map directions are opened directly from the client's booking manage link. Empty without a complete address.
    static func messageBlock(_ location: BusinessLocation?) -> String {
        guard let location, isComplete(location) else { return "" }
        var parts = lines(location)
        let directions = clean(location.directions)
        if !directions.isEmpty { parts.append(directions) }
        return parts.joined(separator: "\n")
    }

    /// Spaces trimmed and runs of white space (a pasted line break included) made one space.
    static func clean(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
