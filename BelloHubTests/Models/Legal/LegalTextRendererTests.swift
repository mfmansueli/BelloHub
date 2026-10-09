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
    document: privacy-policy
    localization: en
    region: United States
    version: 2026-10
    status: draft
    review: LEGAL-REVIEW
    ---
    # Privacy policy

    **Who we are.** {{OPERATOR_NAME}} runs BelloHub. Write to {{OPERATOR_EMAIL}}.
    """

    // MARK: - Header

    @Test("The header is stripped and its facts are read")
    func parseHeader() throws {
        let parsed = try #require(LegalTextRenderer.parse(file))
        #expect(parsed.header["document"] == "privacy-policy")
        #expect(parsed.header["version"] == "2026-10" && parsed.header["status"] == "draft")
        #expect(parsed.body.hasPrefix("# Privacy policy"))
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
            operatorName: "Op Ltd", operatorEmail: "privacy@example.com", operatorAddress: "1 Main St",
            webBaseURL: "https://example.com", effectiveDate: "2026-10-01"
        )
        let body = "{{OPERATOR_NAME}}|{{OPERATOR_EMAIL}}|{{OPERATOR_ADDRESS}}|{{WEB_BASE_URL}}|{{EFFECTIVE_DATE}}"
        #expect(LegalTextRenderer.fill(body, values: values, pending: .visible)
                == "Op Ltd|privacy@example.com|1 Main St|https://example.com|2026-10-01")
    }

    @Test("An unfilled operator field is visibly pending in a debug build and simply absent in a release build")
    func pendingStyles() {
        let values = LegalTextValues(operatorName: "Op Ltd")
        let body = "{{OPERATOR_NAME}}: write to {{OPERATOR_EMAIL}} or visit {{WEB_BASE_URL}}."
        #expect(LegalTextRenderer.fill(body, values: values, pending: .visible)
                == "Op Ltd: write to [[OPERATOR_EMAIL pending]] or visit [[WEB_BASE_URL pending]].")
        #expect(LegalTextRenderer.fill(body, values: values, pending: .hidden) == "Op Ltd: write to  or visit .")
    }

    @Test("A blank value counts as unfilled")
    func blankIsPending() {
        let values = LegalTextValues(operatorName: "   ")
        #expect(LegalTextRenderer.fill("{{OPERATOR_NAME}}", values: values, pending: .visible)
                == "[[OPERATOR_NAME pending]]")
    }

    @Test("An unknown placeholder is treated as pending, and stray braces are left alone")
    func unknownAndStray() {
        let values = LegalTextValues(operatorName: "Op Ltd")
        #expect(LegalTextRenderer.fill("{{SOMETHING_NEW}}", values: values, pending: .visible)
                == "[[SOMETHING_NEW pending]]")
        #expect(LegalTextRenderer.fill("{{SOMETHING_NEW}}", values: values, pending: .hidden) == "")
        #expect(LegalTextRenderer.fill("a {{not a name}} b { c } {{", values: values, pending: .visible)
                == "a {{not a name}} b { c } {{")
    }

    @Test("The placeholders a text uses are listed in order")
    func listsPlaceholders() {
        let body = "{{OPERATOR_NAME}} x {{WEB_BASE_URL}} {{OPERATOR_NAME}} {{no}}"
        #expect(LegalTextRenderer.placeholders(in: body) == ["OPERATOR_NAME", "WEB_BASE_URL", "OPERATOR_NAME"])
    }

    @Test("Filling a value that contains braces or Markdown never fills twice")
    func valuesAreNotRescanned() {
        let values = LegalTextValues(operatorName: "{{OPERATOR_EMAIL}} **x**")
        #expect(LegalTextRenderer.fill("{{OPERATOR_NAME}}", values: values, pending: .visible)
                == "{{OPERATOR_EMAIL}} **x**")
    }

    // MARK: - Markdown

    @Test("Bold words become bold text and the rest stays as written")
    func attributed() {
        let text = LegalTextRenderer.attributed("**Who we are.** Op Ltd runs BelloHub.")
        #expect(String(text.characters) == "Who we are. Op Ltd runs BelloHub.")
        let boldRuns = text.runs.filter { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true }
        #expect(boldRuns.map { String(text[$0.range].characters) } == ["Who we are."])
    }

    @Test("A pending marker survives the Markdown parser as plain text")
    func pendingMarkerIsPlain() {
        let text = LegalTextRenderer.attributed("Write to [[OPERATOR_EMAIL pending]] now.")
        #expect(String(text.characters) == "Write to [[OPERATOR_EMAIL pending]] now.")
    }
}
