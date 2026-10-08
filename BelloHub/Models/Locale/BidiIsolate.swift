//
//  BidiIsolate.swift
//  BelloHub
//

import Foundation

/// Unicode isolates keep a name, phone number, time or URL from scrambling the text around it in
/// right-to-left languages. Every interpolated value in a message template or a notification goes
/// through here (docs/07-LOCALIZATION.md section 2.5).
enum BidiIsolate {
    static let firstStrongIsolate: Character = "\u{2068}"
    static let leftToRightIsolate: Character = "\u{2066}"
    static let popDirectionalIsolate: Character = "\u{2069}"

    /// Isolates `text`, letting its own first strong character decide its direction (names).
    static func wrap(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        return "\(firstStrongIsolate)\(text)\(popDirectionalIsolate)"
    }

    /// Isolates `text` as left-to-right (phone numbers, times, URLs, codes), even inside Arabic.
    static func wrapLeftToRight(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        return "\(leftToRightIsolate)\(text)\(popDirectionalIsolate)"
    }

    /// Removes the isolate marks, for places where they must not appear (plain-text export, `wa.me` text
    /// is the exception: WhatsApp renders them correctly, so messages keep them).
    static func strip(_ text: String) -> String {
        text.filter { $0 != firstStrongIsolate && $0 != leftToRightIsolate && $0 != popDirectionalIsolate }
    }
}
