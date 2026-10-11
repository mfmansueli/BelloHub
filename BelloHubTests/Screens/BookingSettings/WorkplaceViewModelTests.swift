//
//  WorkplaceViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("WorkplaceViewModel")
@MainActor
struct WorkplaceViewModelTests {
    private struct Rig {
        let model: WorkplaceViewModel
        let service: BookingSetupService
        let repository: FakeBookingSetupRepository
    }

    private func make() async throws -> Rig {
        let repository = FakeBookingSetupRepository()
        let service = BookingSetupService(repository: repository, now: { TestClock.now })
        try await service.load(timeZoneID: "America/Sao_Paulo")
        let model = WorkplaceViewModel(editor: BookingSetupEditor(service: service), businessRegion: "BR")
        return Rig(model: model, service: service, repository: repository)
    }

    private func fill(_ model: WorkplaceViewModel) {
        model.street = " Rua Augusta 1200 "
        model.postalCode = "01304-001"
        model.city = "São Paulo"
        model.directions = "2º andar"
    }

    @Test("A new address starts in her business region, visible only to confirmed clients, and cannot be saved empty")
    func starts() async throws {
        let rig = try await make()
        #expect(rig.model.countryCode == "BR" && rig.model.visibility == .confirmedClients)
        #expect(!rig.model.canSave && rig.model.previewLines == nil && rig.model.appleMapsURL == nil)
    }

    @Test("The preview follows the fields; Save stores the cleaned address and then reads as saved")
    func saves() async throws {
        let rig = try await make()
        fill(rig.model)
        #expect(rig.model.previewLines == ["Rua Augusta 1200", "São Paulo 01304-001"])
        #expect(rig.model.previewDirections == "2º andar")
        #expect(rig.model.googleMapsURL != nil && rig.model.canSave)

        #expect(await rig.model.saveAsync())

        let stored = try #require(rig.service.setup.location)
        #expect(stored.street == "Rua Augusta 1200" && stored.countryCode == "BR")
        #expect(rig.model.isSaved && !rig.model.canSave)
        rig.model.visibility = .bookingPage
        #expect(rig.model.canSave && !rig.model.isSaved, "changing who sees it is a change to save")
    }

    @Test("Remove forgets the address and empties the fields")
    func removes() async throws {
        let rig = try await make()
        fill(rig.model)
        await rig.model.saveAsync()

        #expect(await rig.model.removeAsync())

        #expect(rig.service.setup.location == nil)
        #expect(rig.model.street.isEmpty && rig.model.city.isEmpty && rig.model.stored == nil)
    }

    @Test("A failed write keeps her fields, says so, and nothing is stored")
    func failure() async throws {
        let rig = try await make()
        fill(rig.model)
        await rig.repository.setFailsWrites(true)

        #expect(await rig.model.saveAsync() == false)

        #expect(rig.model.errorMessage != nil && rig.service.setup.location == nil)
        #expect(rig.model.street == " Rua Augusta 1200 ")
        rig.model.dismissError()
        #expect(rig.model.errorMessage == nil)
    }

    @Test("Too long a street is caught before saving")
    func tooLong() async throws {
        let rig = try await make()
        fill(rig.model)
        rig.model.street = String(repeating: "a", count: 121)
        #expect(rig.model.isTooLong && !rig.model.canSave)
    }
}
