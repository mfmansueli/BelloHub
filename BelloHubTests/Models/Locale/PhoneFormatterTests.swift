//
//  PhoneFormatterTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("PhoneFormatter")
struct PhoneFormatterTests {
    @Test("Brazilian mobile and landline numbers use their own patterns")
    func brazil() throws {
        let formatter = PhoneFormatter(catalog: try RegionCatalogTests.bundled())

        #expect(formatter.international("+5511912345678") == "+55 (11) 91234-5678")
        #expect(formatter.international("+552123456789") == "+55 (21) 2345-6789")
        #expect(formatter.national("+5511912345678") == "(11) 91234-5678")
    }

    @Test("Numbers from the wave 1 European markets are grouped as people there write them", arguments: [
        ("+351912345678", "+351 912 345 678"),
        ("+34612345678", "+34 612 34 56 78"),
        ("+393123456789", "+39 312 345 6789"),
        ("+33612345678", "+33 6 12 34 56 78"),
        ("+4915123456789", "+49 1512 3456789"),
        ("+447700900123", "+44 7700 900123"),
        ("+353831234567", "+353 83 123 4567"),
        ("+14155552671", "+1 (415) 555-2671")
    ])
    func europe(e164: String, expected: String) throws {
        let formatter = PhoneFormatter(catalog: try RegionCatalogTests.bundled())

        #expect(formatter.international(e164) == expected)
    }

    @Test("An unknown country keeps its digits in groups of three")
    func unknownCountry() throws {
        let formatter = PhoneFormatter(catalog: try RegionCatalogTests.bundled())

        #expect(formatter.international("+31612345678") == "+316 123 456 78")
    }

    @Test("A length with no pattern falls back to groups of three")
    func missingPattern() throws {
        let formatter = PhoneFormatter(catalog: try RegionCatalogTests.bundled())

        #expect(formatter.national("+55119123456789") == "119 123 456 789")
    }

    @Test("Normalizing then formatting round-trips the digits")
    func roundTrip() throws {
        let catalog = try RegionCatalogTests.bundled()
        let brazil = try #require(catalog.preset(for: "BR"))
        let e164 = try PhoneNormalizer(catalog: catalog).normalize("11 91234 5678", defaultRegion: brazil).get()

        #expect(DigitNormalizer.digitsOnly(PhoneFormatter(catalog: catalog).international(e164))
            == DigitNormalizer.digitsOnly(e164))
    }
}
