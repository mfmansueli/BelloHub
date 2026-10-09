//
//  MoreSummaryTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("MoreSummary")
struct MoreSummaryTests {
    /// `BelloHub.Tag`, because Swift Testing has a `Tag` of its own.
    private func tag(_ name: String) -> BelloHub.Tag {
        BelloHub.Tag(id: UUID(), name: name, colorToken: "rose", position: 0)
    }

    @Test("It counts her tags and the record fields switched on across her professions")
    func counts() {
        let template = RecordTemplate(
            fields: [
                RecordFieldSetting(profession: .esthetician, key: "est.skin", isOn: true),
                RecordFieldSetting(profession: .esthetician, key: "est.technique", isOn: false),
                RecordFieldSetting(profession: .esthetician, key: "custom-1", customName: "Mood", isOn: true),
                RecordFieldSetting(profession: .hair, key: "hair.formula", isOn: true)
            ],
            intake: [], updatedAt: TestClock.now
        )

        let summary = MoreSummary(
            tags: [tag("VIP"), tag("Bridal")], template: template, professions: [.esthetician, .hair]
        )

        #expect(summary.tagCount == 2 && summary.fieldsOn == 3)
    }

    @Test("A profession she no longer has does not count")
    func ignoresOtherProfessions() {
        let template = RecordTemplate(
            fields: [
                RecordFieldSetting(profession: .esthetician, key: "est.skin", isOn: true),
                RecordFieldSetting(profession: .barber, key: "barber.line", isOn: true)
            ],
            intake: [], updatedAt: TestClock.now
        )

        #expect(MoreSummary(tags: [], template: template, professions: [.esthetician]).fieldsOn == 1)
    }

    @Test("Before the template is loaded there is no field count, and no tags is zero")
    func notLoadedYet() {
        let summary = MoreSummary(tags: [], template: nil, professions: [.esthetician])
        #expect(summary.tagCount == 0 && summary.fieldsOn == nil)
    }
}
