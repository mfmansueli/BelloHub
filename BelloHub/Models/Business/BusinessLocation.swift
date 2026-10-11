//
//  BusinessLocation.swift
//  BelloHub
//

import Foundation

/// The place she works, as she typed it in "Where you work" (Booking settings). Optional: nothing about it is public
/// until she saves one and chooses where it shows (`visibility`). Stored in the vault with the booking setup, in the
/// clear: an address is not clinical. `BusinessLocationFormat` owns how it is written and the map links.
struct BusinessLocation: Hashable, Codable, Sendable {
    static let streetLimit = 120
    static let postalCodeLimit = 20
    static let cityLimit = 80
    static let directionsLimit = 300

    /// Street and number, with any unit ("Rua Augusta 1200, sala 4").
    var street: String
    var postalCode: String
    var city: String
    /// ISO 3166-1 alpha-2; starts as the business region.
    var countryCode: String
    /// How to find us: floor, bell, a landmark. Optional.
    var directions: String
    var visibility: LocationVisibility

    init(
        street: String = "", postalCode: String = "", city: String = "", countryCode: String,
        directions: String = "", visibility: LocationVisibility = .confirmedClients
    ) {
        self.street = street
        self.postalCode = postalCode
        self.city = city
        self.countryCode = countryCode
        self.directions = directions
        self.visibility = visibility
    }
}
