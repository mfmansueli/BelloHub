//
//  PhotoComparisonRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("PhotoComparisonRules")
struct PhotoComparisonRulesTests {
    @Test("A visit with a before and an after makes a pair, using the latest of each")
    func pairsUseLatest() {
        let visit = UUID()
        let oldBefore = makePhoto(recordID: visit, takenAt: TestClock.days(-9), kind: .before)
        let before = makePhoto(recordID: visit, takenAt: TestClock.days(-8), kind: .before)
        let after = makePhoto(recordID: visit, takenAt: TestClock.days(-8), kind: .after)
        let pairs = PhotoComparisonRules.pairs([oldBefore, before, after])
        #expect(pairs.count == 1)
        #expect(pairs.first?.before.id == before.id)
        #expect(pairs.first?.after.id == after.id)
    }

    @Test("A visit with only one side, or only progress photos, makes no pair")
    func incompleteVisits() {
        let visit = UUID()
        let photos = [
            makePhoto(recordID: visit, kind: .before),
            makePhoto(recordID: UUID(), kind: .progress),
            makePhoto(recordID: UUID(), kind: .after)
        ]
        #expect(PhotoComparisonRules.pairs(photos).isEmpty)
    }

    @Test("Pairs from different visits stay apart, newest visit first")
    func pairsPerVisit() {
        let first = UUID()
        let second = UUID()
        let photos = [
            makePhoto(recordID: first, takenAt: TestClock.days(-20), kind: .before),
            makePhoto(recordID: first, takenAt: TestClock.days(-20), kind: .after),
            makePhoto(recordID: second, takenAt: TestClock.days(-2), kind: .before),
            makePhoto(recordID: second, takenAt: TestClock.days(-2), kind: .after)
        ]
        let pairs = PhotoComparisonRules.pairs(photos)
        #expect(pairs.count == 2)
        #expect(pairs[0].after.recordID == second)
        #expect(pairs[1].after.recordID == first)
    }

    @Test("The timeline is every photo newest first, and the same input gives the same order")
    func timelineOrder() {
        let photos = [
            makePhoto(takenAt: TestClock.days(-5)),
            makePhoto(takenAt: TestClock.days(-1)),
            makePhoto(takenAt: TestClock.days(-3))
        ]
        let timeline = PhotoComparisonRules.timeline(photos)
        #expect(timeline.map(\.takenAt) == photos.map(\.takenAt).sorted(by: >))
        #expect(PhotoComparisonRules.timeline(photos.reversed()) == timeline)
    }

    @Test("Without a photo consent only Only me is offered, and a value already stored stays in the list")
    func visibilityOptions() {
        let privatePhoto = makePhoto(visibility: .professionalOnly)
        let shared = makePhoto(visibility: .shareWithClient)
        #expect(PhotoComparisonRules.visibilityOptions(for: privatePhoto, hasConsent: false) == [.professionalOnly])
        #expect(PhotoComparisonRules.visibilityOptions(for: shared, hasConsent: false)
            == [.professionalOnly, .shareWithClient])
        #expect(PhotoComparisonRules.visibilityOptions(for: privatePhoto, hasConsent: true)
            == PhotoVisibility.allCases)
    }
}
