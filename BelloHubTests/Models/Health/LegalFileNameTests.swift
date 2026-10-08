//
//  LegalFileNameTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("LegalFileName")
struct LegalFileNameTests {
    @Test("The flat bundled name is document, localization and version")
    func flatName() {
        #expect(LegalFileName.name(of: .consentHealth, localizationID: "pt-BR", version: "2026-10")
                == "consent-health-pt-BR-2026-10")
        #expect(LegalFileName.name(of: .consentGuardian, localizationID: "es-419", version: "2027-01")
                == "consent-guardian-es-419-2027-01")
    }

    @Test("A version is YYYY-MM with an optional numeric revision, nothing else",
          arguments: [("2026-10", true), ("2026-10-2", true), ("2026-1", false), ("26-10", false),
                      ("GB-2026-10", false), ("419-2026-10", false), ("2026-10-", false), ("2026-10-x", false),
                      ("", false), ("2026-10-2-3", false)])
    func versions(text: String, isVersion: Bool) {
        #expect(LegalFileName.isVersion(text) == isVersion)
    }

    @Test("A language is never mistaken for a longer one that starts with it")
    func prefixCollisions() {
        let names = ["consent-health-en-2026-10", "consent-health-en-GB-2026-10", "consent-health-es-2026-10",
                     "consent-health-es-419-2026-10", "consent-health-es-MX-2026-10",
                     "consent-photo-en-2026-10"]
        func versions(_ localization: String) -> [String] {
            names.compactMap { LegalFileName.version(inFileName: $0, of: .consentHealth, localizationID: localization) }
        }
        #expect(versions("en") == ["2026-10"])
        #expect(versions("en-GB") == ["2026-10"])
        #expect(versions("es") == ["2026-10"])
        #expect(versions("es-419") == ["2026-10"])
        #expect(versions("es-MX") == ["2026-10"])
        #expect(versions("fr").isEmpty)
    }

    @Test("The newest version is the highest, compared as numbers piece by piece")
    func newest() {
        #expect(LegalFileName.newest(of: ["2026-10", "2027-01", "2026-12"]) == "2027-01")
        #expect(LegalFileName.newest(of: ["2026-10-2", "2026-10-10", "2026-10"]) == "2026-10-10")
        #expect(LegalFileName.newest(of: []) == nil)
    }
}
