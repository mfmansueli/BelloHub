//
//  PhotoConsentRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("PhotoConsentRules")
struct PhotoConsentRulesTests {
    private func consent(_ kind: ConsentKind, daysAgo: Int) -> Consent {
        Consent(
            id: UUID(), clientID: UUID(), kind: kind, signedAt: TestClock.days(-daysAgo), textVersion: "v1",
            localeID: "en", typedSignature: "Ana", signatureImage: nil
        )
    }

    private func photo(_ kind: PhotoKind, daysAgo: Int) -> Photo {
        Photo(
            id: UUID(), clientID: UUID(), recordID: nil, takenAt: TestClock.days(-daysAgo), kind: kind,
            visibility: .professionalOnly
        )
    }

    @Test("Only a signed photo consent counts, and the latest one wins")
    func latestPhotoConsent() {
        let consents = [consent(.treatment, daysAgo: 1), consent(.photos, daysAgo: 30), consent(.photos, daysAgo: 5)]
        #expect(PhotoConsentRules.latestPhotoConsent(consents)?.signedAt == TestClock.days(-5))
        #expect(PhotoConsentRules.latestPhotoConsent([consent(.treatment, daysAgo: 1)]) == nil)
    }

    @Test("Without consent a photo can only be private; with it every choice is open")
    func visibilities() {
        #expect(PhotoConsentRules.allowedVisibilities(hasConsent: false) == [.professionalOnly])
        #expect(PhotoConsentRules.allowedVisibilities(hasConsent: true) == PhotoVisibility.allCases)
        #expect(PhotoConsentRules.visibility(requested: .portfolio, hasConsent: false) == .professionalOnly)
        #expect(PhotoConsentRules.visibility(requested: .portfolio, hasConsent: true) == .portfolio)
    }

    @Test("The pair is the latest before and the latest after")
    func pair() {
        let early = photo(.before, daysAgo: 10)
        let late = photo(.before, daysAgo: 2)
        let after = photo(.after, daysAgo: 1)
        let found = PhotoConsentRules.pair([early, late, after, photo(.progress, daysAgo: 0)])
        #expect(found.before?.id == late.id && found.after?.id == after.id)
    }
}
