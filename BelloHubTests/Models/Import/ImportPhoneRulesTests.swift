//
//  ImportPhoneRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ImportPhoneRules")
struct ImportPhoneRulesTests {
    private func pick(_ numbers: [ImportPhoneNumber], region: String = "BR") throws -> ImportPhoneRules.Pick {
        let catalog = try RegionCatalogTests.bundled()
        let preset = try #require(catalog.preset(for: region))
        return ImportPhoneRules.pick(from: numbers, normalizer: PhoneNormalizer(catalog: catalog), region: preset)
    }

    @Test("No numbers, or only blank ones, is no phone")
    func none() throws {
        #expect(try pick([]) == .none)
        #expect(try pick([ImportPhoneNumber(""), ImportPhoneNumber("  \n")]) == .none)
    }

    @Test("The first mobile number wins over an earlier landline")
    func mobileWins() throws {
        let numbers = [ImportPhoneNumber("(11) 3333-4444"), ImportPhoneNumber("(11) 98765-4321", isMobile: true)]

        #expect(try pick(numbers) == .valid("+5511987654321"))
    }

    @Test("With no mobile label the first valid number wins")
    func firstValidWins() throws {
        #expect(try pick([ImportPhoneNumber("(11) 98765-4321"), ImportPhoneNumber("(21) 99888-7766")])
            == .valid("+5511987654321"))
    }

    @Test("Numbers that are not numbers are invalid, but one valid number is enough")
    func invalidAndValid() throws {
        #expect(try pick([ImportPhoneNumber("123")]) == .invalid)
        #expect(try pick([ImportPhoneNumber("123"), ImportPhoneNumber("(11) 98765-4321")]) == .valid("+5511987654321"))
    }

    // MARK: - Cells

    @Test("A cell with several numbers is split on slashes, semicolons, bars, commas and line breaks")
    func splitCells() {
        let cell = "11 98765-4321 / 21 99888-7766; 31 98877-6655 | 41 3333-4444, 51 2222-3333\n61 1111-2222"

        let numbers = ImportPhoneRules.numbers(inCell: cell).map { $0.raw.trimmingCharacters(in: .whitespaces) }

        #expect(numbers == [
            "11 98765-4321", "21 99888-7766", "31 98877-6655", "41 3333-4444", "51 2222-3333", "61 1111-2222"
        ])
    }

    @Test("A number written with its own punctuation stays one number")
    func punctuationStays() {
        #expect(ImportPhoneRules.numbers(inCell: "+55 (11) 98765-4321").count == 1)
        #expect(ImportPhoneRules.numbers(inCell: "").isEmpty)
    }

    @Test("A Windows line break between numbers is a separator too")
    func crlf() {
        #expect(ImportPhoneRules.numbers(inCell: "11 98765-4321\r\n21 99888-7766").count == 2)
    }

    // MARK: - Looks like a phone

    @Test("What looks like a phone number", arguments: [
        "+55 11 98765-4321", "(11) 98765-4321", "11987654321", "912 345 678", "+1 (415) 555-2671", "0412 345 678",
        "٠٥٠ ١٢٣ ٤٥٦٧", "९८७६५ ४३२१०"
    ])
    func looksLikePhone(value: String) {
        #expect(ImportPhoneRules.looksLikePhone(value))
    }

    @Test("What does not",
          arguments: ["", "Ana Costa", "ana@example.com", "123", "1234567890123456", "12/03/2026x", "Rua 7"])
    func doesNotLookLikePhone(value: String) {
        #expect(!ImportPhoneRules.looksLikePhone(value))
    }
}
