//
//  OnboardingBuilderTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("OnboardingBuilder")
struct OnboardingBuilderTests {
    private let catalog = makeCatalog()
    private let now = TestClock.now

    private func build(_ draft: OnboardingDraft) -> OnboardingResult {
        var counter = 0
        return OnboardingBuilder.build(draft: draft, catalog: catalog, now: now) {
            counter += 1
            return UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", counter)) ?? UUID()
        }
    }

    @Test("The profile carries what she typed, cleaned, and what the phone said")
    func profile() {
        var draft = makeDraft(professions: [.esthetician, .hair], name: "  Maria   Silva ")
        draft.businessName = " Maria  Beauty "
        draft.clientTerm = .patient
        draft.vocabulary = [VocabularyTerm(text: "Protocolo 360", kind: .protocolName)]

        let profile = build(draft).profile

        #expect(profile.displayName == "Maria Silva")
        #expect(profile.businessName == "Maria Beauty")
        #expect(profile.regionCode == "BR")
        #expect(profile.currencyCode == "BRL")
        #expect(profile.timeZoneID == "America/Sao_Paulo")
        #expect(profile.professions == [.esthetician, .hair])
        #expect(profile.clientTerm == .patient)
        #expect(profile.vocabulary.map(\.text) == ["Protocolo 360"])
        #expect(profile.createdAt == now)
        #expect(profile.id == ProfessionalProfile.singletonID)
        #expect(profile.firstName == "Maria")
        #expect(profile.bookingLocaleIDs == ["pt-BR", "en"])
    }

    @Test("Only the selected services are created, in order, with the catalog's follow-up and photo reminders")
    func services() {
        var draft = makeDraft(professions: [.esthetician])
        draft.selectedServiceKeys = ["est.glow", "shared.consult"]

        let services = build(draft).services

        #expect(services.map(\.name) == ["Glow Facial", "Consultation"])
        #expect(services.map(\.position) == [0, 1])
        #expect(services[0].durationMinutes == 60)
        #expect(services[0].followUpWeeks == 4)
        #expect(services[0].remindBeforeAfterPhotos)
        #expect(services[1].followUpWeeks == nil)
        #expect(services.allSatisfy { $0.priceAmount == nil && $0.isActive })
    }

    @Test("A custom service keeps her price and turns aftercare into an empty template")
    func customService() {
        var draft = makeDraft(professions: [.esthetician])
        let custom = DraftService(
            id: UUID(), name: " Brazilian  Glow ", category: "Facial", priceAmount: 120, minutes: 90,
            followUpWeeks: 4, remindsPhotos: true, sharesAftercare: true
        )
        let quiet = DraftService(name: "Quiet", remindsPhotos: false, sharesAftercare: false)
        draft.customServices = [custom, quiet]

        let services = build(draft).services

        #expect(services.map(\.name) == ["Brazilian Glow", "Quiet"])
        #expect(services[0].priceAmount == 120)
        #expect(services[0].durationMinutes == 90)
        #expect(services[0].aftercareTemplate == "")
        #expect(services[1].aftercareTemplate == nil)
        #expect(!services[1].remindBeforeAfterPhotos)
        #expect(services.map(\.position) == [0, 1])
    }

    @Test("Tags are the selected suggestions then her own, with rotating colors")
    func tags() {
        var draft = makeDraft(professions: [.esthetician])
        draft.selectedTagKeys = ["est.sensitive"]
        draft.customTags = ["Bridal", "Regular", "Mom", "Neighbor", "Fifth"]

        let tags = build(draft).tags

        #expect(tags.map(\.name) == ["Sensitive Skin", "Bridal", "Regular", "Mom", "Neighbor", "Fifth"])
        #expect(tags[0].colorToken == "sage")
        #expect(tags[1...].map(\.colorToken) == ["rose", "sage", "peach", "sand", "rose"])
        #expect(tags.map(\.position) == [0, 1, 2, 3, 4, 5])
    }

    @Test("The record template starts from the catalog's defaults and applies her switches")
    func template() {
        var draft = makeDraft(professions: [.esthetician, .hair])
        draft.fieldOverrides["esthetician|est.technique"] = true
        draft.fieldOverrides["hair|hair.formula"] = false
        draft.intakeOverrides["esthetician|patchTestLog"] = true
        draft.intakeOverrides["esthetician|consentForm"] = false

        let template = build(draft).template

        #expect(template.enabledKeys(for: .esthetician) == ["est.skin", "est.technique"])
        #expect(template.enabledKeys(for: .hair).isEmpty)
        #expect(template.fields(for: .hair).count == 1)
        #expect(template.isIntakeOn(.healthHistory, for: .esthetician))
        #expect(!template.isIntakeOn(.consentForm, for: .esthetician))
        #expect(template.isIntakeOn(.patchTestLog, for: .esthetician))
        #expect(template.isIntakeOn(.patchTestLog, for: .hair))
        #expect(!template.isIntakeOn(.healthHistory, for: .hair))
        #expect(template.intake.count == 2 * IntakeItem.allCases.count)
        #expect(template.id == RecordTemplate.singletonID)
    }

    @Test("Choices for a profession she then dropped are not stored")
    func droppedProfession() {
        var draft = makeDraft(professions: [.hair])
        draft.selectedServiceKeys = ["est.glow", "hair.cut"]
        draft.fieldOverrides["esthetician|est.skin"] = false

        let result = build(draft)

        #expect(result.services.map(\.name) == ["Haircut"])
        #expect(result.template.fields(for: .esthetician).isEmpty)
    }

    @Test("The same draft always gives the same result")
    func deterministic() {
        var draft = makeDraft(professions: [.esthetician, .hair])
        draft.selectedServiceKeys = ["est.glow", "hair.cut"]
        draft.selectedTagKeys = ["est.vip"]
        #expect(build(draft) == build(draft))
    }
}
