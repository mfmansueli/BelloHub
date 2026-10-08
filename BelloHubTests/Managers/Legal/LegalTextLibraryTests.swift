//
//  LegalTextLibraryTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("LegalTextLibrary", .serialized)
struct LegalTextLibraryTests {
    // MARK: - The real bundle

    private let shipped = BundleLegalTextLibrary()

    @Test("Every consent document exists in every localization, newest version, with a matching header",
          arguments: LegalDocument.allCases, AppLocalization.allCases)
    func everyDocumentEveryLanguage(document: LegalDocument, localization: AppLocalization) throws {
        let text = try shipped.latest(document, localization: localization)
        #expect(text.document == document)
        #expect(text.localization == localization.rawValue, "fell back to \(text.localization)")
        #expect(text.version == "2026-10")
        #expect(!text.body.isEmpty && !text.body.contains("---\n"))
        #expect(text.status == "draft" && !text.region.isEmpty)
    }

    @Test("The bundled consent texts only use placeholders the app knows how to fill",
          arguments: LegalDocument.allCases, AppLocalization.allCases)
    func knownPlaceholders(document: LegalDocument, localization: AppLocalization) throws {
        let text = try shipped.latest(document, localization: localization)
        let known: Set<String> = ["PROFESSIONAL_NAME", "OPERATOR_NAME", "OPERATOR_EMAIL", "OPERATOR_ADDRESS",
                                  "WEB_BASE_URL", "EFFECTIVE_DATE"]
        #expect(Set(LegalTextRenderer.placeholders(in: text.body)).isSubset(of: known))
    }

    @Test("The professional's name fills every consent text, and no raw token is left over",
          arguments: LegalDocument.allCases, AppLocalization.allCases)
    func rendersWithTheName(document: LegalDocument, localization: AppLocalization) throws {
        let text = try shipped.latest(document, localization: localization)
        let rendered = LegalTextRenderer.render(
            text, values: LegalTextValues(professionalName: "Maria Beauty"), pending: .hidden
        )
        #expect(!rendered.title.isEmpty && !rendered.blocks.isEmpty)
        let everything = ([rendered.title] + rendered.blocks.map { block -> String in
            switch block {
            case .paragraph(let text), .checkbox(let text), .numbered(_, let text): text
            }
        }).joined(separator: "\n")
        #expect(everything.contains("Maria Beauty"))
        #expect(!everything.contains("{{") && !everything.contains("}}"))
    }

    @Test("A signed text can be shown again exactly: the same document, language and version")
    func exactText() throws {
        let latest = try shipped.latest(.consentGuardian, localization: .ptBR)
        let again = try shipped.text(.consentGuardian, localizationID: "pt-BR", version: latest.version)
        #expect(again == latest)
    }

    @Test("There is no fallback for an exact text: another version or language is not found")
    func exactTextHasNoFallback() {
        #expect(throws: LegalTextError.notFound) {
            try shipped.text(.consentHealth, localizationID: "pt-BR", version: "1999-01")
        }
        #expect(throws: LegalTextError.notFound) {
            try shipped.text(.consentHealth, localizationID: "xx", version: "2026-10")
        }
    }

    // MARK: - A bundle built for the test

    /// A folder of `.md` files as a bundle; removed when the test ends.
    private struct Scratch {
        let directory: URL

        init(files: [String: String]) throws {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent("legal-test-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for (name, contents) in files {
                let url = directory.appendingPathComponent("\(name).md")
                try contents.write(to: url, atomically: true, encoding: .utf8)
            }
        }

        var library: BundleLegalTextLibrary {
            BundleLegalTextLibrary(bundle: Bundle(url: directory) ?? .main)
        }

        func remove() {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private func file(
        _ document: LegalDocument = .consentHealth, localization: String, version: String, body: String = "# T\n\nBody."
    ) -> String {
        let header = "document: \(document.rawValue)\nlocalization: \(localization)\nversion: \(version)\nstatus: draft"
        return "---\n\(header)\n---\n\(body)"
    }

    @Test("The newest version wins, and an older one stays readable by its version")
    func newestVersion() throws {
        let scratch = try Scratch(files: [
            "consent-health-pt-BR-2026-10": file(localization: "pt-BR", version: "2026-10", body: "# Velho\n\nA."),
            "consent-health-pt-BR-2027-01": file(localization: "pt-BR", version: "2027-01", body: "# Novo\n\nB."),
            "consent-health-pt-BR-2026-12": file(localization: "pt-BR", version: "2026-12")
        ])
        defer { scratch.remove() }

        #expect(try scratch.library.latest(.consentHealth, localization: .ptBR).version == "2027-01")
        let old = try scratch.library.text(.consentHealth, localizationID: "pt-BR", version: "2026-10")
        #expect(old.body.hasPrefix("# Velho"))
    }

    @Test("A localization with no text falls back to English, and says so")
    func fallsBackToEnglish() throws {
        let scratch = try Scratch(files: [
            "consent-health-en-2026-10": file(localization: "en", version: "2026-10"),
            "consent-health-pt-BR-2026-10": file(localization: "pt-BR", version: "2026-10")
        ])
        defer { scratch.remove() }

        let german = try scratch.library.latest(.consentHealth, localization: .de)
        #expect(german.localization == "en", "the signature must store the language that was actually read")
        #expect(try scratch.library.latest(.consentHealth, localization: .ptBR).localization == "pt-BR")
    }

    @Test("English is not mistaken for British English, and British English falls back to English")
    func britishEnglish() throws {
        let scratch = try Scratch(files: [
            "consent-health-en-GB-2027-05": file(localization: "en-GB", version: "2027-05"),
            "consent-health-en-2026-10": file(localization: "en", version: "2026-10")
        ])
        defer { scratch.remove() }

        #expect(try scratch.library.latest(.consentHealth, localization: .en).version == "2026-10")
        #expect(try scratch.library.latest(.consentHealth, localization: .enGB).version == "2027-05")
    }

    @Test("A document that exists in no language is not found")
    func missingDocument() throws {
        let scratch = try Scratch(files: ["consent-health-en-2026-10": file(localization: "en", version: "2026-10")])
        defer { scratch.remove() }

        #expect(throws: LegalTextError.notFound) { try scratch.library.latest(.consentPhoto, localization: .en) }
    }

    @Test("A file whose header disagrees with its name is refused rather than shown as another text")
    func headerMustMatchName() throws {
        let scratch = try Scratch(files: [
            "consent-health-en-2026-10": file(.consentPhoto, localization: "en", version: "2026-10"),
            "consent-photo-en-2026-10": file(.consentPhoto, localization: "fr", version: "2026-10"),
            "consent-guardian-en-2026-10": "# No header at all"
        ])
        defer { scratch.remove() }

        #expect(throws: LegalTextError.malformed) { try scratch.library.latest(.consentHealth, localization: .en) }
        #expect(throws: LegalTextError.malformed) { try scratch.library.latest(.consentPhoto, localization: .en) }
        #expect(throws: LegalTextError.malformed) { try scratch.library.latest(.consentGuardian, localization: .en) }
    }
}
