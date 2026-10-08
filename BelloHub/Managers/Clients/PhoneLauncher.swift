//
//  PhoneLauncher.swift
//  BelloHub
//

import Foundation
import UIKit

/// The real call: a `tel:` link handed to the system, which asks before dialing.
@MainActor
final class PhoneLauncher: PhoneLaunching {
    func call(_ phoneE164: String) async -> Bool {
        guard let url = Self.telURL(forE164: phoneE164) else { return false }
        return await UIApplication.shared.open(url)
    }

    /// `tel:+5511987654321` for a number in international form; nil for anything else, so a malformed value read from
    /// the vault never reaches the system. Pure, so it is tested without a phone.
    nonisolated static func telURL(forE164 phone: String) -> URL? {
        let digits = DigitNormalizer.digitsOnly(DigitNormalizer.ascii(phone))
        guard phone.hasPrefix("+"), (8...15).contains(digits.count) else { return nil }
        return URL(string: "tel:+\(digits)")
    }
}
