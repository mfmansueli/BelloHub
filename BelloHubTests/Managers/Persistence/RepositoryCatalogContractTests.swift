//
//  RepositoryCatalogContractTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// What the services, add-ons, products and credentials must do in every vault implementation. Run against both
/// flavors, like the other contract suites, so the in-memory repository can never promise something the real one does
/// not. The first group is the exit criterion of S5: contraindication and patch-test settings persist.
@Suite("Repository contract: services and catalog", .serialized)
struct RepositoryCatalogContractTests {
    private let fixture = ContractFixture()

    // MARK: - Services: the settings persist

    @Test("Contraindications and the patch-test settings come back as saved", arguments: RepositoryFlavor.allCases)
    func serviceSettingsPersist(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        let peel = Service(
            name: "Chemical Peel", category: "Facial", durationMinutes: 45, priceAmount: Decimal(string: "120.5"),
            priceDisplay: .startingFrom, followUpWeeks: 6, remindBeforeAfterPhotos: true, aftercareTemplate: "",
            isActive: false, position: 3, contraindications: ["pregnancy", "allergies.retinol", "minor", "free note"],
            requiresPatchTest: true, patchTestHoursBefore: 72
        )

        try await repository.save(peel)

        let read = try #require(try await repository.services().first)
        #expect(read == peel)
        #expect(read.contraindications == ["pregnancy", "allergies.retinol", "minor", "free note"])
        #expect(read.requiresPatchTest && read.patchTestHoursBefore == 72)
        #expect(read.aftercareTemplate == "", "an empty template (on, words to come) is not the same as none")
    }

    @Test("Switching the settings off is stored too", arguments: RepositoryFlavor.allCases)
    func serviceSettingsClear(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        var service = Service(
            name: "Peel", durationMinutes: 30, aftercareTemplate: "Rest.", contraindications: ["pregnancy"],
            requiresPatchTest: true
        )
        try await repository.save(service)
        service.contraindications = []
        service.requiresPatchTest = false
        service.aftercareTemplate = nil

        try await repository.save(service)

        let read = try #require(try await repository.services().first)
        #expect(read.contraindications.isEmpty && !read.requiresPatchTest && read.aftercareTemplate == nil)
        #expect(try await repository.services().count == 1)
    }

    @Test("Several services are stored together and listed by new positions", arguments: RepositoryFlavor.allCases)
    func saveSeveralServices(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        let services = ["A", "B", "C"].enumerated().map { Service(name: $1, durationMinutes: 30, position: $0) }
        try await repository.save(services)
        #expect(try await repository.services().map(\.name) == ["A", "B", "C"])

        let reordered = PositionRules.moving(services, from: IndexSet(integer: 0), to: 3)
        try await repository.save(PositionRules.changed(from: services, to: reordered))

        #expect(try await repository.services().map(\.name) == ["B", "C", "A"])
        #expect(try await repository.services().map(\.position) == [0, 1, 2])
    }

    @Test("Deleting a service leaves the others and the appointments' names", arguments: RepositoryFlavor.allCases)
    func deleteService(flavor: RepositoryFlavor) async throws {
        let (repository, client) = try fixture.seeded(flavor)
        try await repository.save(client)
        let glow = Service(name: "Glow", durationMinutes: 60, position: 0)
        let peel = Service(name: "Peel", durationMinutes: 30, position: 1)
        try await repository.save([glow, peel])
        let start = TestClock.date("2026-10-08 09:00")
        let appointment = Appointment(
            clientID: client.id, serviceID: glow.id, serviceName: "Glow", startsAt: start,
            endsAt: start.addingTimeInterval(3600), createdAt: start
        )
        try await repository.save(appointment)

        try await repository.deleteService(id: glow.id)

        #expect(try await repository.services().map(\.name) == ["Peel"])
        #expect(try await repository.appointment(id: appointment.id)?.serviceName == "Glow")
    }

    // MARK: - Add-ons

    @Test("An add-on is stored, updated, listed in order and deleted", arguments: RepositoryFlavor.allCases)
    func addOns(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        let tint = AddOn(id: UUID(), name: "Eyebrow tint", minutes: 15, priceAmount: 20, isOffered: true, position: 1)
        let led = AddOn(id: UUID(), name: "LED light", minutes: 10, priceAmount: nil, isOffered: false, position: 0)
        try await repository.save(tint)
        try await repository.save(led)

        #expect(try await repository.addOns() == [led, tint], "in position order, every field intact")

        var updated = tint
        updated.isOffered = false
        updated.priceAmount = Decimal(string: "22.5")
        try await repository.save(updated)
        #expect(try await repository.addOns().count == 2)
        #expect(try await repository.addOns().last == updated)

        try await repository.deleteAddOn(id: led.id)
        #expect(try await repository.addOns() == [updated])
        try await repository.deleteAddOn(id: led.id)
        #expect(try await repository.addOns().count == 1, "deleting twice is safe")
    }

    @Test("Several add-ons are stored together", arguments: RepositoryFlavor.allCases)
    func saveSeveralAddOns(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        let list = ["A", "B", "C"].enumerated().map {
            AddOn(id: UUID(), name: $1, minutes: 10, priceAmount: nil, isOffered: true, position: $0)
        }
        try await repository.save(list)
        let reordered = PositionRules.moving(list, from: IndexSet(integer: 2), to: 0)
        try await repository.save(reordered)
        #expect(try await repository.addOns().map(\.name) == ["C", "A", "B"])
    }

    // MARK: - Products

    @Test("A product is stored, shared, listed in order and deleted", arguments: RepositoryFlavor.allCases)
    func products(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        let serum = Product(name: "Calming serum", brand: "Acme", category: .serum, note: "Fragrance-free", position: 0)
        let cream = Product(name: "Barrier cream", category: .moisturizer, sharedWithClient: true, position: 1)
        try await repository.save(cream)
        try await repository.save(serum)

        #expect(try await repository.products() == [serum, cream])
        #expect(try await repository.products().first?.sharedWithClient == false, "private by default")

        var shared = serum
        shared.sharedWithClient = true
        try await repository.save(shared)
        #expect(try await repository.products().first?.sharedWithClient == true)

        try await repository.deleteProduct(id: cream.id)
        #expect(try await repository.products() == [shared])
    }

    @Test("Several products are stored together", arguments: RepositoryFlavor.allCases)
    func saveSeveralProducts(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        let list = ["A", "B"].enumerated().map { Product(name: $1, position: $0) }
        try await repository.save(list)
        #expect(try await repository.products().map(\.name) == ["A", "B"])
    }

    // MARK: - Credentials

    @Test("Credentials and the registration are stored, switched together, and deleted",
          arguments: RepositoryFlavor.allCases)
    func credentials(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        let course = Credential(title: "Aesthetics technical course", institution: "Senac SP", year: 2019, position: 0)
        let registration = Credential(kind: .registration, title: "", registrationNumber: "COREN 123", position: 1)
        try await repository.save(registration)
        try await repository.save(course)

        #expect(try await repository.credentials() == [course, registration])

        let hidden = [course, registration].map { item -> Credential in
            var changed = item
            changed.showOnBookingPage = false
            return changed
        }
        try await repository.save(hidden)
        #expect(try await repository.credentials().allSatisfy { !$0.showOnBookingPage })
        #expect(try await repository.credentials().last?.registrationNumber == "COREN 123")

        try await repository.deleteCredential(id: registration.id)
        #expect(try await repository.credentials().map(\.title) == ["Aesthetics technical course"])
    }

    // MARK: - Storage

    @Test("None of the catalog is sealed: it is what she offers and shows, not clinical")
    func nothingIsSealed() {
        #expect(AddOn.sensitiveKeys.isEmpty && Product.sensitiveKeys.isEmpty && Credential.sensitiveKeys.isEmpty)
        #expect(Service.sensitiveKeys.isEmpty)
    }

    @Test("Each kind is stored under its own vault kind")
    func kinds() {
        #expect(AddOn.kind == .addOn && Product.kind == .product && Credential.kind == .credential)
    }

    @Test("An unknown credential kind from a newer version reads as a training and keeps the rest")
    func unknownCredentialKind() throws {
        let json = Data("""
        {"id": "\(UUID().uuidString)", "kind": "futureKind", "title": "Course", "institution": "",
         "showOnBookingPage": true, "position": 0}
        """.utf8)
        let decoded = try JSONDecoder().decode(Credential.self, from: json)
        #expect(decoded.kind == .training && decoded.title == "Course")
    }

    @Test("Nothing in the catalog touches the registration ledger", arguments: RepositoryFlavor.allCases)
    func ledgerUntouched(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        try await repository.save(
            AddOn(id: UUID(), name: "A", minutes: 5, priceAmount: nil, isOffered: true, position: 0)
        )
        try await repository.save(Product(name: "P"))
        try await repository.save(Credential(title: "C"))
        try await repository.save(Service(name: "S", durationMinutes: 30))
        #expect(try await repository.registrationLedger().isEmpty)
        #expect(try await repository.allClients().isEmpty)
    }
}
