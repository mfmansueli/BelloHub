//
//  BusinessLocationFormatTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("BusinessLocationFormat")
struct BusinessLocationFormatTests {
    private func location(
        street: String = "Rua Augusta 1200, sala 4", postalCode: String = "01304-001", city: String = "São Paulo",
        country: String = "BR", directions: String = ""
    ) -> BusinessLocation {
        BusinessLocation(
            street: street, postalCode: postalCode, city: city, countryCode: country, directions: directions
        )
    }

    @Test("Street and city are the minimum; the country comes from the region")
    func completeness() {
        #expect(BusinessLocationFormat.isComplete(location()))
        #expect(!BusinessLocationFormat.isComplete(location(street: "  ")))
        #expect(!BusinessLocationFormat.isComplete(location(city: "")))
        #expect(BusinessLocationFormat.isComplete(location(postalCode: "")))
    }

    @Test("The postal code goes before or after the city as the region writes it", arguments: [
        ("PT", "1000-001 Lisboa"), ("ES", "1000-001 Lisboa"), ("DE", "1000-001 Lisboa"), ("BR", "Lisboa 1000-001"),
        ("US", "Lisboa 1000-001"), ("GB", "Lisboa 1000-001")
    ])
    func order(country: String, expected: String) {
        let lines = BusinessLocationFormat.lines(location(street: "Rua A 1", postalCode: "1000-001", city: "Lisboa",
                                                         country: country))
        #expect(lines == ["Rua A 1", expected])
    }

    @Test("Spaces and pasted line breaks are tidied; an empty postal code leaves the city alone")
    func cleaning() {
        let messy = location(street: "  Rua   Augusta\n1200 ", postalCode: " ", city: " São  Paulo ")
        #expect(BusinessLocationFormat.lines(messy) == ["Rua Augusta 1200", "São Paulo"])
        #expect(BusinessLocationFormat.oneLine(messy) == "Rua Augusta 1200, São Paulo")
    }

    @Test("The map links are built from the text alone, fully encoded, with the country's English name")
    func mapLinks() throws {
        let place = location()
        #expect(BusinessLocationFormat.query(place) == "Rua Augusta 1200, sala 4, São Paulo 01304-001, Brazil")
        let apple = try #require(BusinessLocationFormat.appleMapsURL(place)).absoluteString
        let google = try #require(BusinessLocationFormat.googleMapsURL(place)).absoluteString
        let encoded = "Rua%20Augusta%201200%2C%20sala%204%2C%20S%C3%A3o%20Paulo%2001304-001%2C%20Brazil"
        #expect(apple == "https://maps.apple.com/?address=\(encoded)")
        #expect(google == "https://www.google.com/maps/search/?api=1&query=\(encoded)")
        // An ampersand in the street can never start a new parameter.
        let tricky = try #require(BusinessLocationFormat.googleMapsURL(location(street: "Rua A & B, 1?x=y#z")))
        #expect(!tricky.absoluteString.contains("&B") && tricky.query?.contains("x=y") == false)
    }

    @Test("{address} carries the lines, the note and the Google Maps link, each on its own line")
    func messageBlock() throws {
        let block = BusinessLocationFormat.messageBlock(location(directions: "2º andar, interfone 4"))
        let google = try #require(BusinessLocationFormat.googleMapsURL(location())).absoluteString
        #expect(block == "Rua Augusta 1200, sala 4\nSão Paulo 01304-001\n2º andar, interfone 4\n\(google)")
        #expect(BusinessLocationFormat.messageBlock(nil).isEmpty)
        #expect(BusinessLocationFormat.messageBlock(location(city: "")).isEmpty)
    }

    @Test("Fields longer than the server takes are caught before saving")
    func lengths() {
        #expect(!BusinessLocationFormat.tooLong(location()))
        #expect(BusinessLocationFormat.tooLong(location(street: String(repeating: "a", count: 121))))
        #expect(BusinessLocationFormat.tooLong(location(directions: String(repeating: "a", count: 301))))
    }

    @Test("A setup stored before the address existed reads as having none")
    func olderSetup() throws {
        let stored = BookingSetup(slug: "maria", updatedAt: TestClock.now)
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(stored)) as? [String: Any])
        json.removeValue(forKey: "location")
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        let read = try decoder.decode(BookingSetup.self, from: data)
        #expect(read.location == nil && read.slug == "maria")
    }

    @Test("An unknown visibility read from the vault shows less, never more")
    func visibilityFallback() throws {
        let data = Data(#""everyone""#.utf8)
        #expect(try JSONDecoder().decode(LocationVisibility.self, from: data) == .confirmedClients)
        #expect(LocationVisibility.confirmedClients.wireValue == "confirmed")
        #expect(LocationVisibility.bookingPage.wireValue == "public")
    }
}
