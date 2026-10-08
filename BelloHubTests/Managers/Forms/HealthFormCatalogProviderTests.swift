//
//  HealthFormCatalogProviderTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("BundleHealthFormCatalogProvider", .serialized)
struct HealthFormCatalogProviderTests {
    /// A folder of catalog files as a bundle; removed when the test ends.
    private struct Scratch {
        let directory: URL

        init(files: [String: String]) throws {
            let name = "catalog-test-\(UUID().uuidString)"
            directory = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for (file, contents) in files {
                let url = directory.appendingPathComponent("healthform-\(file).json")
                try contents.write(to: url, atomically: true, encoding: .utf8)
            }
        }

        var provider: BundleHealthFormCatalogProvider {
            BundleHealthFormCatalogProvider(bundle: Bundle(url: directory) ?? .main)
        }

        func remove() {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private func catalogJSON(_ localization: String) -> String {
        """
        {"localization": "\(localization)", "questions": [
          {"key": "medication", "kind": "yesNo", "name": "M", "prompt": "M?"}]}
        """
    }

    @Test("A localization with a file reads its own catalog")
    func ownFile() throws {
        let scratch = try Scratch(files: ["en": catalogJSON("en"), "pt-BR": catalogJSON("pt-BR")])
        defer { scratch.remove() }

        #expect(try scratch.provider.catalog(for: .ptBR).localization == "pt-BR")
    }

    @Test("A localization with no file reads the English catalog, so a gap never leaves a screen without questions")
    func fallsBackToEnglish() throws {
        let scratch = try Scratch(files: ["en": catalogJSON("en")])
        defer { scratch.remove() }

        #expect(try scratch.provider.catalog(for: .de).localization == "en")
    }

    @Test("With no English file either, the missing resource is reported")
    func nothingToRead() throws {
        let scratch = try Scratch(files: ["fr": catalogJSON("fr")])
        defer { scratch.remove() }

        #expect(throws: HealthFormCatalog.LoadError.missingResource) { try scratch.provider.catalog(for: .de) }
    }

    @Test("A file that is not a catalog is reported as malformed, not read as empty")
    func malformed() throws {
        let scratch = try Scratch(files: ["en": "not json"])
        defer { scratch.remove() }

        #expect(throws: HealthFormCatalog.LoadError.malformed) { try scratch.provider.catalog(for: .en) }
    }
}
