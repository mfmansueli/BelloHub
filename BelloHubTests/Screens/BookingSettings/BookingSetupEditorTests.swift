//
//  BookingSetupEditorTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("BookingSetupEditor")
@MainActor
struct BookingSetupEditorTests {
    private struct Rig {
        let editor: BookingSetupEditor
        let service: BookingSetupService
        let repository: FakeBookingSetupRepository
    }

    private func make() async throws -> Rig {
        let repository = FakeBookingSetupRepository()
        let service = BookingSetupService(repository: repository, now: { TestClock.now })
        try await service.load(timeZoneID: "America/Sao_Paulo")
        return Rig(editor: BookingSetupEditor(service: service), service: service, repository: repository)
    }

    @Test("A change is saved and becomes the stored setup")
    func applies() async throws {
        let rig = try await make()
        let editor = rig.editor
        let service = rig.service
        let repository = rig.repository
        let saved = await editor.apply { $0.noShow.limit = 5 }
        #expect(saved && editor.setup.noShow.limit == 5)
        #expect(service.setup.noShow.limit == 5)
        #expect(try await repository.bookingSetup()?.noShow.limit == 5)
        #expect(editor.saveErrorMessage == nil)
    }

    @Test("A change that changes nothing writes nothing")
    func noChange() async throws {
        let rig = try await make()
        let editor = rig.editor
        let repository = rig.repository
        let saved = await editor.apply { $0.noShow.limit = NoShowPolicy.standard.limit }
        #expect(saved)
        #expect(await repository.writeCount == 0)
    }

    @Test("A failed write goes back to what is stored and says so")
    func failure() async throws {
        let rig = try await make()
        let editor = rig.editor
        let service = rig.service
        let repository = rig.repository
        await repository.setFailsWrites(true)
        let saved = await editor.apply { $0.noShow.limit = 5 }
        #expect(!saved)
        #expect(editor.setup.noShow.limit == NoShowPolicy.standard.limit)
        #expect(service.setup.noShow.limit == NoShowPolicy.standard.limit)
        #expect(editor.saveErrorMessage?.isEmpty == false)
        editor.dismissSaveError()
        #expect(editor.saveErrorMessage == nil)
    }

    @Test("A new change clears an earlier error")
    func errorCleared() async throws {
        let rig = try await make()
        let editor = rig.editor
        let repository = rig.repository
        await repository.setFailsWrites(true)
        await editor.apply { $0.noShow.limit = 5 }
        await repository.setFailsWrites(false)
        await editor.apply { $0.noShow.limit = 4 }
        #expect(editor.saveErrorMessage == nil && editor.setup.noShow.limit == 4)
    }

    @Test("Taking the stored setup again shows what another screen saved")
    func adoptStored() async throws {
        let rig = try await make()
        let editor = rig.editor
        let service = rig.service
        var other = service.setup
        other.slug = "from-elsewhere"
        try await service.saveSetup(other)
        #expect(editor.setup.slug == nil)
        editor.adoptStored()
        #expect(editor.setup.slug == "from-elsewhere")
    }

    @Test("Two editors on one service see each other's saves after they adopt them")
    func sharedService() async throws {
        let rig = try await make()
        let first = rig.editor
        let service = rig.service
        let second = BookingSetupEditor(service: service)
        await first.apply { $0.cancellation.freeWindowHours = 48 }
        second.adoptStored()
        #expect(second.setup.cancellation.freeWindowHours == 48)
    }
}
