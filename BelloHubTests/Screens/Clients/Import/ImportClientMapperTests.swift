//
//  ImportClientMapperTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ImportClientMapper")
struct ImportClientMapperTests {
    private func makeMapper(region: String = "BR") throws -> ImportClientMapper {
        let catalog = try RegionCatalogTests.bundled()
        let preset = try #require(catalog.preset(for: region))
        return ImportClientMapper(region: preset, phones: PhoneNormalizer(catalog: catalog), now: TestClock.now)
    }

    private func makeCandidate(
        _ name: String = "Ana Costa", phones: [ImportPhoneNumber] = [], email: String? = nil, row: Int? = nil
    ) -> ImportCandidate {
        ImportCandidate(id: "c-\(name)", name: name, phoneNumbers: phones, email: email, rowNumber: row)
    }

    private func entry(for candidate: ImportCandidate, region: String = "BR") throws -> ImportEntry {
        try makeMapper(region: region).entry(for: candidate, id: UUID())
    }

    // MARK: - A good row

    @Test("A good row becomes an imported client with a new id, the cleaned name and an E.164 phone")
    func goodRow() throws {
        let id = UUID()
        let candidate = makeCandidate("  Ana   Costa ", phones: [ImportPhoneNumber("(11) 98765-4321")],
                                      email: "Ana@Example.com")

        let result = try makeMapper().entry(for: candidate, id: id)
        let client = try #require(result.client)

        #expect(client.id == id)
        #expect(client.name == "Ana Costa")
        #expect(client.phoneE164 == "+5511987654321")
        #expect(client.email == "ana@example.com")
        #expect(client.source == .importedClients)
        #expect(client.createdAt == TestClock.now)
        #expect(result.id == candidate.id)
    }

    @Test("The business region reads a number written without a country code")
    func regionMatters() throws {
        let candidate = makeCandidate(phones: [ImportPhoneNumber("912 345 678")])

        #expect(try entry(for: candidate, region: "PT").client?.phoneE164 == "+351912345678")
        #expect(try entry(for: candidate, region: "BR").issue == .invalidPhone, "nine digits is not a Brazilian number")
    }

    @Test("A number with a country code ignores the region")
    func internationalNumber() throws {
        let candidate = makeCandidate(phones: [ImportPhoneNumber("+351 912 345 678")])

        #expect(try entry(for: candidate, region: "BR").client?.phoneE164 == "+351912345678")
    }

    @Test("The birthday of a contact comes along")
    func birthday() throws {
        var candidate = makeCandidate()
        candidate.birthday = Birthday(month: 4, day: 12, year: nil)

        #expect(try entry(for: candidate).client?.birthday == Birthday(month: 4, day: 12, year: nil))
    }

    // MARK: - The name

    @Test("A row with no name is malformed")
    func noName() throws {
        let phones = [ImportPhoneNumber("11 98765-4321")]
        for name in ["", "   ", "\n"] {
            #expect(try entry(for: makeCandidate(name, phones: phones)).issue == .nameMissing)
        }
    }

    @Test("A name must have 2 to 60 characters")
    func nameLength() throws {
        #expect(try entry(for: makeCandidate("A")).issue == .nameLength)
        #expect(try entry(for: makeCandidate("Al")).isReady)
        #expect(try entry(for: makeCandidate(String(repeating: "a", count: 60))).isReady)
        #expect(try entry(for: makeCandidate(String(repeating: "a", count: 61))).issue == .nameLength)
    }

    @Test("The row number is kept for a row that has no name to show")
    func rowNumberIsKept() throws {
        let result = try entry(for: makeCandidate("", row: 14))

        #expect(result.rowNumber == 14)
        #expect(result.displayName.isEmpty)
    }

    // MARK: - The phone

    @Test("A phone is optional: a client without one is imported without one")
    func phoneIsOptional() throws {
        let result = try entry(for: makeCandidate(phones: []))

        #expect(result.client?.phoneE164 == nil)
        #expect(try entry(for: makeCandidate(phones: [ImportPhoneNumber("   ")])).isReady)
    }

    @Test("A phone that is there but is not a number makes the row malformed",
          arguments: ["123", "abc123", "99999999999999999"])
    func invalidPhone(raw: String) throws {
        #expect(try entry(for: makeCandidate(phones: [ImportPhoneNumber(raw)])).issue == .invalidPhone)
    }

    @Test("A contact with several numbers is imported with the first mobile one that is valid")
    func firstMobile() throws {
        let candidate = makeCandidate(phones: [
            ImportPhoneNumber("(11) 3333-4444"),
            ImportPhoneNumber("(11) 98765-4321", isMobile: true),
            ImportPhoneNumber("(21) 99888-7766", isMobile: true)
        ])

        #expect(try entry(for: candidate).client?.phoneE164 == "+5511987654321")
    }

    @Test("Without a mobile number the first valid one is used, and an invalid first number is skipped")
    func firstValid() throws {
        let candidate = makeCandidate(phones: [ImportPhoneNumber("123"), ImportPhoneNumber("(11) 3333-4444")])

        #expect(try entry(for: candidate).client?.phoneE164 == "+551133334444")
    }

    @Test("A mobile number that is not valid does not beat a valid landline")
    func invalidMobileLosesToValidLandline() throws {
        let candidate = makeCandidate(phones: [
            ImportPhoneNumber("999", isMobile: true), ImportPhoneNumber("(11) 3333-4444")
        ])

        #expect(try entry(for: candidate).client?.phoneE164 == "+551133334444")
    }

    // MARK: - The e-mail

    @Test("An e-mail that is not an address makes the row malformed",
          arguments: ["not-an-email", "a@b", "@b.com", "a@@b.com"])
    func invalidEmail(raw: String) throws {
        #expect(try entry(for: makeCandidate(email: raw)).issue == .invalidEmail)
    }

    @Test("A placeholder for no e-mail is no e-mail", arguments: ["", "  ", "-", "n/a", "N/A", "sem email"])
    func placeholderEmail(raw: String) throws {
        let result = try entry(for: makeCandidate(email: raw))

        #expect(result.isReady)
        #expect(result.client?.email == nil)
    }

    // MARK: - A batch

    @Test("A batch keeps its order, with one new id per row from the supplier")
    func batch() throws {
        let mapper = try makeMapper()
        let ids = (0..<3).map { _ in UUID() }
        var index = 0

        let entries = mapper.entries(from: [makeCandidate("Ana"), makeCandidate(""), makeCandidate("Carla")]) {
            defer { index += 1 }
            return ids[index]
        }

        #expect(entries.map(\.isReady) == [true, false, true])
        #expect(entries.compactMap(\.client).map(\.id) == [ids[0], ids[2]])
    }

    @Test("Entries sort by name the way the system sorts: accents and case ignored")
    func sorting() throws {
        let mapper = try makeMapper()
        let names = ["bia", "Ana", "Álvaro", "Zélia", "ana 2", "Ana 10"]
        let entries = mapper.entries(from: names.map { makeCandidate($0) })

        let sorted = ImportClientMapper.sortedByName(entries).map(\.displayName)

        #expect(sorted == ["Álvaro", "Ana", "ana 2", "Ana 10", "bia", "Zélia"])
    }
}
