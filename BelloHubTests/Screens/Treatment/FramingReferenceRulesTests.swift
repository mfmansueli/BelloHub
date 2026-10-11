//
//  FramingReferenceRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("FramingReferenceRules")
struct FramingReferenceRulesTests {
    private let clientID = UUID()

    private func makePhoto(_ kind: PhotoKind, daysAgo: Int, recordID: UUID? = nil) -> Photo {
        Photo(
            id: UUID(), clientID: clientID, recordID: recordID, takenAt: TestClock.days(-daysAgo), kind: kind,
            visibility: .professionalOnly
        )
    }

    @Test("An 'after' lines up with this visit's 'before'")
    func pairsWithThisVisit() {
        let before = makePhoto(.before, daysAgo: 0)
        let lastVisit = makePhoto(.after, daysAgo: 30)

        let chosen = FramingReferenceRules.reference(for: .after, thisVisit: [before], earlier: [lastVisit, before])

        #expect(chosen == before)
    }

    @Test("With nothing in this visit, the latest earlier photo of the same kind is used")
    func sameKindFromEarlierVisits() {
        let oldBefore = makePhoto(.before, daysAgo: 60)
        let lastBefore = makePhoto(.before, daysAgo: 30)
        let lastAfter = makePhoto(.after, daysAgo: 29)

        let chosen = FramingReferenceRules.reference(
            for: .before, thisVisit: [], earlier: [oldBefore, lastAfter, lastBefore]
        )

        #expect(chosen == lastBefore)
    }

    @Test("Without the same kind, the latest earlier photo of any kind")
    func anyKindFallback() {
        let progress = makePhoto(.progress, daysAgo: 10)
        let after = makePhoto(.after, daysAgo: 40)

        #expect(FramingReferenceRules.reference(for: .before, thisVisit: [], earlier: [after, progress]) == progress)
    }

    @Test("A photo of this visit is never its own earlier reference, and no photo means no reference")
    func noReference() {
        let justTaken = makePhoto(.before, daysAgo: 0)

        #expect(FramingReferenceRules.reference(for: .before, thisVisit: [justTaken], earlier: [justTaken]) == nil)
        #expect(FramingReferenceRules.reference(for: .after, thisVisit: [], earlier: []) == nil)
    }
}
