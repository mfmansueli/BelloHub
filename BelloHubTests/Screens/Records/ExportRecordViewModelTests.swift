//
//  ExportRecordViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("ExportRecordViewModel", .serialized)
struct ExportRecordViewModelTests {
    private struct World {
        let model: ExportRecordViewModel
        let exporter: FakeRecordExporter
        let client: Client
        let repository: any ClientRecordRepository
    }

    private func makeWorld(exporterFails: Bool = false) async throws -> World {
        let world = try await ClientsWorld.make()
        var client = makeClient(name: "Ana Costa")
        client.allergies = ["Latex"]
        _ = try await world.repository.save(client)
        try await world.repository.save(makeRecord(clientID: client.id, notes: "PRIVATE-OBSERVATION"))
        try await world.repository.save(makeConsent(clientID: client.id))
        let exporter = FakeRecordExporter()
        exporter.fails = exporterFails
        let model = ExportRecordViewModel(
            clientID: client.id, vault: world.vault, profile: world.profile, exporter: exporter,
            locale: Locale(identifier: "en"), now: { TestClock.now },
            resolve: { $0.resolved(in: Locale(identifier: "en")) }
        )
        await model.loadAsync()
        return World(model: model, exporter: exporter, client: client, repository: world.repository)
    }

    @Test("The sheet opens on the form with the counts for her card")
    func opens() async throws {
        let world = try await makeWorld()
        #expect(world.model.phase == .form)
        #expect(world.model.summary.treatmentCount == 1)
        #expect(world.model.summary.consentSignedAt != nil)
        #expect(world.model.options == ExportOptions())
        #expect(world.model.canExport)
    }

    @Test("Exporting builds the document from the vault and hands it to the exporter")
    func exports() async throws {
        let world = try await makeWorld()
        await world.model.exportAsync()
        guard case .ready(let file) = world.model.phase else {
            Issue.record("expected a ready file")
            return
        }
        #expect(file.fileName == "Ana-Costa-record.pdf")
        let document = try #require(world.exporter.exported.first)
        #expect(document.title.contains("Ana Costa"))
        let text = String(describing: document)
        #expect(text.contains("Latex"))
        #expect(!text.contains("PRIVATE-OBSERVATION"))
    }

    @Test("A health professional's copy with internal notes on includes them")
    func doctorCopy() async throws {
        let world = try await makeWorld()
        world.model.setAudience(.healthProfessional)
        world.model.options.includeInternalNotes = true
        await world.model.exportAsync()
        #expect(String(describing: world.exporter.exported.first as Any).contains("PRIVATE-OBSERVATION"))
    }

    @Test("A photo that is private is not in the client's copy and its bytes are never read")
    func privatePhotoStaysOut() async throws {
        let world = try await makeWorld()
        var photo = makePhoto(clientID: world.client.id, kind: .before, visibility: .professionalOnly)
        photo.clientID = world.client.id
        try await world.repository.save(photo, data: PhotoData(image: Data("SECRET-BYTES".utf8), thumbnail: Data([1])))
        world.model.options.includePhotos = true
        await world.model.exportAsync()
        let document = try #require(world.exporter.exported.first)
        #expect(!document.sections.contains { $0.heading == "Photos" })
    }

    @Test("A failing exporter leaves the form with an error and no file")
    func exportFails() async throws {
        let world = try await makeWorld(exporterFails: true)
        await world.model.exportAsync()
        #expect(world.model.phase == .form)
        #expect(world.model.exportErrorMessage != nil)
        world.model.dismissExportError()
        #expect(world.model.exportErrorMessage == nil)
    }

    @Test("A finished share deletes the file; a cancelled one keeps it for another try")
    func sharing() async throws {
        let world = try await makeWorld()
        await world.model.exportAsync()
        world.model.shareFinished(completed: false)
        guard case .ready(let file) = world.model.phase else {
            Issue.record("a cancelled share keeps the file")
            return
        }
        #expect(world.exporter.discarded.isEmpty)
        world.model.shareFinished(completed: true)
        #expect(world.model.phase == .shared)
        #expect(world.exporter.discarded == [file])
    }

    @Test("Leaving the screen deletes the file, and with no file there is nothing to delete")
    func leaving() async throws {
        let world = try await makeWorld()
        world.model.discardFile()
        #expect(world.exporter.discarded.isEmpty)
        await world.model.exportAsync()
        world.model.discardFile()
        #expect(world.exporter.discarded.count == 1)
        #expect(world.model.phase == .form)
    }

    @Test("The client's copy turns the internal-notes switch off for good")
    func clientCopyNotesRule() async throws {
        let world = try await makeWorld()
        world.model.options.includeInternalNotes = true
        #expect(world.model.options.effectiveIncludesInternalNotes == false)
        world.model.setAudience(.healthProfessional)
        #expect(world.model.options.effectiveIncludesInternalNotes)
    }

    @Test("A client who is gone is said")
    func missing() async throws {
        let world = try await ClientsWorld.make()
        let model = ExportRecordViewModel(
            clientID: UUID(), vault: world.vault, profile: world.profile, exporter: FakeRecordExporter()
        )
        await model.loadAsync()
        #expect(model.phase == .missing)
    }
}
