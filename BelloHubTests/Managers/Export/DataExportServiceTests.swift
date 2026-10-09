//
//  DataExportServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// Export all my data (7.8, D18): read from the vault, built on the device into a protected temp file, deleted when
/// the screen is done. Nothing goes anywhere else.
@MainActor
@Suite("DataExportService")
struct DataExportServiceTests {
    private func makeRepository() async throws -> any ClientRecordRepository {
        let repository: any ClientRecordRepository = InMemoryClientRecordRepository()
        try await repository.save(ProfessionalProfile(
            displayName: "Maria Silva", businessName: "Glow", regionCode: "BR", timeZoneID: "America/Sao_Paulo",
            currencyCode: "BRL", appLocaleID: "pt-BR", createdAt: TestClock.now
        ))
        let ana = makeClient(name: "Ana Costa")
        _ = try await repository.save(ana)
        _ = try await repository.save(makeClient(name: "Bia Lima"))
        try await repository.save(makeAppointment(clientID: ana.id, daysFromNow: -3))
        try await repository.save(TreatmentRecord(
            clientID: ana.id, serviceName: "Glow Facial", createdAt: TestClock.days(-3), notes: "Sentinel-RECORD"
        ))
        return repository
    }

    @Test("Prepare writes a ZIP with the spreadsheets and the PDF into a protected temp file; discard removes it")
    func prepareAndDiscard() async throws {
        let repository = try await makeRepository()
        let service = DataExportService(vault: VaultService(repository: repository), now: { TestClock.now })
        let profile = try await repository.profile()

        let file = try #require(await service.prepare(
            contents: ExportContents(), locale: Locale(identifier: "en"), profile: profile
        ))

        #expect(service.errorMessage == nil)
        #expect(file.url.lastPathComponent.hasPrefix("bellohub-export-"))
        #expect(file.url.path.hasPrefix(FileManager.default.temporaryDirectory.path), "the app's own temp folder")
        #if !targetEnvironment(simulator)
        // The simulator stores no data-protection class; a device does.
        let attributes = try FileManager.default.attributesOfItem(atPath: file.url.path)
        #expect(attributes[.protectionKey] as? FileProtectionType == .complete)
        #endif
        let archive = try Data(contentsOf: file.url)
        let text = String(bytes: archive, encoding: .isoLatin1) ?? ""
        #expect(text.contains("clients.csv") && text.contains("appointments.csv") && text.contains("records.csv"))
        #expect(text.contains("summary.pdf"))
        #expect(text.contains("Ana Costa") && text.contains("Bia Lima"))
        #expect(text.contains("Sentinel-RECORD"))
        #expect(text.contains("%PDF"), "a real PDF was rendered")
        #expect(!text.contains("photos/"), "photos were not asked for")

        service.discard()

        #expect(service.file == nil)
        #expect(!FileManager.default.fileExists(atPath: file.url.path))
        #expect(!FileManager.default.fileExists(atPath: file.url.deletingLastPathComponent().path))
    }

    @Test("A second prepare replaces the first file, and the vault being unavailable gives a message")
    func replaceAndUnavailable() async throws {
        let repository = try await makeRepository()
        let service = DataExportService(vault: VaultService(repository: repository), now: { TestClock.now })
        let first = try #require(await service.prepare(contents: ExportContents(), locale: Locale(identifier: "en"),
                                                        profile: nil))
        let second = try #require(await service.prepare(contents: ExportContents(), locale: Locale(identifier: "en"),
                                                         profile: nil))
        #expect(!FileManager.default.fileExists(atPath: first.url.path))
        #expect(FileManager.default.fileExists(atPath: second.url.path))
        service.discard()

        let closed = DataExportService(vault: VaultService(repository: nil))
        let none = await closed.prepare(contents: ExportContents(), locale: Locale(identifier: "en"), profile: nil)
        #expect(none == nil)
        #expect(closed.errorMessage != nil)
    }
}
