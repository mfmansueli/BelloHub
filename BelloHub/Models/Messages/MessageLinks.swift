//
//  MessageLinks.swift
//  BelloHub
//

import Foundation

/// The links that open a chat with the text ready (D14: she reads it and presses send). Pure, so the exact URLs are
/// tested without a phone. It lives in `Models/Messages/` because the agenda and the Home screens both send messages.
///
/// A message to a client never carries clinical data (docs/06-PRIVACY-SECURITY.md section 8): callers build the text
/// from quick replies and the visit's day, time and service name only.
enum MessageLinks {
    /// Everything except the unreserved characters is percent-encoded, so `&`, `=`, `+`, `#` and `?` inside a message
    /// can never end the `text` parameter early.
    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    /// The digits of a number in international form (`+5511981234410`), or nil when it is not one (8 to 15 digits
    /// after a plus sign). A malformed value read from the vault never reaches the system.
    static func digits(ofE164 phone: String?) -> String? {
        guard let phone, phone.hasPrefix("+") else { return nil }
        let digits = DigitNormalizer.digitsOnly(DigitNormalizer.ascii(phone))
        return (8...15).contains(digits.count) ? digits : nil
    }

    /// `https://wa.me/5511981234410?text=Hi%20Ana`. Without a valid number there is no link.
    static func whatsApp(phoneE164: String?, text: String) -> URL? {
        guard let digits = digits(ofE164: phoneE164) else { return nil }
        let query = text.isEmpty ? "" : "?text=\(encoded(text))"
        return URL(string: "https://wa.me/\(digits)\(query)")
    }

    /// `sms:+5511981234410&body=Hi%20Ana`: the form every iOS version understands.
    static func sms(phoneE164: String?, text: String) -> URL? {
        guard let digits = digits(ofE164: phoneE164) else { return nil }
        let body = text.isEmpty ? "" : "&body=\(encoded(text))"
        return URL(string: "sms:+\(digits)\(body)")
    }

    static func encoded(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }
}
