//
//  LegalTextRenderer.swift
//  BelloHub
//

import Foundation

/// Turns a bundled legal notice (terms, privacy policy) into something the screen can draw: strips the header, fills
/// the `{{PLACEHOLDERS}}` and styles the inline Markdown. Pure, so every rule is tested without a bundle. It never
/// changes a word of the legal text itself.
enum LegalTextRenderer {
    /// What an unfilled placeholder looks like.
    enum PendingStyle: Sendable {
        /// `[[OPERATOR_NAME pending]]`: a debug build must never pass for a finished text.
        case visible
        /// Nothing at all. A release build only ever runs with the operator fields filled (the S11 gate blocks it
        /// otherwise); this keeps a raw `{{TOKEN}}` from ever reaching a person.
        case hidden
    }

    /// The header facts and the body of one file.
    struct ParsedFile: Equatable, Sendable {
        let header: [String: String]
        let body: String
    }

    // MARK: - Header

    /// Splits `---` header lines (`key: value`) from the body. Nil when the file has no header.
    static func parse(_ raw: String) -> ParsedFile? {
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
        guard normalized.hasPrefix("---\n") else { return nil }
        let afterOpening = normalized.dropFirst(4)
        guard let closing = afterOpening.range(of: "\n---\n") ?? closingAtEnd(afterOpening) else { return nil }
        var header: [String: String] = [:]
        for line in afterOpening[afterOpening.startIndex..<closing.lowerBound].split(separator: "\n") {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[line.startIndex..<colon].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if !key.isEmpty { header[key] = value }
        }
        let body = String(afterOpening[closing.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return ParsedFile(header: header, body: body)
    }

    private static func closingAtEnd(_ text: Substring) -> Range<Substring.Index>? {
        guard text.hasSuffix("\n---") else { return nil }
        return text.index(text.endIndex, offsetBy: -4)..<text.endIndex
    }

    // MARK: - Placeholders

    /// Replaces every `{{NAME}}`. A placeholder with no value (the operator's fields until H17, or a name this
    /// version does not know) follows `pending`.
    static func fill(_ body: String, values: LegalTextValues, pending: PendingStyle) -> String {
        var result = ""
        var cursor = body.startIndex
        while let open = body.range(of: "{{", range: cursor..<body.endIndex),
              let close = body.range(of: "}}", range: open.upperBound..<body.endIndex) {
            let name = String(body[open.upperBound..<close.lowerBound])
            guard isPlaceholderName(name) else {
                // Not a placeholder (stray braces in the text): keep it and move past the opening braces.
                result += body[cursor..<open.upperBound]
                cursor = open.upperBound
                continue
            }
            result += body[cursor..<open.lowerBound]
            if let value = values.value(for: name) {
                result += value
            } else if pending == .visible {
                result += "[[\(name) pending]]"
            }
            cursor = close.upperBound
        }
        result += body[cursor...]
        return result
    }

    /// The names of the placeholders a body uses, in order of appearance.
    static func placeholders(in body: String) -> [String] {
        var found: [String] = []
        var cursor = body.startIndex
        while let open = body.range(of: "{{", range: cursor..<body.endIndex),
              let close = body.range(of: "}}", range: open.upperBound..<body.endIndex) {
            let name = String(body[open.upperBound..<close.lowerBound])
            if isPlaceholderName(name) { found.append(name) }
            cursor = close.upperBound
        }
        return found
    }

    private static func isPlaceholderName(_ name: String) -> Bool {
        !name.isEmpty && name.allSatisfy { $0.isASCII && ($0.isUppercase || $0 == "_") }
    }

    // MARK: - Markdown

    /// The inline Markdown of a text (`**bold**`) as styled text. Whitespace is kept as written; a string the parser
    /// rejects is shown as plain text instead of being dropped.
    static func attributed(_ markdown: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: markdown, options: options)) ?? AttributedString(markdown)
    }
}
