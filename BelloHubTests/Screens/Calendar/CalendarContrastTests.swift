//
//  CalendarContrastTests.swift
//  BelloHubTests
//

@testable import BelloHub
import SwiftUI
import Testing

@Suite("Calendar contrast")
struct CalendarContrastTests {
    private static let text: [ContrastPair] = [
        ContrastPair(name: "confirmed visit: sageText on sageWash", foreground: StatusPalette.confirmed.foreground,
                     background: StatusPalette.confirmed.background, minimum: 4.5),
        ContrastPair(name: "booked visit: roseDeepText on roseWash", foreground: StatusPalette.nextUp.foreground,
                     background: StatusPalette.nextUp.background, minimum: 4.5),
        ContrastPair(name: "finished visit: neutralText on neutralWash", foreground: StatusPalette.completed.foreground,
                     background: StatusPalette.completed.background, minimum: 4.5),
        ContrastPair(name: "no-show: coralText on coralBg", foreground: StatusPalette.attention.foreground,
                     background: StatusPalette.attention.background, minimum: 4.5),
        ContrastPair(name: "hour labels: ink2 on the screen", foreground: Palette.ink2, background: Palette.bg,
                     minimum: 4.5),
        ContrastPair(name: "break band: ink2 on sunken", foreground: Palette.ink2, background: Palette.sunken,
                     minimum: 4.5),
        ContrastPair(name: "blocked band: neutralText on neutralWash", foreground: Palette.neutralText,
                     background: Palette.neutralWash, minimum: 4.5),
        ContrastPair(name: "selected day: inkOnFill on ink", foreground: Palette.inkOnFill, background: Palette.ink,
                     minimum: 4.5),
        ContrastPair(name: "today in the strip: roseText on the screen", foreground: Palette.roseText,
                     background: Palette.bg, minimum: 4.5),
        ContrastPair(name: "today in the week summary: roseDeepText on the list row", foreground: Palette.roseDeepText,
                     background: Palette.surface, minimum: 4.5),
        ContrastPair(name: "warning: amberText on amberBg", foreground: Palette.amberText, background: Palette.amberBg,
                     minimum: 4.5),
        ContrastPair(name: "safety warning: coralText on coralBg", foreground: Palette.coralText,
                     background: Palette.coralBg, minimum: 4.5),
        ContrastPair(name: "information: sageText on sageWash", foreground: Palette.sageText,
                     background: Palette.sageWash, minimum: 4.5),
        ContrastPair(name: "week summary tiles: ink2 on sageWash", foreground: Palette.ink2,
                     background: Palette.sageWash, minimum: 4.5),
        ContrastPair(name: "week summary tiles: ink2 on peachWash", foreground: Palette.ink2,
                     background: Palette.peachWash, minimum: 4.5),
        ContrastPair(name: "week summary tiles: ink2 on roseWash", foreground: Palette.ink2,
                     background: Palette.roseWash, minimum: 4.5)
    ]

    private static let parts: [ContrastPair] = [
        ContrastPair(name: "current-time marker: roseText on the screen", foreground: Palette.roseText,
                     background: Palette.bg, minimum: 3),
        ContrastPair(name: "progress bar: sage on the list row", foreground: Palette.sage,
                     background: Palette.surface, minimum: 3)
    ]

    @Test("Every text pair the calendar draws reaches 4.5:1 in every appearance", arguments: Appearance.all)
    @MainActor
    func textIsReadable(appearance: Appearance) {
        for pair in Self.text {
            let ratio = pair.ratio(in: appearance)
            #expect(ratio >= pair.minimum, "\(pair.name) is \(ratio):1 in \(appearance.testDescription)")
        }
    }

    @Test("The marker and the bars reach 3:1 in every appearance", arguments: Appearance.all)
    @MainActor
    func partsAreVisible(appearance: Appearance) {
        for pair in Self.parts {
            let ratio = pair.ratio(in: appearance)
            #expect(ratio >= pair.minimum, "\(pair.name) is \(ratio):1 in \(appearance.testDescription)")
        }
    }
}
