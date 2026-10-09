//
//  ImportColumnMapperTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ImportColumnMapper")
struct ImportColumnMapperTests {
    private func makeTable(_ text: String, hasHeader: Bool? = nil) -> ImportTable {
        ImportTable(document: CSVParser.parse(text), hasHeader: hasHeader)
    }

    private func detect(_ text: String) -> ImportColumnMapping {
        ImportColumnMapper.detect(in: makeTable(text))
    }

    // MARK: - Titles in the product's languages

    struct HeaderCase: Sendable {
        let language: String
        let header: String
        let name: Int
        let phone: Int
        let email: Int?
    }

    static let headerCases: [HeaderCase] = [
        HeaderCase(language: "pt-BR", header: "Nome;Telefone;E-mail", name: 0, phone: 1, email: 2),
        HeaderCase(language: "pt-BR celular", header: "Cliente;Celular;E-mail", name: 0, phone: 1, email: 2),
        HeaderCase(language: "pt-PT", header: "Nome;Telemóvel;Email", name: 0, phone: 1, email: 2),
        HeaderCase(language: "es", header: "Nombre;Teléfono;Correo electrónico", name: 0, phone: 1, email: 2),
        HeaderCase(language: "es móvil", header: "Cliente;Móvil;Correo", name: 0, phone: 1, email: 2),
        HeaderCase(language: "en", header: "Name,Phone,Email", name: 0, phone: 1, email: 2),
        HeaderCase(language: "en whatsapp", header: "Full name,WhatsApp,Email address", name: 0, phone: 1, email: 2),
        HeaderCase(language: "it", header: "Nome;Cellulare;E-mail", name: 0, phone: 1, email: 2),
        HeaderCase(language: "fr", header: "Nom;Téléphone;Courriel", name: 0, phone: 1, email: 2),
        HeaderCase(language: "fr portable", header: "Nom complet;Portable;Adresse e-mail", name: 0, phone: 1,
                   email: 2),
        HeaderCase(language: "de", header: "Name;Telefonnummer;E-Mail", name: 0, phone: 1, email: 2),
        HeaderCase(language: "de handy", header: "Kunde;Handy;E-Mail", name: 0, phone: 1, email: 2),
        HeaderCase(language: "tr", header: "Ad Soyad;Cep Telefonu;E-posta", name: 0, phone: 1, email: 2),
        HeaderCase(language: "id", header: "Nama;Nomor Telepon;Email", name: 0, phone: 1, email: 2),
        HeaderCase(language: "id hp", header: "Nama Lengkap;No HP;Email", name: 0, phone: 1, email: 2),
        HeaderCase(language: "hi", header: "नाम;फ़ोन;ईमेल", name: 0, phone: 1, email: 2),
        HeaderCase(language: "ar", header: "الاسم;رقم الهاتف;البريد الإلكتروني", name: 0, phone: 1, email: 2),
        HeaderCase(language: "ar reversed columns", header: "الجوال;الاسم", name: 1, phone: 0, email: nil),
        HeaderCase(language: "columns in another order", header: "E-mail;Telefone;Nome", name: 2, phone: 1, email: 0),
        HeaderCase(language: "upper case and spaces", header: " NOME  COMPLETO ; TELEFONE ", name: 0, phone: 1,
                   email: nil)
    ]

    @Test("The columns are found from the titles in every language", arguments: headerCases)
    func titles(testCase: HeaderCase) {
        let delimiter = testCase.header.contains(";") ? ";" : ","
        let cells = testCase.header.components(separatedBy: delimiter)
        let row = cells.map { _ in "x" }.joined(separator: delimiter)

        let mapping = detect("\(testCase.header)\n\(row)")

        #expect(mapping.name == testCase.name, "\(testCase.language): name")
        #expect(mapping.phone == testCase.phone, "\(testCase.language): phone")
        #expect(mapping.email == testCase.email, "\(testCase.language): email")
    }

    @Test("Google Contacts: first and last name, the value column and not the label column")
    func googleContacts() {
        let text = """
        First Name,Middle Name,Last Name,Phone 1 - Label,Phone 1 - Value,E-mail 1 - Value
        Ana,Maria,Costa,Mobile,+55 11 98765-4321,ana@example.com
        """

        let mapping = detect(text)

        #expect(mapping == ImportColumnMapping(name: 0, lastName: 2, phone: 4, email: 5))
    }

    @Test("Outlook: the mobile phone wins over the home phone")
    func outlook() {
        let text = "First Name,Last Name,E-mail Address,Home Phone,Mobile Phone\nAna,Costa,a@b.co,111,222"

        let mapping = detect(text)

        #expect(mapping.phone == 4)
        #expect(mapping.lastName == 1)
        #expect(mapping.email == 2)
    }

    @Test("An exact title beats a title that only contains the word")
    func exactBeatsContains() {
        let mapping = detect("Phone type;Contact phone;Phone\nx;y;z")

        #expect(mapping.phone == 2, "'Phone type' is a kind column, 'Contact phone' only contains the word")
    }

    @Test("A column is used for one part only")
    func oneColumnOnePart() {
        let mapping = detect("Telefone\n11 98765-4321")

        #expect(mapping.phone == 0)
        #expect(mapping.name == nil)
    }

    // MARK: - The values decide when the titles do not

    @Test("A file with no header is read by its values: name, phone, e-mail")
    func valuesWithoutHeader() {
        let text = """
        Ana Costa,+55 11 98765-4321,ana@example.com
        Bia Lima,(21) 99888-7766,bia@example.com
        Carla Dias,31 98877-6655,
        """

        let table = makeTable(text)
        let mapping = ImportColumnMapper.detect(in: table)

        #expect(!table.hasHeader)
        #expect(table.rows.count == 3)
        #expect(mapping == ImportColumnMapping(name: 0, lastName: nil, phone: 1, email: 2))
    }

    @Test("A header in a language the product does not know is still mapped by the values")
    func unknownLanguageHeader() {
        let text = """
        Naam;Nummer van de klant
        Jan de Vries;+31 6 12345678
        Els Bakker;+31 6 87654321
        """

        let mapping = detect(text)

        #expect(mapping.name == 0)
        #expect(mapping.phone == 1)
    }

    @Test("A single column of names has no header and is the name column")
    func namesOnly() {
        let table = makeTable("Ana Costa\nBia Lima\nCarla Dias")

        #expect(!table.hasHeader)
        #expect(ImportColumnMapper.detect(in: table) == ImportColumnMapping(name: 0))
    }

    @Test("Digits in a column of words do not make it a phone column")
    func wordsAreNotPhones() {
        let mapping = detect("Nome;Cidade\nAna;Lisboa\nBia;Porto")

        #expect(mapping.phone == nil)
    }

    // MARK: - The header row

    @Test("The first row is a header when a cell names a part of a client")
    func headerByTitle() {
        #expect(makeTable("Nome,Telefone\nAna,123").hasHeader)
    }

    @Test("The first row is data when it already holds a phone number")
    func dataWhenPhone() {
        #expect(!makeTable("Ana,+55 11 98765-4321\nBia,+55 21 99888-7766").hasHeader)
    }

    @Test("The first row is a header when only the rows below hold phones")
    func headerByNeighbors() {
        #expect(makeTable("Pessoa,Contato\nAna,11 98765-4321\nBia,21 99888-7766").hasHeader)
    }

    @Test("She can correct the guess, and the columns are guessed again")
    func headerToggle() {
        let table = makeTable("Pessoa,Contato\nAna,11 98765-4321")
        #expect(table.hasHeader)

        let withoutHeader = table.settingHeader(false)

        #expect(!withoutHeader.hasHeader)
        #expect(withoutHeader.rows.count == 2)
        #expect(withoutHeader.rows.first?.number == 1)
        #expect(table.settingHeader(true).rows.count == 1)
    }

    @Test("Blank rows (ghost rows of commas) are dropped and the row numbers stay those of the file")
    func ghostRows() {
        let table = makeTable("Nome,Telefone\nAna,123\n,\n\nBia,456\n,,,")

        #expect(table.rows.map(\.number) == [2, 5])
    }

    @Test("An empty file or a file with only a header has no rows")
    func noRows() {
        #expect(makeTable("").isEmpty)
        #expect(makeTable("Nome,Telefone").isEmpty)
    }

    // MARK: - Candidates

    @Test("Candidates take the name, phones and e-mail from the chosen columns")
    func candidates() {
        let table = makeTable("Nome;Telefone;E-mail\nAna Costa;11 98765-4321;ana@example.com\nBia;;")
        let mapping = ImportColumnMapper.detect(in: table)

        let candidates = ImportColumnMapper.candidates(from: table, mapping: mapping)

        #expect(candidates.map(\.name) == ["Ana Costa", "Bia"])
        #expect(candidates[0].phoneNumbers.map(\.raw) == ["11 98765-4321"])
        #expect(candidates[0].email == "ana@example.com")
        #expect(candidates[1].phoneNumbers.isEmpty && candidates[1].email == nil)
        #expect(candidates.map(\.id) == ["row-2", "row-3"])
        #expect(candidates.map(\.rowNumber) == [2, 3])
    }

    @Test("A first and a last name column are joined, unless the name already holds the last name")
    func joinedNames() {
        let table = makeTable("First Name,Last Name\nAna,Costa\nBia Lima,Lima\n,Dias")
        let mapping = ImportColumnMapper.detect(in: table)

        let names = ImportColumnMapper.candidates(from: table, mapping: mapping).map(\.name)

        #expect(names == ["Ana Costa", "Bia Lima", "Dias"])
    }

    @Test("Several numbers in one cell are several numbers")
    func severalNumbers() {
        let table = makeTable("Nome;Telefone\nAna;11 98765-4321 / 11 3333-4444\nBia;\"21 99888-7766; 21 2222-3333\"")
        let mapping = ImportColumnMapper.detect(in: table)

        let candidates = ImportColumnMapper.candidates(from: table, mapping: mapping)

        #expect(candidates[0].phoneNumbers.map(\.raw).map { $0.trimmingCharacters(in: .whitespaces) }
            == ["11 98765-4321", "11 3333-4444"])
        #expect(candidates[1].phoneNumbers.count == 2)
    }

    @Test("A limit keeps the first rows only")
    func limit() {
        let table = makeTable("Nome\nA\nB\nC\nD")

        #expect(ImportColumnMapper.candidates(from: table, mapping: ImportColumnMapping(name: 0), limit: 2).count == 2)
    }

    // MARK: - Titles of the mapping menus

    @Test("The menus list each column with its title, or its position and first value when it has none")
    func columnOptions() {
        let table = makeTable("Nome;;Telefone\nAna;x;123\nBia;;456")

        let options = ImportColumnOption.options(for: table)

        #expect(options.map(\.title) == ["Nome", nil, "Telefone"])
        #expect(options.map(\.sample) == ["Ana", "x", "123"])
    }

    // MARK: - Speed

    @Test("2,000 rows are parsed, mapped and validated in well under two seconds of CPU time")
    func twoThousandRows() throws {
        var lines = ["Nome;Telefone;E-mail"]
        for index in 1...2_000 {
            let digits = String(format: "%04d", index)
            lines.append("Cliente \(index);(11) 9\(digits)-\(digits);c\(index)@example.com")
        }
        let text = lines.joined(separator: "\n")
        let catalog = try RegionCatalogTests.bundled()
        let brazil = try #require(catalog.preset(for: "BR"))
        let mapper = ImportClientMapper(
            region: brazil, phones: PhoneNormalizer(catalog: catalog), now: TestClock.now
        )

        var entries: [ImportEntry] = []
        let elapsed = CPUTime.measure {
            let table = ImportTable(document: CSVParser.parse(text))
            let mapping = ImportColumnMapper.detect(in: table)
            entries = mapper.entries(from: ImportColumnMapper.candidates(from: table, mapping: mapping))
        }

        #expect(entries.count == 2_000)
        #expect(entries.allSatisfy { $0.isReady })
        #expect(elapsed < .seconds(2), "took \(elapsed)")
    }
}
