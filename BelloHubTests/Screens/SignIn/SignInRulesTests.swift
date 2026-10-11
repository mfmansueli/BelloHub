//
//  SignInRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("SignInRules")
struct SignInRulesTests {
    @Test("A code keeps only ASCII digits, at most six", arguments: [
        ("123456", "123456"), ("123 456", "123456"), ("12-34-56", "123456"), ("1234567890", "123456"),
        ("٣٢١٠٩٨", "321098"), ("abc", ""), ("", "")
    ])
    func sanitized(raw: String, expected: String) {
        #expect(SignInRules.sanitizedCode(raw) == expected)
    }

    @Test("Only six digits are a complete code")
    func complete() {
        #expect(SignInRules.isComplete("123456"))
        #expect(!SignInRules.isComplete("12345"))
        #expect(!SignInRules.isComplete(""))
    }

    @Test("The resend countdown runs down to zero and never goes negative")
    func countdown() {
        let sent = TestClock.now
        #expect(SignInRules.secondsUntilResend(sentAt: nil, now: sent) == 0)
        #expect(SignInRules.secondsUntilResend(sentAt: sent, now: sent) == SignInRules.resendSeconds)
        #expect(SignInRules.secondsUntilResend(sentAt: sent, now: sent.addingTimeInterval(10)) == 20)
        #expect(SignInRules.secondsUntilResend(sentAt: sent, now: sent.addingTimeInterval(30)) == 0)
        #expect(SignInRules.secondsUntilResend(sentAt: sent, now: sent.addingTimeInterval(500)) == 0)
    }

    @Test("A clock that moved backwards waits the full time, not longer")
    func backwardsClock() {
        let sent = TestClock.now
        let earlier = sent.addingTimeInterval(-90)
        #expect(SignInRules.secondsUntilResend(sentAt: sent, now: earlier) == SignInRules.resendSeconds)
    }
}
