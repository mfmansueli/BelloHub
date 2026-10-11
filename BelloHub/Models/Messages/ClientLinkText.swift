//
//  ClientLinkText.swift
//  BelloHub
//

import Foundation

/// The one rule for a link inside a message a client reads (owner, 2026-10-11: "the links must be clickable"):
///
/// 1. It is the full address, `url.absoluteString` (`https://bellohub.app/maria`). WhatsApp, Messages and mail apps
///    do not reliably detect a link without its scheme, so the short form people read (`BookingLink.display`) never
///    goes into a message; it stays for what she reads herself (the link card, the QR caption, the printed card, a
///    bio line).
/// 2. It stands on its own line with nothing glued after it: a full stop or a closing bracket right after the address
///    is dropped, and whatever followed it moves to the next line, so the chat app detects all of it and nothing more.
/// 3. It is never wrapped in bidi isolates: on its own line it is its own paragraph and cannot reorder Arabic text,
///    while an isolate character next to an address can end up inside the detected link.
///
/// Pure, so every case is tested; `QuickReplyRenderer` and the share texts use it.
enum ClientLinkText {
    /// Closing punctuation that would be read as part of the link (or would dangle after it) when glued to it.
    private static let closing: Set<Character> = [
        ".", ",", ";", ":", "!", "?", ")", "]", "}", "»", "”", "’", "…", "。", "、", "،", "؛", "؟", "।", "\u{2069}"
    ]
    private static let horizontalSpace: Set<Character> = [" ", "\t", "\u{00A0}", "\u{202F}"]

    /// The link as it goes into a message: the full address.
    static func text(_ url: URL) -> String {
        url.absoluteString
    }

    /// `text` with every occurrence of `link` on its own line (rule 2). A text without the link comes back unchanged.
    static func placeOnOwnLine(_ link: String, in text: String) -> String {
        guard !link.isEmpty, text.contains(link) else { return text }
        var result = ""
        var rest = Substring(text)
        while let range = rest.range(of: link) {
            var before = rest[..<range.lowerBound]
            while let last = before.last, horizontalSpace.contains(last) { before = before.dropLast() }
            result += before
            if !result.isEmpty, !result.hasSuffix("\n") { result += "\n" }
            result += link
            var after = rest[range.upperBound...]
            while let first = after.first, closing.contains(first) || horizontalSpace.contains(first) {
                after = after.dropFirst()
            }
            if let first = after.first, !first.isNewline { result += "\n" }
            rest = after
        }
        result += rest
        return result
    }

    /// `block` (a link or a few lines with one) put after `text` on lines of its own; an empty block leaves the text
    /// alone.
    static func appendOnOwnLine(_ block: String, to text: String) -> String {
        guard !block.isEmpty else { return text }
        var trimmed = Substring(text)
        while let last = trimmed.last, horizontalSpace.contains(last) { trimmed = trimmed.dropLast() }
        guard !trimmed.isEmpty else { return block }
        return trimmed.hasSuffix("\n") ? "\(trimmed)\(block)" : "\(trimmed)\n\(block)"
    }
}
