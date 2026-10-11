//
//  PhoneLauncherTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("PhoneLauncher")
struct PhoneLauncherTests {
    @Test("A number in international form becomes a tel link with only its digits")
    func telLink() {
        #expect(PhoneLauncher.telURL(forE164: "+5511981234410")?.absoluteString == "tel:+5511981234410")
        #expect(PhoneLauncher.telURL(forE164: "+1 (415) 555-2671")?.absoluteString == "tel:+14155552671")
    }

    @Test("Anything that is not an international number never reaches the system", arguments: [
        "", "11981234410", "+55", "+1234567890123456", "tel:+5511981234410", "+55 11 abc"
    ])
    func refusesWhatIsNotANumber(input: String) {
        #expect(PhoneLauncher.telURL(forE164: input) == nil)
    }
}
