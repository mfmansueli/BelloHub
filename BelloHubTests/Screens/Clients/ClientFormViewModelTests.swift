//
//  ClientFormViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// A gate that fails, for the "something went wrong" path.
@MainActor
private final class FailingRegistrar: ClientRegistering {
    struct Failure: Error {}

    var usage = RegistrationUsage.unknown

    func refreshUsage() async {}

    func register(_ client: Client) async throws -> RegistrationOutcome {
        throw Failure()
    }

    func knownClients() async throws -> [Client] {
        throw Failure()
    }

    func importClients(_ clients: [Client]) async throws -> ClientImportResult {
        throw Failure()
    }
}

@MainActor
@Suite("ClientFormViewModel", .serialized)
struct ClientFormViewModelTests {
    private let fixedID = UUID()

    private func newModel(
        _ world: ClientsWorld, registrar: any ClientRegistering = FakeClientRegistrar()
    ) -> ClientFormViewModel {
        ClientFormViewModel(
            mode: .new, registrar: registrar, vault: world.vault, profile: world.profile, regions: world.regions,
            now: { TestClock.now }, makeID: { [fixedID] in fixedID }
        )
    }

    // MARK: - New client

    @Test("A name is enough: the client is built and sent through the registration gate, then her profile opens")
    func savesANewClient() async throws {
        let world = try await ClientsWorld.make()
        let registrar = FakeClientRegistrar()
        let model = newModel(world, registrar: registrar)
        model.draft.name = "Ana Costa"

        await model.saveAsync()

        let sent = try #require(registrar.registered.first)
        #expect(sent.name == "Ana Costa" && sent.id == fixedID && sent.source == .manual)
        #expect(model.finish == .registered(fixedID))
        #expect(!model.showsPaywall && model.duplicateNotice == nil && model.errorMessage == nil)
    }

    @Test("A missing name is said next to the field and nothing is sent; the message only shows after the first try")
    func missingName() async throws {
        let world = try await ClientsWorld.make()
        let registrar = FakeClientRegistrar()
        let model = newModel(world, registrar: registrar)
        #expect(model.nameIssue == nil, "no scolding before she tries to save")

        await model.saveAsync()

        #expect(registrar.registered.isEmpty && model.finish == nil)
        #expect(model.nameIssue == .nameMissing)
    }

    @Test("A bad number is said next to the field, and fixing it lets the save through")
    func badNumber() async throws {
        let world = try await ClientsWorld.make()
        let registrar = FakeClientRegistrar()
        let model = newModel(world, registrar: registrar)
        model.draft.name = "Ana"
        model.draft.phone = "123"

        await model.saveAsync()
        #expect(model.phoneFailure == .tooShort && registrar.registered.isEmpty)

        model.draft.phone = "(11) 98123-4410"
        #expect(model.phoneFailure == nil)
        await model.saveAsync()
        #expect(registrar.registered.first?.phoneE164 == "+5511981234410")
    }

    @Test("The number is read in the business region: a Portuguese professional reads it as Portuguese")
    func businessRegionDecidesTheNumber() async throws {
        let world = try await ClientsWorld.make(regionCode: "PT")
        let registrar = FakeClientRegistrar()
        let model = newModel(world, registrar: registrar)
        model.draft.name = "Ana"
        model.draft.phone = "912 345 678"

        await model.saveAsync()

        #expect(registrar.registered.first?.phoneE164 == "+351912345678")
    }

    @Test("When the free registrations are used the paywall comes up and nothing opens")
    func needsSubscription() async throws {
        let world = try await ClientsWorld.make()
        let registrar = FakeClientRegistrar()
        registrar.outcome = .needsSubscription
        let model = newModel(world, registrar: registrar)
        model.draft.name = "Ana"

        await model.saveAsync()

        #expect(model.showsPaywall && model.finish == nil)
    }

    @Test("A number another client has shows a notice with her id, until the number is changed")
    func duplicateNumber() async throws {
        let world = try await ClientsWorld.make()
        let registrar = FakeClientRegistrar()
        let existing = UUID()
        registrar.outcome = .duplicate(existingID: existing)
        let model = newModel(world, registrar: registrar)
        model.draft.name = "Ana"
        model.draft.phone = "+5511981234410"

        await model.saveAsync()
        #expect(model.duplicateNotice == existing && model.finish == nil)

        model.draft.phone = "+5511981234411"
        #expect(model.duplicateNotice == nil)

        model.draft.phone = "+5511981234410"
        #expect(model.duplicateNotice == existing, "the same number brings the notice back")
    }

    @Test("A gate that fails shows an error, keeps the draft and can be tried again")
    func gateFailure() async throws {
        let world = try await ClientsWorld.make()
        let model = newModel(world, registrar: FailingRegistrar())
        model.draft.name = "Ana"

        await model.saveAsync()

        #expect(model.errorMessage != nil && model.finish == nil && model.draft.name == "Ana" && !model.isSaving)
        model.dismissError()
        #expect(model.errorMessage == nil)
    }

    @Test("Unsaved changes are the ones that differ from an empty form")
    func dirty() async throws {
        let world = try await ClientsWorld.make()
        let model = newModel(world)
        #expect(!model.isDirty && model.canSave)

        model.draft.name = "A"
        #expect(model.isDirty)

        model.draft.name = "  "
        #expect(!model.isDirty)
    }

    // MARK: - Tags

    @Test("Tapping a tag puts it on the client and tapping again takes it off")
    func toggleTag() async throws {
        let world = try await ClientsWorld.make()
        let tag = try #require(world.tags.first)
        let model = newModel(world)

        model.toggleTag(tag.id)
        #expect(model.draft.tagIDs == [tag.id])

        model.toggleTag(tag.id)
        #expect(model.draft.tagIDs.isEmpty)
    }

    @Test("A new tag is saved in her setup, appears in the chips and is selected")
    func newTag() async throws {
        let world = try await ClientsWorld.make()
        let model = newModel(world)

        await model.addTag(named: "  Regular ")

        let created = try #require(world.profile.tags.first { $0.name == "Regular" })
        #expect(world.profile.tags.count == world.tags.count + 1)
        #expect(created.position == world.tags.count)
        #expect(model.draft.tagIDs == [created.id])
        #expect(model.tags.last?.id == created.id)
        #expect(try await world.repository.tags().contains { $0.id == created.id })
    }

    @Test("A tag name she already has selects the existing tag instead of making a twin")
    func existingTagIsSelected() async throws {
        let world = try await ClientsWorld.make()
        let model = newModel(world)

        await model.addTag(named: "vip")

        #expect(world.profile.tags.count == world.tags.count)
        #expect(model.draft.tagIDs == [world.tags[1].id])
        await model.addTag(named: "VIP")
        #expect(model.draft.tagIDs.count == 1)
    }

    @Test("A blank tag name does nothing")
    func blankTag() async throws {
        let world = try await ClientsWorld.make()
        let model = newModel(world)

        await model.addTag(named: "   ")

        #expect(model.draft.tagIDs.isEmpty && world.profile.tags.count == world.tags.count)
    }

    // MARK: - With the real gate (D42)

    @Test("Through the real gate a client is saved, counted, and listed in the vault")
    func realGateRegisters() async throws {
        let world = try await ClientsWorld.make()
        let gate = ClientRegistrationService(vault: world.vault)
        let model = newModel(world, registrar: gate)
        model.draft.name = "Ana Costa"
        model.draft.phone = "11 98123-4410"

        await model.saveAsync()
        await model.refreshUsage()

        #expect(model.finish == .registered(fixedID))
        #expect(try await world.repository.client(id: fixedID)?.phoneE164 == "+5511981234410")
        #expect(model.usage.used == 1)
    }

    @Test("The eleventh client needs a plan: nothing is saved and the paywall comes up")
    func realGateStopsTheEleventh() async throws {
        let world = try await ClientsWorld.make()
        for index in 0..<RegistrationQuota.freeLimit {
            try await world.repository.save(makeListedClient(name: "Client \(index)"))
        }
        let model = newModel(world, registrar: ClientRegistrationService(vault: world.vault))
        model.draft.name = "One too many"

        await model.saveAsync()

        #expect(model.showsPaywall && model.finish == nil)
        #expect(try await world.repository.client(id: fixedID) == nil)
    }

    @Test("A number that is already saved is refused by the real gate and offers the existing client")
    func realGateRefusesADuplicate() async throws {
        let world = try await ClientsWorld.make()
        let existing = makeListedClient(name: "Ana", phone: "+5511981234410")
        try await world.repository.save(existing)
        let model = newModel(world, registrar: ClientRegistrationService(vault: world.vault))
        model.draft.name = "Another Ana"
        model.draft.phone = "11 98123-4410"

        await model.saveAsync()

        #expect(model.duplicateNotice == existing.id && model.finish == nil)
        #expect(try await world.repository.allClients().count == 1)
    }

    @Test("Her first name labels the form: the first word of what is typed")
    func firstName() async throws {
        let world = try await ClientsWorld.make()
        let model = newModel(world)
        model.draft.name = "  Ana Maria Costa "

        #expect(model.firstName == "Ana")
    }
}
