//
//  HomeContrastTests.swift
//  BelloHubTests
//

@testable import BelloHub
import SwiftUI
import Testing

/// Every text pair Home, Alerts, Follow-ups, Win back, the reminders list and the client message sheet draw, measured
/// in every appearance (CLAUDE.md section 5). The tiles' own pairs are measured by the Palette suite.
@Suite("Home screens contrast")
struct HomeContrastTests {
    private static let text: [ContrastPair] = [
        ContrastPair(name: "greeting, names and titles: ink on the screen", foreground: Palette.ink,
                     background: Palette.bg, minimum: 4.5),
        ContrastPair(name: "date, subtitles and services: ink2 on the screen", foreground: Palette.ink2,
                     background: Palette.bg, minimum: 4.5),
        ContrastPair(name: "names on a card: ink on the surface", foreground: Palette.ink,
                     background: Palette.surface, minimum: 4.5),
        ContrastPair(name: "services and times on a card: ink2 on the surface", foreground: Palette.ink2,
                     background: Palette.surface, minimum: 4.5),
        ContrastPair(name: "visits left today: roseDeepText on the screen", foreground: Palette.roseDeepText,
                     background: Palette.bg, minimum: 4.5),
        ContrastPair(name: "view follow-ups link: roseText on the surface", foreground: Palette.roseText,
                     background: Palette.surface, minimum: 4.5),
        ContrastPair(name: "win-back strip: peachText on peachWash", foreground: Palette.peachText,
                     background: Palette.peachWash, minimum: 4.5),
        ContrastPair(name: "reminder opened and message sent: sageText on the surface", foreground: Palette.sageText,
                     background: Palette.surface, minimum: 4.5),
        ContrastPair(name: "message sent notice: sageText on the screen", foreground: Palette.sageText,
                     background: Palette.bg, minimum: 4.5),
        ContrastPair(name: "alert card tones: sageText on sageWash", foreground: Palette.sageText,
                     background: Palette.sageWash, minimum: 4.5),
        ContrastPair(name: "alert card tones: roseDeepText on roseWash", foreground: Palette.roseDeepText,
                     background: Palette.roseWash, minimum: 4.5)
    ]

    private static let parts: [ContrastPair] = [
        ContrastPair(name: "chevrons: ink3 on the surface", foreground: Palette.ink3,
                     background: Palette.surface, minimum: 3),
        ContrastPair(name: "next-visit dot: roseDeepText on the surface", foreground: Palette.roseDeepText,
                     background: Palette.surface, minimum: 3)
    ]

    @Test("Every text pair the home screens draw reaches 4.5:1 in every appearance", arguments: Appearance.all)
    @MainActor
    func textIsReadable(appearance: Appearance) {
        for pair in Self.text {
            let ratio = pair.ratio(in: appearance)
            #expect(ratio >= pair.minimum, "\(pair.name) is \(ratio):1 in \(appearance.testDescription)")
        }
    }

    @Test("Every part and icon reaches 3:1 in every appearance", arguments: Appearance.all)
    @MainActor
    func partsAreVisible(appearance: Appearance) {
        for pair in Self.parts {
            let ratio = pair.ratio(in: appearance)
            #expect(ratio >= pair.minimum, "\(pair.name) is \(ratio):1 in \(appearance.testDescription)")
        }
    }
}
