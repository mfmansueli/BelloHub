//
//  ClientFormRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ClientFormRules")
struct ClientFormRulesTests {
    private let calendar = TestClock.calendar()
    private let brazil = ClientFormRules(
        catalog: (try? RegionCatalog.loadBundled()) ?? RegionCatalog(presets: []), regionCode: "BR"
    )

    private func issues(_ draft: ClientFormDraft, original: Client? = nil) -> [ClientFormRules.Issue] {
        brazil.issues(in: draft, original: original, now: TestClock.now, calendar: calendar)
    }

    // MARK: - Validation

    @Test("Only a name is required: a draft with a name and nothing else is valid")
    func nameOnly() {
        #expect(issues(ClientFormDraft(name: "Ana Costa")).isEmpty)
        #expect(issues(ClientFormDraft(name: "   ")) == [.nameMissing])
        #expect(issues(ClientFormDraft()) == [.nameMissing])
    }

    @Test("A national number is read in the business region and saved in international form")
    func phoneIsNormalizedWithTheBusinessRegion() throws {
        let client = try #require(brazil.newClient(
            from: ClientFormDraft(name: "Ana", phone: "(11) 98123-4410"), id: UUID(), now: TestClock.now,
            calendar: calendar
        ))

        #expect(client.phoneE164 == "+5511981234410")
    }

    @Test("A number with its own country code keeps it, whatever the business region")
    func internationalNumberKeepsItsCountry() throws {
        let client = try #require(brazil.newClient(
            from: ClientFormDraft(name: "Zoe", phone: "+1 415 555 2671"), id: UUID(), now: TestClock.now,
            calendar: calendar
        ))

        #expect(client.phoneE164 == "+14155552671")
    }

    @Test("A number that cannot be right is a problem next to the field, and nothing is built")
    func badPhone() {
        let draft = ClientFormDraft(name: "Ana", phone: "123")

        #expect(issues(draft) == [.phone(.tooShort)])
        #expect(brazil.phoneIssue(in: draft) == .tooShort)
        #expect(brazil.newClient(from: draft, id: UUID(), now: TestClock.now, calendar: calendar) == nil)
    }

    @Test("Without a known business region only numbers with a country code pass")
    func noRegion() {
        let catalog = (try? RegionCatalog.loadBundled()) ?? RegionCatalog(presets: [])
        let rules = ClientFormRules(catalog: catalog, regionCode: nil)

        #expect(rules.phoneIssue(in: ClientFormDraft(name: "A", phone: "11 98123-4410")) != nil)
        #expect(rules.phoneIssue(in: ClientFormDraft(name: "A", phone: "+55 11 98123-4410")) == nil)
    }

    @Test("An email is optional and only checked lightly", arguments: [
        ("ana@example.com", true), ("a.b+c@sub.example.org", true), ("ana@example", false), ("ana@", false),
        ("@example.com", false), ("ana example@x.com", false), ("ana@@example.com", false), ("ana@.com", false),
        ("ana@example.", false)
    ])
    func emailCheck(email: String, plausible: Bool) {
        #expect(ClientFormRules.isPlausibleEmail(email) == plausible)
        let found = issues(ClientFormDraft(name: "Ana", email: email))
        #expect(found.contains(.emailInvalid) == !plausible)
    }

    @Test("A blank email is not a problem and is saved as nothing")
    func blankEmail() throws {
        let client = try #require(brazil.newClient(
            from: ClientFormDraft(name: "Ana", email: "  "), id: UUID(), now: TestClock.now, calendar: calendar
        ))

        #expect(client.email == nil)
    }

    @Test("A new client is manual, counts as created now, and keeps her tags and her private note")
    func newClientFields() throws {
        let tag = UUID()
        let id = UUID()
        let client = try #require(brazil.newClient(
            from: ClientFormDraft(name: "  Ana Costa ", tagIDs: [tag], importantNote: " Allergic to fragrance "),
            id: id, now: TestClock.now, calendar: calendar
        ))

        #expect(client.id == id)
        #expect(client.name == "Ana Costa")
        #expect(client.source == .manual)
        #expect(client.createdAt == TestClock.now)
        #expect(client.tagIDs == [tag])
        #expect(client.importantNote == "Allergic to fragrance")
        #expect(!client.isArchived && client.remindersEnabled && !client.onlineBookingStopped)
    }

    // MARK: - Editing

    @Test("The edit draft starts from the client, with her number written the way people read it")
    func draftForClient() {
        var client = makeListedClient(
            name: "Ana Costa", phone: "+5511981234410", tagIDs: [UUID()], email: "ana@example.com"
        )
        client.birthday = Birthday(month: 3, day: 14, year: nil)
        client.onlineBookingStopped = true
        client.stopReason = "Moved away"

        let draft = brazil.draft(for: client)

        #expect(draft.name == "Ana Costa")
        #expect(draft.phone == brazil.displayPhone("+5511981234410"))
        #expect(draft.email == "ana@example.com")
        #expect(draft.birthday == BirthdayInput(day: 14, month: 3, year: nil))
        #expect(draft.onlineBookingStopped && draft.stopReason == "Moved away")
    }

    @Test("Saving an edit without touching the number keeps the stored number, even one the rules would refuse")
    func untouchedNumberIsKept() throws {
        let client = makeListedClient(name: "Ana", phone: "+5511981234410")
        var draft = brazil.draft(for: client)
        draft.name = "Ana C."

        let updated = try #require(brazil.updated(client, from: draft, now: TestClock.now, calendar: calendar))

        #expect(updated.phoneE164 == "+5511981234410")
        #expect(updated.name == "Ana C.")

        let odd = makeListedClient(name: "Odd", phone: "+5511123")
        let oddDraft = brazil.draft(for: odd)
        #expect(brazil.updated(odd, from: oddDraft, now: TestClock.now, calendar: calendar)?.phoneE164 == "+5511123")
    }

    @Test("Changing the number to a bad one is refused, and clearing it removes it")
    func changedNumber() throws {
        let client = makeListedClient(name: "Ana", phone: "+5511981234410")
        var draft = brazil.draft(for: client)

        draft.phone = "12"
        #expect(brazil.updated(client, from: draft, now: TestClock.now, calendar: calendar) == nil)
        #expect(issues(draft, original: client) == [.phone(.tooShort)])

        draft.phone = ""
        let cleared = try #require(brazil.updated(client, from: draft, now: TestClock.now, calendar: calendar))
        #expect(cleared.phoneE164 == nil)
    }

    @Test("An edit leaves everything the form does not show exactly as it was")
    func editKeepsWhatItDoesNotShow() throws {
        var client = makeListedClient(name: "Ana", importantNote: "Private note")
        client.allergies = ["fragrance"]
        client.sensitivities = ["cheeks"]
        client.preferences = ["quiet room"]
        client.recurringRequests = ["gentle pressure"]
        client.source = .referral
        client.isArchived = true
        var draft = brazil.draft(for: client)
        draft.name = "Ana C."

        let updated = try #require(brazil.updated(client, from: draft, now: TestClock.now, calendar: calendar))

        #expect(updated.importantNote == "Private note")
        #expect(updated.allergies == ["fragrance"])
        #expect(updated.sensitivities == ["cheeks"] && updated.preferences == ["quiet room"])
        #expect(updated.recurringRequests == ["gentle pressure"])
        #expect(updated.source == .referral && updated.isArchived)
        #expect(updated.id == client.id && updated.createdAt == client.createdAt)
    }

    @Test("The stop reason only survives while online booking is stopped")
    func stopReason() throws {
        let client = makeListedClient(name: "Ana")
        var draft = brazil.draft(for: client)
        draft.onlineBookingStopped = true
        draft.stopReason = " Asked to pause "

        let stopped = try #require(brazil.updated(client, from: draft, now: TestClock.now, calendar: calendar))
        #expect(stopped.onlineBookingStopped && stopped.stopReason == "Asked to pause")

        draft.onlineBookingStopped = false
        let resumed = try #require(brazil.updated(stopped, from: draft, now: TestClock.now, calendar: calendar))
        #expect(!resumed.onlineBookingStopped && resumed.stopReason == nil)
    }

    @Test("A birthday needs a day and a month together, and the year may be left out")
    func birthdayInTheForm() throws {
        let client = makeListedClient(name: "Ana")
        var draft = brazil.draft(for: client)

        draft.birthday = BirthdayInput(day: 14, month: nil, year: nil)
        #expect(issues(draft) == [.birthday(.incomplete)])

        draft.birthday = BirthdayInput(day: 14, month: 3, year: nil)
        let saved = try #require(brazil.updated(client, from: draft, now: TestClock.now, calendar: calendar))
        #expect(saved.birthday == Birthday(month: 3, day: 14, year: nil))
    }

    // MARK: - Unsaved changes

    @Test("A new form is dirty as soon as anything is typed, but not for spaces alone")
    func dirtyNewForm() {
        let empty = ClientFormDraft()

        #expect(!ClientFormRules.isDirty(ClientFormDraft(name: "  "), comparedTo: empty))
        #expect(ClientFormRules.isDirty(ClientFormDraft(name: "A"), comparedTo: empty))
        #expect(ClientFormRules.isDirty(ClientFormDraft(importantNote: "x"), comparedTo: empty))
        #expect(ClientFormRules.isDirty(ClientFormDraft(tagIDs: [UUID()]), comparedTo: empty))
    }

    @Test("An edit form is dirty only when something really changed: spacing and tag order do not count")
    func dirtyEditForm() {
        let tags = [UUID(), UUID()]
        let client = makeListedClient(name: "Ana", phone: "+5511981234410", tagIDs: tags)
        let initial = brazil.draft(for: client)
        var same = initial
        same.name = " Ana "
        same.tagIDs = tags.reversed()
        same.stopReason = "ignored while booking is not stopped"
        var changed = initial
        changed.email = "ana@example.com"

        #expect(!ClientFormRules.isDirty(same, comparedTo: initial))
        #expect(ClientFormRules.isDirty(changed, comparedTo: initial))
    }

    // MARK: - Tags

    @Test("New tags take the colors in turn and wrap around")
    func tagColors() {
        let tokens = (0..<6).map(ClientFormRules.tagColorToken(forPosition:))

        #expect(Array(tokens.prefix(4)) == ClientFormRules.tagColorTokens)
        #expect(tokens[4] == tokens[0] && tokens[5] == tokens[1])
        #expect(ClientFormRules.tagColorToken(forPosition: -3) == tokens[0])
    }
}
