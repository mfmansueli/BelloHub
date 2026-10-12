//
//  HealthFormTemplateRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("HealthFormTemplateRules")
struct HealthFormTemplateRulesTests {
    private let catalog = makeHealthCatalog()

    // MARK: - Which questions a profession is offered

    @Test("A question with no professions is offered to everyone; one with professions only to them")
    func applicability() {
        let allergies = catalog.question(for: "allergies")
        let scalp = catalog.question(for: "scalp")
        #expect(allergies.map { HealthFormTemplateRules.applies($0, to: [.barber]) } == true)
        #expect(scalp.map { HealthFormTemplateRules.applies($0, to: [.hair]) } == true)
        #expect(scalp.map { HealthFormTemplateRules.applies($0, to: [.esthetician]) } == false)
        #expect(scalp.map { HealthFormTemplateRules.applies($0, to: [.esthetician, .hair]) } == true)
    }

    @Test("A professional with no profession yet is offered what Other gets")
    func noProfession() {
        let keys = HealthFormTemplateRules.applicableQuestions(in: catalog, for: []).map(\.key)
        #expect(keys == ["allergies", "medication", "notes"])
    }

    @Test("The default keys are the applicable questions that start on, in catalog order")
    func defaultKeys() {
        #expect(HealthFormTemplateRules.defaultKeys(in: catalog, for: [.esthetician])
                == ["allergies", "medication", "pregnancy", "notes"])
        #expect(HealthFormTemplateRules.defaultKeys(in: catalog, for: [.hair])
                == ["allergies", "medication", "scalp", "notes"])
        #expect(HealthFormTemplateRules.defaultKeys(in: catalog, for: [.hair, .lash])
                == ["allergies", "medication", "pregnancy", "scalp", "notes"])
    }

    @Test("The first template is version 1 with the defaults and the default review period")
    func defaultTemplate() {
        let template = HealthFormTemplateRules.defaultTemplate(in: catalog, for: [.lash], now: TestClock.now)
        #expect(template.version == 1)
        #expect(template.questionKeys == ["allergies", "medication", "pregnancy", "notes"])
        #expect(template.reviewEveryMonths == 12)
        #expect(template.createdAt == TestClock.now && template.updatedAt == TestClock.now)
    }

    @Test("The editor also lists a question that is on although it no longer applies to her professions")
    func offeredKeepsWhatIsOn() {
        let template = makeHealthTemplate(keys: ["allergies", "scalp"])
        let offered = HealthFormTemplateRules.offeredQuestions(in: catalog, for: [.esthetician], template: template)
        #expect(offered.map(\.key) == ["allergies", "medication", "pregnancy", "sunExposure", "scalp", "notes"])
        let without = HealthFormTemplateRules.offeredQuestions(in: catalog, for: [.esthetician], template: nil)
        #expect(!without.map(\.key).contains("scalp"))
    }

    // MARK: - Versions

    @Test("The same questions and the same months change nothing, whatever order the keys come in")
    func unchangedEdit() {
        let current = makeHealthTemplate()
        let edited = HealthFormTemplateRules.edited(
            current, enabling: ["notes", "pregnancy", "medication", "allergies"], reviewEveryMonths: 12,
            in: catalog, now: TestClock.now
        )
        #expect(edited == current)
    }

    @Test("Changing only how often she asks again keeps the version and updates it")
    func monthsOnly() {
        let current = makeHealthTemplate(version: 3, months: 12)
        let edited = HealthFormTemplateRules.edited(
            current, enabling: Set(current.questionKeys), reviewEveryMonths: 6, in: catalog, now: TestClock.now
        )
        #expect(edited.version == 3 && edited.reviewEveryMonths == 6)
        #expect(edited.questionKeys == current.questionKeys)
        #expect(edited.createdAt == current.createdAt && edited.updatedAt == TestClock.now)
    }

    @Test("Changing the questions creates the next version in catalog order, and never touches the old one")
    func newVersion() {
        let current = makeHealthTemplate(version: 2)
        let edited = HealthFormTemplateRules.edited(
            current, enabling: ["notes", "allergies", "sunExposure"], reviewEveryMonths: 24, in: catalog,
            now: TestClock.now
        )
        #expect(edited.version == 3)
        #expect(edited.questionKeys == ["allergies", "sunExposure", "notes"])
        #expect(edited.reviewEveryMonths == 24)
        #expect(edited.createdAt == TestClock.now)
        #expect(edited.id != current.id)
        #expect(current.questionKeys == ["allergies", "medication", "pregnancy", "notes"])
    }

    @Test("A question key this version does not know is kept when the questions change")
    func unknownKeysSurvive() {
        let current = makeHealthTemplate(keys: ["allergies", "fromTheFuture"])
        let edited = HealthFormTemplateRules.edited(
            current, enabling: ["allergies", "medication"], reviewEveryMonths: 12, in: catalog, now: TestClock.now
        )
        #expect(edited.questionKeys == ["allergies", "medication", "fromTheFuture"])
    }

    @Test("A review period outside the choices is ignored")
    func invalidMonths() {
        let current = makeHealthTemplate(months: 12)
        let edited = HealthFormTemplateRules.edited(
            current, enabling: Set(current.questionKeys), reviewEveryMonths: 5, in: catalog, now: TestClock.now
        )
        #expect(edited == current)
        #expect(HealthFormTemplateRules.reviewOptions == [3, 6, 12, 24])
    }

    @Test("A stored version keeps its questions: only the same questions may be saved over it")
    func acceptsOnlySameQuestions() {
        let stored = makeHealthTemplate(version: 2)
        var sameQuestions = stored
        sameQuestions.reviewEveryMonths = 3
        var otherQuestions = stored
        otherQuestions.questionKeys = ["allergies"]
        #expect(HealthFormTemplateRules.accepts(sameQuestions, over: stored))
        #expect(!HealthFormTemplateRules.accepts(otherQuestions, over: stored))
        #expect(HealthFormTemplateRules.accepts(otherQuestions, over: nil))
    }

    @Test("The current template is the highest version, and a form finds the version it was signed on")
    func currentAndLookup() {
        let templates = [makeHealthTemplate(version: 2), makeHealthTemplate(version: 3), makeHealthTemplate(version: 1)]
        #expect(HealthFormTemplateRules.current(of: templates)?.version == 3)
        #expect(HealthFormTemplateRules.template(forVersion: 2, in: templates)?.version == 2)
        #expect(HealthFormTemplateRules.template(forVersion: 9, in: templates) == nil)
        #expect(HealthFormTemplateRules.current(of: []) == nil)
    }

    @Test("A version has one id, so two phones that both create it write the same record")
    func versionIDs() {
        #expect(HealthFormTemplate.id(forVersion: 4) == makeHealthTemplate(version: 4).id)
        #expect(HealthFormTemplate.id(forVersion: 4) != HealthFormTemplate.id(forVersion: 5))
        #expect(HealthFormTemplate.id(forVersion: 1) != RecordTemplate.singletonID)
    }

    // MARK: - Review

    /// Signed on the wall clock `signedAt` in `zone`; the review is due `months` later, at the same local time.
    private func status(
        signed signedAt: String, months: Int, now: Date, zone: String
    ) -> HealthReviewStatus {
        HealthFormTemplateRules.reviewStatus(
            signedAt: TestClock.date(signedAt, zone: zone), months: months, now: now,
            calendar: TestClock.calendar(zone)
        )
    }

    @Test("Exactly 12 months later it is due; a second before it is not; a day either side is current and due")
    func twelveMonthBoundary() {
        let zone = "America/Sao_Paulo"
        let due = TestClock.date("2027-09-12 14:00", zone: zone)

        #expect(status(signed: "2026-09-12 14:00", months: 12, now: due, zone: zone) == .due(dueAt: due))
        #expect(status(signed: "2026-09-12 14:00", months: 12, now: due.addingTimeInterval(-1), zone: zone)
                == .current(dueAt: due))
        #expect(status(signed: "2026-09-12 14:00", months: 12, now: TestClock.date("2027-09-11 14:00", zone: zone),
                       zone: zone) == .current(dueAt: due))
        #expect(status(signed: "2026-09-12 14:00", months: 12, now: TestClock.date("2027-09-13 14:00", zone: zone),
                       zone: zone) == .due(dueAt: due))
    }

    @Test("Across a daylight-saving change the due time is the same wall clock time",
          arguments: [
              ("Europe/Lisbon", "2026-01-15 10:00", "2026-07-15 10:00"),
              ("America/New_York", "2026-03-01 12:00", "2026-09-01 12:00"),
              ("Europe/Madrid", "2025-10-20 09:30", "2026-04-20 09:30")
          ])
    func daylightSaving(zone: String, signed: String, expectedDue: String) throws {
        let signedAt = TestClock.date(signed, zone: zone)
        let calendar = TestClock.calendar(zone)
        let due = try #require(HealthFormTemplateRules.reviewDueDate(signedAt: signedAt, months: 6, calendar: calendar))

        #expect(due == TestClock.date(expectedDue, zone: zone))
        let time = calendar.dateComponents([.hour, .minute], from: due)
        let expected = calendar.dateComponents([.hour, .minute], from: signedAt)
        #expect(time.hour == expected.hour && time.minute == expected.minute)
    }

    @Test("Across the Lisbon spring change the boundary still falls on the wall clock, not on 182 days")
    func lisbonBoundary() {
        let zone = "Europe/Lisbon"
        let due = TestClock.date("2026-07-15 10:00", zone: zone)
        let signedAt = TestClock.date("2026-01-15 10:00", zone: zone)

        // 181 calendar days, but the summer offset makes it one hour shorter in real time.
        #expect(due.timeIntervalSince(signedAt) == 181 * 86_400 - 3_600)
        #expect(status(signed: "2026-01-15 10:00", months: 6, now: due, zone: zone) == .due(dueAt: due))
        #expect(status(signed: "2026-01-15 10:00", months: 6, now: due.addingTimeInterval(-3_600), zone: zone)
                == .current(dueAt: due))
    }

    @Test("A month that is shorter clamps: the 31st plus one month is the 28th, and a leap day the 28th a year on")
    func shortMonths() throws {
        let zone = "America/Sao_Paulo"
        let calendar = TestClock.calendar(zone)
        let january = TestClock.date("2026-01-31 10:00", zone: zone)
        #expect(HealthFormTemplateRules.reviewDueDate(signedAt: january, months: 1, calendar: calendar)
                == TestClock.date("2026-02-28 10:00", zone: zone))
        let leapDay = TestClock.date("2028-02-29 10:00", zone: zone)
        #expect(HealthFormTemplateRules.reviewDueDate(signedAt: leapDay, months: 12, calendar: calendar)
                == TestClock.date("2029-02-28 10:00", zone: zone))
    }

    @Test("A form with no signature date has nothing to count from", arguments: HealthFormTemplateRules.reviewOptions)
    func undated(months: Int) {
        let calendar = TestClock.calendar()
        #expect(HealthFormTemplateRules.reviewStatus(
            signedAt: nil, months: months, now: TestClock.now, calendar: calendar
        ) == .undated)
        #expect(!HealthReviewStatus.undated.isDue)
        #expect(!HealthReviewStatus.current(dueAt: TestClock.now).isDue)
        #expect(HealthReviewStatus.due(dueAt: TestClock.now).isDue)
    }

    // MARK: - The latest form

    @Test("The form read first is the one signed last; one without a date comes after every dated one")
    func latestForm() {
        let older = makeHealthForm(signedAt: TestClock.days(-400))
        let newer = makeHealthForm(signedAt: TestClock.days(-20))
        let undated = makeHealthForm(signedAt: nil)

        #expect(HealthFormTemplateRules.latestForm(in: [older, undated, newer])?.id == newer.id)
        #expect(HealthFormTemplateRules.latestForm(in: [undated, older])?.id == older.id)
        #expect(HealthFormTemplateRules.latestForm(in: []) == nil)
    }

    @Test("Her health history dates from the latest signed paper form or answered form, whichever is later (D60)")
    func lastHealthFormDate() {
        let answered = makeHealthForm(signedAt: TestClock.days(-400))
        let paper = makeConsentRecord(kind: .healthForm, daysAgo: 20)
        let unsignedPaper = makeConsentRecord(kind: .healthForm, isSigned: false, daysAgo: 2)
        let consent = makeConsentRecord(kind: .treatment, daysAgo: 1)

        #expect(HealthFormTemplateRules.lastHealthFormDate(forms: [answered], records: [paper]) == TestClock.days(-20))
        #expect(HealthFormTemplateRules.lastHealthFormDate(forms: [answered], records: [unsignedPaper, consent])
            == TestClock.days(-400))
        #expect(HealthFormTemplateRules.lastHealthFormDate(forms: [], records: [consent]) == nil)
    }
}
