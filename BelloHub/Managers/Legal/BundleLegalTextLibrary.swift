//
//  BundleLegalTextLibrary.swift
//  BelloHub
//

import Foundation

/// Reads the legal drafts bundled under `Resources/Legal/` (copies of `legal/`, kept identical by
/// `scripts/check-legal-resources.sh`). Reading the bundle is IO, which is why this is a Manager.
struct BundleLegalTextLibrary: LegalTextLibrary {
    let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func latest(_ document: LegalDocument, localization: AppLocalization) throws -> LegalText {
        var candidates = [localization.rawValue]
        if localization != .en { candidates.append(AppLocalization.en.rawValue) }
        for candidate in candidates {
            if let version = LegalFileName.newest(of: versions(of: document, localizationID: candidate)) {
                return try text(document, localizationID: candidate, version: version)
            }
        }
        throw LegalTextError.notFound
    }

    func text(_ document: LegalDocument, localizationID: String, version: String) throws -> LegalText {
        let name = LegalFileName.name(of: document, localizationID: localizationID, version: version)
        guard let url = bundle.url(forResource: name, withExtension: "md") else { throw LegalTextError.notFound }
        guard let raw = try? String(contentsOf: url, encoding: .utf8), let parsed = LegalTextRenderer.parse(raw) else {
            throw LegalTextError.malformed
        }
        let header = parsed.header
        // A header that disagrees with the file name would show one text as another: refuse it.
        guard header["document"] == document.rawValue, header["localization"] == localizationID,
              header["version"] == version else { throw LegalTextError.malformed }
        return LegalText(
            document: document, localization: localizationID, version: version, region: header["region"] ?? "",
            status: header["status"] ?? "draft", framework: header["framework"] ?? "", body: parsed.body
        )
    }

    private func versions(of document: LegalDocument, localizationID: String) -> [String] {
        let urls = bundle.urls(forResourcesWithExtension: "md", subdirectory: nil) ?? []
        return urls.compactMap {
            LegalFileName.version(
                inFileName: $0.deletingPathExtension().lastPathComponent, of: document, localizationID: localizationID
            )
        }
    }
}
