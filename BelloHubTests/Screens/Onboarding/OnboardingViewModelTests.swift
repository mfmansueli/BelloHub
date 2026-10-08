//
//  OnboardingViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("OnboardingViewModel")
struct OnboardingViewModelTests {
    @MainActor
    final class FinishCounter {
        var calls = 0
    }

    private struct Rig {
        let model: OnboardingViewModel
        let vault: VaultService
        let profile: ProfileService
        let finished: FinishCounter
    }

    private func makeRig(vaultAvailable: Bool = true, professions: [ProfessionID] = []) -> Rig {
        let vault = VaultService(repository: vaultAvailable ? InMemoryClientRecordRepository() : nil)
        let profile = ProfileService(vault: vault)
        let finished = FinishCounter()
        let draft = makeDraft(professions: [], name: "")
        let model = OnboardingViewModel(
            draft: draft, catalog: makeCatalog(), profile: profile, now: { TestClock.now },
            makeID: { UUID() }, onFinished: { finished.calls += 1 }
        )
        // Through the ViewModel, so the catalog's preselected services and tags are applied as in the app.
        professions.forEach { model.toggle($0) }
        return Rig(model: model, vault: vault, profile: profile, finished: finished)
    }

    @Test("The region she picked in the first step is what gets saved")
    func regionIsSaved() async throws {
        let rig = makeRig(professions: [.hair])
        let regions = try RegionCatalog.loadBundled()
        let model = OnboardingViewModel(
            draft: makeDraft(professions: [], name: "Maria"), catalog: makeCatalog(), profile: rig.profile,
            regions: regions, deviceTimeZoneID: "America/Sao_Paulo", onFinished: {}
        )
        #expect(model.region?.code == "BR")
        model.setRegion(try #require(regions.preset(for: "PT")))
        model.toggle(.hair)

        await model.finishAsync()

        let stored = try #require(try await rig.vault.repository?.profile())
        #expect(stored.regionCode == "PT" && stored.currencyCode == "EUR" && stored.timeZoneID == "Europe/Lisbon")
    }

    @Test("Continue stays off until the step is valid, and the steps move forward and back")
    func navigation() {
        let rig = makeRig()
        let model = rig.model
        #expect(model.step == .about && !model.canContinue)
        model.goNext()
        #expect(model.step == .about)

        model.setDisplayName("Maria")
        model.goNext()
        #expect(model.step == .profession && model.isMovingForward)
        model.goNext()
        #expect(model.step == .profession)

        model.toggle(.esthetician)
        model.goNext()
        #expect(model.step == .services)

        model.goBack()
        #expect(model.step == .profession && !model.isMovingForward)
    }

    @Test("Choosing a profession preselects its services and tags, and dropping it removes them")
    func professionChoice() {
        let model = makeRig().model
        model.toggle(.esthetician)
        #expect(model.isServiceSelected("est.glow") && model.isServiceSelected("shared.consult"))
        #expect(!model.isServiceSelected("est.peel"))
        #expect(model.isTagSelected("est.sensitive") && !model.isTagSelected("est.vip"))

        model.toggleService("est.peel")
        model.toggle(.hair)
        #expect(model.isServiceSelected("hair.cut") && model.isServiceSelected("est.peel"))
        #expect(model.suggestedServices.count == 4)

        model.toggle(.esthetician)
        #expect(!model.isServiceSelected("est.peel") && !model.isServiceSelected("est.glow"))
        #expect(model.isServiceSelected("hair.cut"))
        #expect(model.draft.professions == [.hair])
    }

    @Test("Custom services are added only when valid, and can be removed")
    func customServices() {
        let model = makeRig(professions: [.esthetician]).model
        #expect(!model.addCustomService(DraftService(name: " ")))
        let service = DraftService(name: "Brazilian Glow", priceAmount: 120, minutes: 90)
        #expect(model.addCustomService(service))
        #expect(model.draft.customServices.map(\.name) == ["Brazilian Glow"])
        #expect(model.knownNames.contains("Brazilian Glow"))
        model.removeCustomService(id: service.id)
        #expect(model.draft.customServices.isEmpty)
    }

    @Test("Names she adds are cleaned and never repeat a service she already has")
    func vocabulary() {
        let model = makeRig(professions: [.esthetician]).model
        #expect(model.addVocabulary("  Protocolo   360 ", kind: .protocolName))
        #expect(!model.addVocabulary("protocolo 360", kind: .protocolName))
        #expect(!model.addVocabulary("glow facial", kind: .service))
        #expect(!model.addVocabulary("   ", kind: .service))
        #expect(model.draft.vocabulary.map(\.text) == ["Protocolo 360"])
        #expect(model.draft.vocabulary.first?.kind == .protocolName)
        let id = model.draft.vocabulary[0].id
        model.removeVocabulary(id: id)
        #expect(model.draft.vocabulary.isEmpty)
    }

    @Test("Her own tags cannot repeat a suggested one")
    func customTags() {
        let model = makeRig(professions: [.esthetician]).model
        #expect(!model.addCustomTag("vip"))
        #expect(model.addCustomTag("Neighbor"))
        #expect(!model.addCustomTag("neighbor"))
        #expect(model.draft.customTags == ["Neighbor"])
        model.removeCustomTag("Neighbor")
        #expect(model.draft.customTags.isEmpty)
    }

    @Test("The record step starts on her first profession and counts the fields that are on")
    func recordFields() throws {
        let model = makeRig(professions: [.esthetician, .hair]).model
        #expect(model.recordProfession == .esthetician)
        let fields = model.fields(of: .esthetician)
        let skin = try #require(fields.first { $0.key == "est.skin" })
        let technique = try #require(fields.first { $0.key == "est.technique" })
        #expect(model.isFieldOn(skin, of: .esthetician) && !model.isFieldOn(technique, of: .esthetician))
        #expect(model.onCount(for: .esthetician) == 1)

        model.setField(technique, of: .esthetician, on: true)
        model.setField(skin, of: .esthetician, on: false)
        #expect(model.onCount(for: .esthetician) == 1)
        #expect(model.isFieldOn(technique, of: .esthetician))

        // Putting a switch back where the catalog had it leaves no override behind.
        model.setField(technique, of: .esthetician, on: false)
        model.setField(skin, of: .esthetician, on: true)
        #expect(model.draft.fieldOverrides.isEmpty)

        model.showRecord(of: .hair)
        #expect(model.recordProfession == .hair)
        model.toggle(.hair)
        #expect(model.recordProfession == .esthetician)
    }

    @Test("Intake switches start from the catalog and remember only what she changed")
    func intake() {
        let model = makeRig(professions: [.esthetician]).model
        #expect(model.isIntakeOn(.healthHistory, of: .esthetician))
        #expect(!model.isIntakeOn(.patchTestLog, of: .esthetician))
        model.setIntake(.patchTestLog, of: .esthetician, on: true)
        model.setIntake(.healthHistory, of: .esthetician, on: false)
        #expect(model.isIntakeOn(.patchTestLog, of: .esthetician))
        #expect(!model.isIntakeOn(.healthHistory, of: .esthetician))
        model.setIntake(.patchTestLog, of: .esthetician, on: false)
        #expect(model.draft.intakeOverrides.count == 1)
    }

    @Test("Finishing saves the whole workspace together and tells the app once")
    func finish() async throws {
        let rig = makeRig(professions: [.esthetician])
        rig.model.setDisplayName("Maria Silva")
        rig.model.setClientTerm(.patient)
        rig.model.toggleTag("est.vip")

        await rig.model.finishAsync()

        #expect(rig.finished.calls == 1)
        #expect(rig.model.errorMessage == nil)
        let repository = try #require(rig.vault.repository)
        let stored = try #require(try await repository.profile())
        #expect(stored.displayName == "Maria Silva" && stored.clientTerm == .patient)
        #expect(try await repository.services().map(\.name) == ["Glow Facial", "Consultation"])
        #expect(try await repository.tags().map(\.name) == ["VIP", "Sensitive Skin"])
        #expect(try await repository.recordTemplate()?.enabledKeys(for: .esthetician) == ["est.skin"])
        #expect(rig.profile.profile?.displayName == "Maria Silva")
        #expect(rig.profile.clientTerm == .patient)
    }

    @Test("When the vault cannot be opened nothing is reported as finished and she can try again")
    func finishFails() async {
        let rig = makeRig(vaultAvailable: false, professions: [.esthetician])
        rig.model.setDisplayName("Maria Silva")

        await rig.model.finishAsync()

        #expect(rig.finished.calls == 0)
        #expect(rig.model.errorMessage != nil)
        #expect(!rig.model.isSaving)
        #expect(rig.profile.profile == nil)
    }

    @Test("A second tap while saving does nothing")
    func finishOnce() async {
        let rig = makeRig(professions: [.hair])
        rig.model.setDisplayName("Maria")
        async let first: Void = rig.model.finishAsync()
        async let second: Void = rig.model.finishAsync()
        _ = await (first, second)
        #expect(rig.finished.calls == 1)
    }
}

@Suite("OnboardingDraft")
struct OnboardingDraftTests {
    private let regions = (try? RegionCatalog.loadBundled()) ?? RegionCatalog(presets: [])

    private func initial(region: String?, language: String?, preferred: [String], zone: String) -> OnboardingDraft {
        OnboardingDraft.initial(
            regions: regions, deviceRegion: region, languageCode: language, preferredLanguages: preferred,
            deviceTimeZoneID: zone
        )
    }

    @Test("A phone in Brazil starts as Brazil, in Portuguese, in the phone's time zone")
    func brazil() {
        let draft = initial(region: "BR", language: "pt", preferred: ["pt-BR"], zone: "America/Manaus")
        #expect(draft.regionCode == "BR" && draft.currencyCode == "BRL")
        #expect(draft.localization == .ptBR)
        #expect(draft.timeZoneID == "America/Manaus")
        #expect(draft.bookingLocaleIDs == ["pt-BR", "en"])
    }

    @Test("A time zone outside the region falls back to the region's first one")
    func timeZoneFallback() {
        let draft = initial(region: "PT", language: "pt", preferred: ["pt-PT"], zone: "Asia/Tokyo")
        #expect(draft.regionCode == "PT" && draft.timeZoneID == "Europe/Lisbon" && draft.localization == .ptPT)
    }

    @Test("A region without a preset still gets a usable start")
    func unknownRegion() {
        let draft = initial(region: "NL", language: "nl", preferred: ["nl-NL"], zone: "Europe/Amsterdam")
        #expect(!draft.regionCode.isEmpty && !draft.currencyCode.isEmpty)
        #expect(draft.localization == .enGB)
    }

    @Test("Moving the business to another region changes currency, time zone and booking languages only")
    func changeRegion() throws {
        var draft = initial(region: "BR", language: "pt", preferred: ["pt-BR"], zone: "America/Sao_Paulo")
        let portugal = try #require(regions.preset(for: "PT"))

        draft.changeRegion(to: portugal, deviceTimeZoneID: "America/Sao_Paulo")

        #expect(draft.regionCode == "PT" && draft.currencyCode == "EUR")
        #expect(draft.timeZoneID == "Europe/Lisbon")
        #expect(draft.bookingLocaleIDs == portugal.localizations)
        #expect(draft.localization == .ptBR)

        // A phone whose time zone the new region also uses keeps it.
        let spain = try #require(regions.preset(for: "ES"))
        draft.changeRegion(to: spain, deviceTimeZoneID: "Atlantic/Canary")
        #expect(draft.timeZoneID == "Atlantic/Canary")
    }

    @Test("A Spanish phone in the United States speaks the Mexican voice")
    func spanishInTheUnitedStates() {
        let draft = initial(region: "US", language: "es", preferred: ["es-US"], zone: "America/New_York")
        #expect(draft.regionCode == "US" && draft.localization == .esMX)
    }
}
