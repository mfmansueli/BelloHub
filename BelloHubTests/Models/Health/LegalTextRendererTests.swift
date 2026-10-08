//
//  LegalTextRendererTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("LegalTextRenderer")
struct LegalTextRendererTests {
    private let file = """
    ---
    document: consent-health
    localization: en
    region: United States
    version: 2026-10
    status: draft
    review: LEGAL-REVIEW
    ---
    # Consent to share your health information

    **Who is asking.** {{PROFESSIONAL_NAME}} is responsible for what you share.

    **What you agree to.**
    1. She may collect your answers.
    2. She keeps them private.

    ☐ I agree that {{PROFESSIONAL_NAME}} may use my answers. Contact: {{OPERATOR_EMAIL}}.
    Signature (type your full name):
    """

    private func makeText(body: String) -> LegalText {
        LegalText(document: .consentHealth, localization: "en", version: "2026-10", region: "United States",
                  status: "draft", framework: "", body: body)
    }

    // MARK: - Header

    @Test("The header is stripped and its facts are read")
    func parseHeader() throws {
        let parsed = try #require(LegalTextRenderer.parse(file))
        #expect(parsed.header["document"] == "consent-health")
        #expect(parsed.header["version"] == "2026-10" && parsed.header["status"] == "draft")
        #expect(parsed.body.hasPrefix("# Consent to share your health information"))
        #expect(!parsed.body.contains("---") && !parsed.body.contains("LEGAL-REVIEW"))
    }

    @Test("A file with no header, or one that never closes, is not a legal text")
    func noHeader() {
        #expect(LegalTextRenderer.parse("# Just a title\n\nSome text.") == nil)
        #expect(LegalTextRenderer.parse("---\ndocument: x\nno closing line") == nil)
    }

    @Test("Windows line endings read the same")
    func carriageReturns() throws {
        let parsed = try #require(LegalTextRenderer.parse(file.replacingOccurrences(of: "\n", with: "\r\n")))
        #expect(parsed.header["localization"] == "en")
        #expect(!parsed.body.contains("\r"))
    }

    // MARK: - Placeholders

    @Test("Every placeholder is filled from its value")
    func fillsAll() {
        let values = LegalTextValues(
            professionalName: "Maria Beauty", operatorName: "Op Ltd", operatorEmail: "privacy@example.com",
            operatorAddress: "1 Main St", webBaseURL: "https://example.com", effectiveDate: "2026-10-01"
        )
        let body = "{{PROFESSIONAL_NAME}}|{{OPERATOR_NAME}}|{{OPERATOR_EMAIL}}|{{OPERATOR_ADDRESS}}|{{WEB_BASE_URL}}|" +
            "{{EFFECTIVE_DATE}}"
        #expect(LegalTextRenderer.fill(body, values: values, pending: .visible)
                == "Maria Beauty|Op Ltd|privacy@example.com|1 Main St|https://example.com|2026-10-01")
    }

    @Test("An unfilled operator field is visibly pending in a debug build and simply absent in a release build")
    func pendingStyles() {
        let values = LegalTextValues(professionalName: "Maria")
        let body = "Hi {{PROFESSIONAL_NAME}}, write to {{OPERATOR_EMAIL}} or visit {{WEB_BASE_URL}}."
        #expect(LegalTextRenderer.fill(body, values: values, pending: .visible)
                == "Hi Maria, write to [[OPERATOR_EMAIL pending]] or visit [[WEB_BASE_URL pending]].")
        #expect(LegalTextRenderer.fill(body, values: values, pending: .hidden) == "Hi Maria, write to  or visit .")
    }

    @Test("A blank value counts as unfilled")
    func blankIsPending() {
        let values = LegalTextValues(professionalName: "   ")
        #expect(LegalTextRenderer.fill("{{PROFESSIONAL_NAME}}", values: values, pending: .visible)
                == "[[PROFESSIONAL_NAME pending]]")
    }

    @Test("An unknown placeholder is treated as pending, and stray braces are left alone")
    func unknownAndStray() {
        let values = LegalTextValues(professionalName: "Maria")
        #expect(LegalTextRenderer.fill("{{SOMETHING_NEW}}", values: values, pending: .visible)
                == "[[SOMETHING_NEW pending]]")
        #expect(LegalTextRenderer.fill("{{SOMETHING_NEW}}", values: values, pending: .hidden) == "")
        #expect(LegalTextRenderer.fill("a {{not a name}} b { c } {{", values: values, pending: .visible)
                == "a {{not a name}} b { c } {{")
    }

    @Test("The placeholders a text uses are listed in order")
    func listsPlaceholders() {
        let body = "{{PROFESSIONAL_NAME}} x {{WEB_BASE_URL}} {{PROFESSIONAL_NAME}} {{no}}"
        #expect(LegalTextRenderer.placeholders(in: body) == ["PROFESSIONAL_NAME", "WEB_BASE_URL", "PROFESSIONAL_NAME"])
    }

    @Test("Filling a value that contains braces or Markdown never fills twice")
    func valuesAreNotRescanned() {
        let values = LegalTextValues(professionalName: "{{OPERATOR_NAME}} **x**")
        #expect(LegalTextRenderer.fill("{{PROFESSIONAL_NAME}}", values: values, pending: .visible)
                == "{{OPERATOR_NAME}} **x**")
    }

    // MARK: - Blocks

    @Test("The text becomes a title and blocks, with the placeholders filled and not a word changed")
    func rendersBlocks() throws {
        let parsed = try #require(LegalTextRenderer.parse(file))
        let rendered = LegalTextRenderer.render(
            makeText(body: parsed.body), values: LegalTextValues(professionalName: "Maria Beauty"), pending: .visible
        )
        #expect(rendered.title == "Consent to share your health information")
        #expect(rendered.blocks == [
            .paragraph("**Who is asking.** Maria Beauty is responsible for what you share."),
            .paragraph("**What you agree to.**"),
            .numbered(1, "She may collect your answers."),
            .numbered(2, "She keeps them private."),
            .checkbox("I agree that Maria Beauty may use my answers. Contact: [[OPERATOR_EMAIL pending]]."),
            .paragraph("Signature (type your full name):")
        ])
    }

    @Test("Bold words become bold text and the rest stays as written")
    func attributed() {
        let text = LegalTextRenderer.attributed("**Who is asking.** Maria is responsible.")
        #expect(String(text.characters) == "Who is asking. Maria is responsible.")
        let boldRuns = text.runs.filter { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true }
        #expect(boldRuns.map { String(text[$0.range].characters) } == ["Who is asking."])
    }

    @Test("A pending marker survives the Markdown parser as plain text")
    func pendingMarkerIsPlain() {
        let text = LegalTextRenderer.attributed("Write to [[OPERATOR_EMAIL pending]] now.")
        #expect(String(text.characters) == "Write to [[OPERATOR_EMAIL pending]] now.")
    }
}
