//
//  ServiceRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ServiceRules")
struct ServiceRulesTests {
    private let english = Locale(identifier: "en_US")
    private let brazil = Locale(identifier: "pt_BR")
    private let arabic = Locale(identifier: "ar_SA")

    private func draft(
        name: String = "Glow Facial", price: String = "", category: String = "Facial", minutes: Int = 60
    ) -> ServiceDraft {
        var draft = ServiceDraft()
        draft.name = name
        draft.priceText = price
        draft.category = category
        draft.minutes = minutes
        return draft
    }

    private func service(
        _ name: String, category: String = "Facial", position: Int = 0, id: UUID = UUID()
    ) -> Service {
        Service(id: id, name: name, category: category, durationMinutes: 60, position: position)
    }

    // MARK: - Checking

    @Test("A name taken by another service is refused, ignoring case and accents, but not by the same one")
    func nameTaken() {
        let glow = service("Glow Facial")
        #expect(ServiceRules.nameCheck("glow facial", among: [glow]) == .duplicate)
        #expect(ServiceRules.nameCheck("Glów Facial", among: [glow]) == .duplicate)
        #expect(ServiceRules.nameCheck("glow facial", among: [glow], editing: glow.id) == .accepted("glow facial"))
    }

    @Test("Issues are listed in the order the form shows them")
    func issueOrder() {
        let issues = ServiceRules.issues(in: draft(name: "", price: "abc"), among: [], locale: english)
        #expect(issues == [.nameEmpty, .priceInvalid])
        #expect(ServiceRules.issues(in: draft(), among: [], locale: english).isEmpty)
    }

    @Test("A name that is too long, or taken, is an issue of its own")
    func nameIssues() {
        let long = draft(name: String(repeating: "x", count: 61))
        #expect(ServiceRules.issues(in: long, among: [], locale: english) == [.nameTooLong])
        let taken = ServiceRules.issues(in: draft(), among: [service("Glow Facial")], locale: english)
        #expect(taken == [.nameTaken])
    }

    @Test("The price is read the way each language writes numbers", arguments: [
        ("en_US", "120.50"), ("pt_BR", "120,50"), ("ar_SA", "١٢٠٫٥٠")
    ])
    func priceReading(localeID: String, text: String) {
        let built = ServiceRules.build(draft(price: text), among: [], locale: Locale(identifier: localeID))
        #expect(built?.priceAmount == Decimal(string: "120.5"))
    }

    @Test("An empty price field is no price")
    func noPrice() {
        #expect(ServiceRules.build(draft(price: ""), among: [], locale: english)?.priceAmount == nil)
    }

    @Test("A price that is negative or not a number stops the save")
    func priceInvalid() {
        #expect(ServiceRules.build(draft(price: "-5"), among: [], locale: english) == nil)
        #expect(ServiceRules.build(draft(price: "ten"), among: [], locale: english) == nil)
    }

    // MARK: - Building

    @Test("A new service goes after the last one and takes the draft's settings")
    func buildsNew() throws {
        var form = draft(name: "  Brow   Lift ", price: "80", category: " Brows ", minutes: 45)
        form.priceDisplay = .startingFrom
        form.followUpWeeks = 6
        form.remindsPhotos = false
        form.requiresPatchTest = true
        form.patchTestHoursBefore = 72
        form.contraindications = ["pregnancy", " allergies.latex ", "pregnancy", ""]
        let id = UUID()

        let built = try #require(ServiceRules.build(
            form, among: [service("A", position: 0), service("B", position: 4)], locale: english, makeID: { id }
        ))

        #expect(built.id == id && built.position == 5)
        #expect(built.name == "Brow Lift" && built.category == "Brows" && built.durationMinutes == 45)
        #expect(built.priceAmount == 80 && built.priceDisplay == .startingFrom)
        #expect(built.followUpWeeks == 6 && !built.remindBeforeAfterPhotos)
        #expect(built.requiresPatchTest && built.patchTestHoursBefore == 72)
        #expect(built.contraindications == ["pregnancy", "allergies.latex"], "cleaned and without repeats, in order")
    }

    @Test("Editing keeps the id and the place in the list")
    func buildsEdit() throws {
        let existing = service("Glow Facial", position: 2)
        var form = draft(name: "Glow Facial Deluxe")
        form.minutes = 90
        let built = try #require(ServiceRules.build(form, among: [existing], editing: existing, locale: english))
        #expect(built.id == existing.id && built.position == 2 && built.durationMinutes == 90)
    }

    @Test("Aftercare off stores nothing; on with no words stores an empty template; words are trimmed")
    func aftercare() throws {
        var form = draft()
        func template() throws -> String? {
            try #require(ServiceRules.build(form, among: [], locale: english)).aftercareTemplate
        }
        form.sharesAftercare = false
        form.aftercareText = "ignored"
        #expect(try template() == nil)
        form.sharesAftercare = true
        form.aftercareText = ""
        #expect(try template() == "")
        form.aftercareText = "  Avoid the sun.\n"
        #expect(try template() == "Avoid the sun.")
    }

    @Test("A service becomes a form and back without losing anything", arguments: ["en_US", "pt_BR", "ar_SA"])
    func roundTrip(localeID: String) throws {
        let locale = Locale(identifier: localeID)
        let original = Service(
            name: "Protocol 360", category: "Protocol", durationMinutes: 120, priceAmount: Decimal(string: "1234.5"),
            priceDisplay: .onRequest, followUpWeeks: 8, remindBeforeAfterPhotos: true, aftercareTemplate: "Rest.",
            isActive: false, position: 3, contraindications: ["pregnancy", "minor"], requiresPatchTest: true,
            patchTestHoursBefore: 24
        )
        let form = ServiceDraft(original, locale: locale)
        let rebuilt = try #require(ServiceRules.build(form, among: [original], editing: original, locale: locale))
        #expect(rebuilt == original)
    }

    @Test("A service with no aftercare template reads back as aftercare off")
    func aftercareOffRoundTrip() throws {
        let original = Service(name: "Peel", durationMinutes: 30, aftercareTemplate: nil)
        let form = ServiceDraft(original, locale: english)
        let rebuilt = try #require(ServiceRules.build(form, among: [original], editing: original, locale: english))
        #expect(!form.sharesAftercare)
        #expect(rebuilt == original)
    }

    // MARK: - Choices

    @Test("Categories are the ones in use, in order, without repeats ignoring case, plus a new one")
    func categories() {
        let list = [service("A", category: "Facial", position: 1), service("B", category: "Body", position: 0),
                    service("C", category: "facial", position: 2), service("D", category: "", position: 3)]
        #expect(ServiceRules.categories(among: list) == ["Body", "Facial"])
        #expect(ServiceRules.categories(among: list, including: "Peel") == ["Body", "Facial", "Peel"])
        #expect(ServiceRules.categories(among: list, including: "  BODY ") == ["Body", "Facial"])
    }

    @Test("A new service starts in the category most services use, the earliest on a tie")
    func suggestedCategory() {
        let list = [service("A", category: "Body", position: 0), service("B", category: "Facial", position: 1),
                    service("C", category: "facial", position: 2)]
        #expect(ServiceRules.suggestedCategory(among: list) == "Facial")
        let tie = [service("A", category: "Body"), service("B", category: "Peel", position: 1)]
        #expect(ServiceRules.suggestedCategory(among: tie) == "Body")
        #expect(ServiceRules.suggestedCategory(among: []).isEmpty)
    }

    @Test("A duration or follow-up that is not on the list stays a choice")
    func oddValuesStay() {
        #expect(ServiceRules.durationOptions(including: 60) == OnboardingRules.durationOptions)
        #expect(ServiceRules.durationOptions(including: 55).contains(55))
        #expect(ServiceRules.durationOptions(including: 55) == ServiceRules.durationOptions(including: 55).sorted())
        #expect(ServiceRules.followUpOptions(including: nil) == OnboardingRules.followUpWeekOptions)
        #expect(ServiceRules.followUpOptions(including: 5) == [2, 3, 4, 5, 6, 8])
        #expect(ServiceRules.patchTestHourOptions(including: 48) == [24, 48, 72])
        #expect(ServiceRules.patchTestHourOptions(including: 36) == [24, 36, 48, 72])
    }

    // MARK: - The list

    @Test("The list is in order by position, then name, and a switch changes only the switch")
    func listOrder() {
        let list = [service("B", position: 1), service("A", position: 1), service("C", position: 0)]
        #expect(ServiceRules.ordered(list).map(\.name) == ["C", "A", "B"])
        let off = ServiceRules.setting(list[0], active: false)
        #expect(!off.isActive && off.name == list[0].name && off.position == list[0].position)
    }
}
