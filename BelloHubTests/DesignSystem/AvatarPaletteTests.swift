//
//  AvatarPaletteTests.swift
//  BelloHubTests
//

@testable import BelloHub
import SwiftUI
import Testing
import UIKit

@Suite("AvatarPalette and Initials")
struct AvatarPaletteTests {
    @Test("A person keeps the same pair for the same id")
    func pairIsStable() {
        let first = AvatarPalette.pair(for: "client-42")

        for _ in 0..<5 {
            #expect(AvatarPalette.pair(for: "client-42") == first)
        }
    }

    @Test("Known ids map to known pairs (FNV-1a is the contract, so a refactor cannot reshuffle colors)")
    func knownVectors() {
        #expect(AvatarPalette.pair(for: "") == AvatarPalette.allCases[Int(UInt64(0xcbf2_9ce4_8422_2325) % 4)])
        #expect(AvatarPalette.pair(for: "a") == AvatarPalette.allCases[Int(UInt64(0xaf63_dc4c_8601_ec8c) % 4)])
    }

    @Test("Ids spread over all four pairs")
    func idsSpreadOverAllPairs() {
        let used = Set((0..<200).map { AvatarPalette.pair(for: "id-\($0)") })

        #expect(used.count == AvatarPalette.allCases.count)
    }

    @Test("Initials text reaches 4.5:1 on both ends of every gradient in every appearance",
          arguments: Appearance.all)
    func initialsAreReadable(appearance: Appearance) {
        for pair in AvatarPalette.allCases {
            for background in [pair.start, pair.end] {
                let ratio = ContrastPair(name: "\(pair)", foreground: pair.text, background: background, minimum: 4.5)
                    .ratio(in: appearance)
                #expect(ratio >= 4.5, "\(pair) initials are \(ratio):1 in \(appearance.testDescription)")
            }
        }
    }

    @Test("Initials are the first letters of the first and last words",
          arguments: [
              ("Camila Rocha", "CR"),
              ("Maria de Fátima Souza", "MS"),
              ("ana", "A"),
              ("  Julia   Mendes ", "JM"),
              ("", "")
          ])
    func initials(name: String, expected: String) {
        #expect(Initials.make(from: name, locale: Locale(identifier: "en_US")) == expected)
    }

    @Test("Turkish casing is applied to initials")
    func turkishInitials() {
        #expect(Initials.make(from: "ilker yıldız", locale: Locale(identifier: "tr_TR")) == "İY")
    }

    @Test("Scripts without case keep their letters")
    func scriptsWithoutCase() {
        #expect(Initials.make(from: "سارة أحمد", locale: Locale(identifier: "ar_SA")) == "سأ")
        // The first user-perceived character of "प्रिया" is the conjunct plus vowel sign "प्रि", not a lone "प".
        #expect(Initials.make(from: "प्रिया शर्मा", locale: Locale(identifier: "hi_IN")) == "प्रिश")
    }
}
