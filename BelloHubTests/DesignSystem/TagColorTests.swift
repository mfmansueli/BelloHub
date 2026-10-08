//
//  TagColorTests.swift
//  BelloHubTests
//

@testable import BelloHub
import SwiftUI
import Testing

@Suite("TagColor")
struct TagColorTests {
    @Test("The four tokens are the ones the catalog and the stored tags use")
    func tokens() {
        #expect(TagColor.allCases.map(\.token) == ["rose", "sage", "peach", "sand"])
    }

    @Test("A stored token reads back as its color", arguments: TagColor.allCases)
    func roundTrip(color: TagColor) {
        #expect(TagColor(token: color.token) == color)
    }

    @Test("An unknown or empty token reads as sand instead of failing")
    func unknownTokens() {
        #expect(TagColor(token: "mauve") == .sand)
        #expect(TagColor(token: "") == .sand)
        #expect(TagColor(token: "Rose") == .sand)
    }

    @Test("Every color has its own name key, so the choice can be read aloud")
    func names() {
        #expect(Set(TagColor.allCases.map { String(describing: $0.name.key) }).count == 4)
    }
}

@Suite("TagColor contrast")
struct TagColorContrastTests {
    /// The chip a tag color can sit in: its text on its wash.
    static let textPairs: [ContrastPair] = TagColor.allCases.map {
        ContrastPair(
            name: "\($0.rawValue) washText on wash", foreground: $0.washText, background: $0.wash, minimum: 4.5
        )
    }

    /// The ring of the dot must keep the shape visible on every surface the dot sits on: the list row (`surface`), the
    /// page (`bg`) and the unselected color choice (`sunken`).
    static let partPairs: [ContrastPair] = TagColor.allCases.flatMap { color in
        [("surface", Palette.surface), ("bg", Palette.bg), ("sunken", Palette.sunken)].map { name, background in
            ContrastPair(
                name: "\(color.rawValue) outline on \(name)", foreground: color.outline, background: background,
                minimum: 3
            )
        }
    }

    @Test("Every tag chip text reaches 4.5:1 in every appearance", arguments: Appearance.all)
    @MainActor
    func textPairsMeetAA(appearance: Appearance) {
        for pair in Self.textPairs {
            let ratio = pair.ratio(in: appearance)
            #expect(ratio >= pair.minimum, "\(pair.name) is \(ratio):1 in \(appearance.testDescription)")
        }
    }

    @Test("Every dot ring reaches 3:1 on the surfaces it sits on, in every appearance", arguments: Appearance.all)
    @MainActor
    func ringsMeetNonTextContrast(appearance: Appearance) {
        for pair in Self.partPairs {
            let ratio = pair.ratio(in: appearance)
            #expect(ratio >= pair.minimum, "\(pair.name) is \(ratio):1 in \(appearance.testDescription)")
        }
    }

    @Test("Increase Contrast never lowers a ratio", arguments: [false, true])
    @MainActor
    func increasedContrastIsNeverWorse(isDark: Bool) {
        let normal = Appearance(isDark: isDark, isIncreasedContrast: false)
        let increased = Appearance(isDark: isDark, isIncreasedContrast: true)

        for pair in Self.textPairs + Self.partPairs {
            #expect(
                pair.ratio(in: increased) >= pair.ratio(in: normal) - 0.001,
                "\(pair.name) got worse with Increase Contrast (\(isDark ? "dark" : "light"))"
            )
        }
    }
}
