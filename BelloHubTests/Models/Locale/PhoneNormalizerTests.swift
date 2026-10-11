//
//  PhoneNormalizerTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("PhoneNormalizer")
struct PhoneNormalizerTests {
    struct Case: Sendable {
        let region: String
        let input: String
        let expected: String
    }

    /// Numbers written the way people in each preset country write them (trunk prefix, spaces, dashes).
    static let nationalCases: [Case] = [
        Case(region: "BR", input: "(11) 91234-5678", expected: "+5511912345678"),
        Case(region: "BR", input: "11912345678", expected: "+5511912345678"),
        Case(region: "BR", input: "011 91234-5678", expected: "+5511912345678"),
        Case(region: "BR", input: "(21) 2345-6789", expected: "+552123456789"),
        Case(region: "PT", input: "912 345 678", expected: "+351912345678"),
        Case(region: "ES", input: "612 34 56 78", expected: "+34612345678"),
        Case(region: "MX", input: "55 1234 5678", expected: "+525512345678"),
        Case(region: "US", input: "(415) 555-2671", expected: "+14155552671"),
        Case(region: "AR", input: "011 1234-5678", expected: "+541112345678"),
        Case(region: "CO", input: "310 123 4567", expected: "+573101234567"),
        Case(region: "CL", input: "9 1234 5678", expected: "+56912345678"),
        Case(region: "PE", input: "912 345 678", expected: "+51912345678"),
        Case(region: "IT", input: "312 345 6789", expected: "+393123456789"),
        Case(region: "FR", input: "06 12 34 56 78", expected: "+33612345678"),
        Case(region: "DE", input: "01512 3456789", expected: "+4915123456789"),
        Case(region: "AT", input: "0664 1234567", expected: "+436641234567"),
        Case(region: "CH", input: "078 123 45 67", expected: "+41781234567"),
        Case(region: "GB", input: "07700 900123", expected: "+447700900123"),
        Case(region: "IE", input: "083 123 4567", expected: "+353831234567"),
        Case(region: "AU", input: "0412 345 678", expected: "+61412345678"),
        Case(region: "NZ", input: "021 123 4567", expected: "+64211234567"),
        Case(region: "ZA", input: "082 123 4567", expected: "+27821234567"),
        Case(region: "IN", input: "98765 43210", expected: "+919876543210"),
        Case(region: "TR", input: "0532 123 45 67", expected: "+905321234567"),
        Case(region: "ID", input: "0812-3456-7890", expected: "+6281234567890"),
        Case(region: "SA", input: "05 1234 5678", expected: "+966512345678"),
        Case(region: "AE", input: "050 123 4567", expected: "+971501234567")
    ]

    @Test("National numbers from every preset normalize to E.164", arguments: nationalCases)
    func nationalNumbers(testCase: Case) throws {
        let catalog = try RegionCatalogTests.bundled()
        let region = try #require(catalog.preset(for: testCase.region))
        let result = PhoneNormalizer(catalog: catalog).normalize(testCase.input, defaultRegion: region)

        #expect(result == .success(testCase.expected), "\(testCase.region): \(testCase.input)")
    }

    @Test("International numbers ignore the default region, with a plus or with 00",
          arguments: ["+55 11 91234-5678", "0055 11 91234-5678", "+55 (11) 91234-5678", "+5511912345678"])
    func internationalNumbers(input: String) throws {
        let catalog = try RegionCatalogTests.bundled()
        let spain = try #require(catalog.preset(for: "ES"))

        #expect(PhoneNormalizer(catalog: catalog).normalize(input, defaultRegion: spain) == .success("+5511912345678"))
    }

    @Test("A trunk prefix typed after the country code is dropped (+44 07700 900123)")
    func trunkAfterCountryCode() throws {
        let catalog = try RegionCatalogTests.bundled()
        let brazil = try #require(catalog.preset(for: "BR"))

        #expect(PhoneNormalizer(catalog: catalog).normalize("+44 07700 900123", defaultRegion: brazil)
            == .success("+447700900123"))
    }

    @Test("Arabic-Indic, Extended Arabic-Indic and Devanagari digits are accepted")
    func otherDigitSystems() throws {
        let catalog = try RegionCatalogTests.bundled()
        let normalizer = PhoneNormalizer(catalog: catalog)
        let uae = try #require(catalog.preset(for: "AE"))
        let india = try #require(catalog.preset(for: "IN"))
        let saudi = try #require(catalog.preset(for: "SA"))

        #expect(normalizer.normalize("٠٥٠ ١٢٣ ٤٥٦٧", defaultRegion: uae) == .success("+971501234567"))
        #expect(normalizer.normalize("९८७६५ ४३२१०", defaultRegion: india) == .success("+919876543210"))
        #expect(normalizer.normalize("۰۵ ۱۲۳۴ ۵۶۷۸", defaultRegion: saudi) == .success("+966512345678"))
        #expect(normalizer.normalize("+٩٦٦ ٥ ١٢٣٤ ٥٦٧٨", defaultRegion: uae) == .success("+966512345678"))
    }

    @Test("Bad input is rejected with a reason, never silently accepted")
    func rejections() throws {
        let catalog = try RegionCatalogTests.bundled()
        let normalizer = PhoneNormalizer(catalog: catalog)
        let brazil = try #require(catalog.preset(for: "BR"))

        #expect(normalizer.normalize("", defaultRegion: brazil) == .failure(.empty))
        #expect(normalizer.normalize("   ", defaultRegion: brazil) == .failure(.empty))
        #expect(normalizer.normalize("abc", defaultRegion: brazil) == .failure(.empty))
        #expect(normalizer.normalize("12345", defaultRegion: brazil) == .failure(.tooShort))
        #expect(normalizer.normalize("+55 11 91", defaultRegion: brazil) == .failure(.tooShort))
        #expect(normalizer.normalize("+55 11 9123", defaultRegion: brazil) == .failure(.implausibleLength))
        #expect(normalizer.normalize("(11) 9123-45678-99", defaultRegion: brazil) == .failure(.tooLong))
        #expect(normalizer.normalize("(11) 9123-456", defaultRegion: brazil) == .failure(.implausibleLength))
        #expect(normalizer.normalize("+5511912345678901234", defaultRegion: brazil) == .failure(.tooLong))
    }

    @Test("A country that has no preset is kept as typed")
    func unknownCountry() throws {
        let catalog = try RegionCatalogTests.bundled()
        let brazil = try #require(catalog.preset(for: "BR"))

        #expect(PhoneNormalizer(catalog: catalog).normalize("+31 6 12345678", defaultRegion: brazil)
            == .success("+31612345678"))
    }

    @Test("wa.me digits are the E.164 number without the plus", arguments: [
        ("+5511912345678", "5511912345678"), ("+351912345678", "351912345678"), ("+971501234567", "971501234567")
    ])
    func whatsAppDigits(e164: String, expected: String) {
        #expect(PhoneNormalizer.whatsAppDigits(fromE164: e164) == expected)
    }
}
