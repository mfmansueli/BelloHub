//
//  ExportBundleBuilderTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// Exit criterion of S10: the export is built from fixtures, on the device, as CSV spreadsheets and a PDF in a ZIP.
@Suite("ExportBundleBuilder and ZipWriter")
struct ExportBundleBuilderTests {
    private let builder = ExportBundleBuilder(
        formatters: Formatters(
            locale: Locale(identifier: "en_US"), timeZone: TimeZone(identifier: "America/Sao_Paulo") ?? .current,
            currencyCode: "BRL"
        ),
        locale: Locale(identifier: "en"), now: TestClock.now
    )

    private func makeSnapshot() -> ExportSnapshot {
        let tag = Tag(id: UUID(), name: "VIP", colorToken: "rose", position: 0)
        let ana = Client(
            name: "Ana, Costa", phoneE164: "+5511987654321", email: "ana@example.com", tagIDs: [tag.id],
            createdAt: TestClock.days(-30), importantNote: "Says \"hi\"", allergies: ["fragrance", "latex"]
        )
        let bia = Client(name: "Bia", createdAt: TestClock.days(-10))
        var snapshot = ExportSnapshot()
        snapshot.profile = ProfessionalProfile(
            displayName: "Maria Silva", businessName: "Glow Studio", regionCode: "BR",
            timeZoneID: "America/Sao_Paulo", currencyCode: "BRL", appLocaleID: "pt-BR", createdAt: TestClock.now
        )
        snapshot.clients = [bia, ana]
        snapshot.tags = [tag]
        snapshot.appointments = [
            makeAppointment(clientID: ana.id, daysFromNow: -3),
            makeAppointment(clientID: ana.id, daysFromNow: -20, status: .cancelled),
            makeAppointment(clientID: bia.id, daysFromNow: 2, status: .confirmed)
        ]
        snapshot.records = [TreatmentRecord(
            clientID: ana.id, serviceName: "Glow Facial", createdAt: TestClock.days(-3), notes: "Line one\nLine two",
            technique: "Peel", productsUsed: ["Serum A", "Mask B"]
        )]
        return snapshot
    }

    @Test("The clients spreadsheet is sorted by name, counts completed visits and escapes commas, quotes and lines")
    func clientsTable() {
        let table = builder.clientsTable(makeSnapshot())

        #expect(table.header.first == "Name")
        #expect(table.rows.map { $0[0] } == ["Ana, Costa", "Bia"])
        let ana = table.rows[0]
        #expect(ana[1] == "+5511987654321")
        #expect(ana[4] == "VIP")
        #expect(ana[5] == "1", "only the completed visit counts")
        #expect(ana[8] == "fragrance; latex")
        #expect(ana[11] == "No")
        let text = table.text
        #expect(text.contains("\"Ana, Costa\""))
        #expect(text.contains("\"Says \"\"hi\"\"\""))
        #expect(text.hasSuffix("\r\n"))
        #expect(table.data.prefix(3) == Data([0xEF, 0xBB, 0xBF]), "a BOM so Excel reads UTF-8")
        #expect(CSVTable.escaped("a\nb") == "\"a\nb\"")
    }

    @Test("Appointments and records carry the client's name, never her id")
    func appointmentsAndRecords() {
        let snapshot = makeSnapshot()
        let appointments = builder.appointmentsTable(snapshot)
        #expect(appointments.rows.count == 3)
        #expect(appointments.rows.map { $0[0] } == ["Ana, Costa", "Ana, Costa", "Bia"], "oldest first")
        #expect(appointments.rows[0][5] == "cancelled")

        let records = builder.recordsTable(snapshot)
        #expect(records.rows.count == 1)
        #expect(records.rows[0][0] == "Ana, Costa")
        #expect(records.rows[0].contains("Serum A; Mask B"))
        #expect(!records.text.contains(snapshot.clients[1].id.uuidString))
    }

    @Test("The archive holds the three spreadsheets and the PDF, photos only when asked, under a dated name")
    func entriesAndName() throws {
        let snapshot = makeSnapshot()
        let pdf = Data("%PDF-1.4 test".utf8)

        let entries = builder.entries(snapshot, pdf: pdf, contents: ExportContents(includesPhotos: false))

        #expect(entries.map(\.name) == ["clients.csv", "appointments.csv", "records.csv", "summary.pdf"])
        #expect(entries[3].data == pdf)
        #expect(builder.archiveName().hasPrefix("bellohub-export-20"))
        #expect(builder.archiveName().hasSuffix(".zip"))
        #expect(ExportBundleBuilder.fileSafe("Ana / Costa <3") == "Ana  Costa 3")
        #expect(ExportBundleBuilder.birthdayText(try #require(Birthday(month: 3, day: 5, year: nil))) == "--03-05")
        #expect(ExportBundleBuilder.birthdayText(try #require(Birthday(month: 5, day: 14, year: 1990))) == "1990-05-14")
    }

    @Test("The summary names the business, the date and the counts")
    func summary() {
        let summary = builder.summary(makeSnapshot())

        #expect(summary.title == "Bello Hub export")
        #expect(summary.lines.contains("Business: Glow Studio"))
        #expect(summary.lines.contains("2 clients, 3 appointments, 1 records"))
    }

    @Test("The ZIP has one local header per entry with the right CRC and size, and an end record with the count")
    func zip() {
        let entries = [
            ExportEntry(name: "clients.csv", data: Data("a,b\r\n".utf8)),
            ExportEntry(name: "photos/Ana/1.jpg", data: Data([0xFF, 0xD8, 0xFF]))
        ]

        let archive = ZipWriter(now: TestClock.now).archive(entries)

        #expect(archive.readUInt32(at: 0) == 0x0403_4B50, "local file header signature")
        #expect(archive.readUInt32(at: 14) == ZipWriter.crc32(entries[0].data))
        #expect(archive.readUInt32(at: 18) == 5 && archive.readUInt32(at: 22) == 5)
        #expect(archive.readUInt16(at: 26) == 11, "name length")
        #expect(String(data: archive.subdata(in: 30..<41), encoding: .utf8) == "clients.csv")
        #expect(archive.subdata(in: 41..<46) == entries[0].data)
        let end = archive.count - 22
        #expect(archive.readUInt32(at: end) == 0x0605_4B50, "end of central directory")
        #expect(archive.readUInt16(at: end + 10) == 2, "two entries")
        #expect(ZipWriter.crc32(Data("123456789".utf8)) == 0xCBF4_3926, "the CRC-32 check value")
    }
}

private extension Data {
    func readUInt32(at offset: Int) -> UInt32 {
        (0..<4).reduce(UInt32(0)) { $0 | UInt32(self[startIndex + offset + $1]) << (8 * UInt32($1)) }
    }

    func readUInt16(at offset: Int) -> UInt16 {
        UInt16(self[startIndex + offset]) | UInt16(self[startIndex + offset + 1]) << 8
    }
}
