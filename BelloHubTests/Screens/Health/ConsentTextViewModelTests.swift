//
//  ConsentTextViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("Signed consent and consent preview")
struct ConsentTextViewModelTests {
    private let formatters = Formatters(
        locale: Locale(identifier: "en"), timeZone: TestClock.saoPaulo, currencyCode: "BRL"
    )

    private func library() -> FakeLegalTextLibrary {
        FakeLegalTextLibrary(
            LegalDocument.allCases.flatMap { document in
                ["en", "pt-BR"].flatMap { localization in
                    ["2026-10", "2027-02"].map {
                        FakeLegalTextLibrary.text(document, localization: localization, version: $0)
                    }
                }
            }
        )
    }

    private func consent(
        kind: ConsentKind = .treatment, localeID: String = "pt-BR", version: String = "2026-10"
    ) -> Consent {
        Consent(
            id: UUID(), clientID: UUID(), kind: kind, signedAt: TestClock.now, textVersion: version,
            localeID: localeID, typedSignature: "Ana Costa", signatureImage: nil
        )
    }

    @Test("A signed text is shown exactly: the version it was signed on, even when a newer one exists")
    func exactVersion() {
        let model = SignedConsentViewModel(
            consent: consent(version: "2026-10"), formatters: formatters, legal: library(),
            profile: makeHealthProfile(localeID: "pt-BR")
        )

        #expect(model.legalText?.version == "2026-10" && model.legalText?.localization == "pt-BR")
        #expect(!model.isMissing && model.localization == .ptBR)
        #expect(model.renderedText?.blocks.contains(.paragraph("**Who.** Maria Beauty.")) == true)
    }

    @Test("Each kind of consent opens its own document")
    func documents() {
        for (kind, document) in [(ConsentKind.treatment, LegalDocument.consentHealth), (.photos, .consentPhoto),
                                 (.guardian, .consentGuardian)] {
            let model = SignedConsentViewModel(
                consent: consent(kind: kind), formatters: formatters, legal: library(), profile: nil
            )
            #expect(model.legalText?.document == document)
        }
    }

    @Test("A version this iPhone does not have is reported as missing, never replaced by another text")
    func missingVersion() {
        let model = SignedConsentViewModel(
            consent: consent(version: "2099-01"), formatters: formatters, legal: library(), profile: nil
        )
        #expect(model.isMissing && model.renderedText == nil && model.legalText == nil)

        let otherLanguage = SignedConsentViewModel(
            consent: consent(localeID: "de"), formatters: formatters, legal: library(), profile: nil
        )
        #expect(otherLanguage.isMissing, "no fallback to English for a text that was signed in German")
    }

    @Test("The preview shows the newest version and changes language on request")
    func preview() {
        let model = ConsentPreviewViewModel(
            document: .consentHealth, language: .ptBR, legal: library(), profile: makeHealthProfile()
        )
        #expect(model.legalText?.version == "2027-02" && model.legalText?.localization == "pt-BR")
        #expect(!model.hasError)

        model.setLanguage(.en)
        #expect(model.language == .en && model.legalText?.localization == "en")
        model.setLanguage(.de)
        #expect(model.language == .de && model.legalText?.localization == "en", "German falls back to English")
    }

    @Test("A document with no text at all is an error, not an empty page")
    func previewError() {
        let model = ConsentPreviewViewModel(
            document: .consentPhoto, language: .en, legal: FakeLegalTextLibrary(), profile: nil
        )
        #expect(model.hasError && model.renderedText == nil)
    }
}
