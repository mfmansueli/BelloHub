//
//  ImportEmailRules.swift
//  BelloHub
//

import Foundation

/// The light e-mail check of the importers: an address has one `@`, something before it and a dotted domain after
/// it. Not a full RFC 5322 parser on purpose: a lenient rule keeps real clients in, and the address is only used to
/// reach her later.
enum ImportEmailRules {
    enum Check: Equatable, Sendable {
        /// Nothing there, or a placeholder a spreadsheet uses for "no e-mail" ("-", "n/a").
        case none
        case valid(String)
        case invalid
    }

    private static let placeholders: Set<String> = [
        "-", "--", "---", "—", "n/a", "na", "none", "null", "nil", "no", "sem email", "sem e-mail", "sin correo",
        "sin email", "nao tem", "não tem", "ninguno", "aucun", "keine", "yok", "tidak ada"
    ]

    static func check(_ raw: String?) -> Check {
        guard var text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return .none }
        if placeholders.contains(text.lowercased()) { return .none }
        // A cell may hold several addresses ("a@x.com; b@y.com"): the first one is the client's.
        if let first = text.split(whereSeparator: { $0.isWhitespace || ";,/".contains($0) }).first {
            text = String(first)
        }
        if text.lowercased().hasPrefix("mailto:") { text = String(text.dropFirst("mailto:".count)) }
        return isValid(text) ? .valid(text.lowercased()) : .invalid
    }

    private static func isValid(_ address: String) -> Bool {
        guard address.count <= 254 else { return false }
        let parts = address.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let domain = parts[1]
        guard domain.contains("."), !domain.hasPrefix("."), !domain.hasSuffix("."), !domain.contains("..") else {
            return false
        }
        return !address.contains(where: \.isWhitespace)
    }
}
