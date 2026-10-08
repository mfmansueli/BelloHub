//
//  SignInRules.swift
//  BelloHub
//

import Foundation

/// The rules of the code step with no UI: what a valid code looks like and when she may ask for another one.
enum SignInRules {
    static let codeLength = 6
    /// Seconds before "send again" works, so a slow SMS is not answered by a second one.
    static let resendSeconds = 30

    /// Digits only, in ASCII, at most six: a code pasted from a message, typed with Arabic-Indic digits or with a
    /// space in the middle ("123 456") comes out as "123456".
    static func sanitizedCode(_ raw: String) -> String {
        String(DigitNormalizer.digitsOnly(DigitNormalizer.ascii(raw)).prefix(codeLength))
    }

    static func isComplete(_ code: String) -> Bool {
        code.count == codeLength
    }

    /// Whole seconds left before she can ask for another code; 0 when she can.
    static func secondsUntilResend(sentAt: Date?, now: Date) -> Int {
        guard let sentAt else { return 0 }
        let elapsed = now.timeIntervalSince(sentAt)
        // A clock that moved backwards must not lock her out for long: cap at the full wait.
        guard elapsed >= 0 else { return resendSeconds }
        return max(0, resendSeconds - Int(elapsed))
    }
}
