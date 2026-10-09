//
//  LegalFileName.swift
//  BelloHub
//

import Foundation

/// The names of the bundled legal notices. `legal/<notice>/<localization>/<version>.md` is bundled flat (the bundle
/// has no folders) as `<notice>-<localization>-<version>.md`, e.g. `privacy-policy-pt-BR-2026-10.md`. Pure, so the
/// rules that pick a version out of a list of names are tested without a bundle.
enum LegalFileName {
    static func name(of notice: LegalNotice, localizationID: String, version: String) -> String {
        "\(notice.rawValue)-\(localizationID)-\(version)"
    }

    /// The version in `fileName` (no extension) when it is a file of this notice and localization, else nil.
    /// `en` and `en-GB` share a prefix, so the rest after it must really be a version (`2026-10`): `GB-2026-10` is not.
    static func version(inFileName fileName: String, of notice: LegalNotice, localizationID: String) -> String? {
        let prefix = "\(notice.rawValue)-\(localizationID)-"
        guard fileName.hasPrefix(prefix) else { return nil }
        let rest = String(fileName.dropFirst(prefix.count))
        return isVersion(rest) ? rest : nil
    }

    /// `2026-10`, optionally with a numeric revision (`2026-10-2`).
    static func isVersion(_ text: String) -> Bool {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2 || parts.count == 3 else { return false }
        func digits(_ part: Substring, count: Int? = nil) -> Bool {
            !part.isEmpty && part.allSatisfy { $0.isASCII && $0.isNumber } && (count == nil || part.count == count)
        }
        return digits(parts[0], count: 4) && digits(parts[1], count: 2) && (parts.count == 2 || digits(parts[2]))
    }

    /// The newest of some versions: compared as numbers piece by piece, so `2026-10-10` is after `2026-10-2`.
    static func newest(of versions: [String]) -> String? {
        versions.max { $0.compare($1, options: .numeric) == .orderedAscending }
    }
}
