//
//  BundleLegalNoticeLibrary.swift
//  BelloHub
//

import Foundation

/// Reads `terms-dpa-<localization>-<version>.md` and `privacy-policy-<localization>-<version>.md` from
/// `Resources/Legal/` (copies of `legal/`, kept identical by `scripts/check-legal-resources.sh`).
struct BundleLegalNoticeLibrary: LegalNoticeLibrary {
    let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func latest(_ notice: LegalNotice, localization: AppLocalization) throws -> LegalNoticeText {
        var candidates = [localization.rawValue]
        if localization != .en { candidates.append(AppLocalization.en.rawValue) }
        for candidate in candidates {
            if let version = LegalFileName.newest(of: versions(of: notice, localizationID: candidate)) {
                return try text(notice, localizationID: candidate, version: version)
            }
        }
        throw LegalTextError.notFound
    }

    private func text(_ notice: LegalNotice, localizationID: String, version: String) throws -> LegalNoticeText {
        let name = LegalFileName.name(of: notice, localizationID: localizationID, version: version)
        guard let url = bundle.url(forResource: name, withExtension: "md") else { throw LegalTextError.notFound }
        guard let raw = try? String(contentsOf: url, encoding: .utf8), let parsed = LegalTextRenderer.parse(raw) else {
            throw LegalTextError.malformed
        }
        let header = parsed.header
        guard header["document"] == notice.rawValue, header["localization"] == localizationID,
              header["version"] == version else { throw LegalTextError.malformed }
        return LegalNoticeText(
            notice: notice, localization: localizationID, version: version, status: header["status"] ?? "draft",
            body: parsed.body
        )
    }

    private func versions(of notice: LegalNotice, localizationID: String) -> [String] {
        let urls = bundle.urls(forResourcesWithExtension: "md", subdirectory: nil) ?? []
        return urls.compactMap { url in
            LegalFileName.version(
                inFileName: url.deletingPathExtension().lastPathComponent, of: notice, localizationID: localizationID
            )
        }
    }
}
