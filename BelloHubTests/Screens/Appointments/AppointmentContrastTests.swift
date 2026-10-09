//
//  AppointmentContrastTests.swift
//  BelloHubTests
//

@testable import BelloHub
import SwiftUI
import Testing

/// Every text pair the visit detail and its sheets draw, measured in every appearance (CLAUDE.md section 5).
@Suite("Appointment screens contrast")
struct AppointmentContrastTests {
    private static let text: [ContrastPair] = [
        ContrastPair(name: "client and summary: ink on the screen", foreground: Palette.ink, background: Palette.bg,
                     minimum: 4.5),
        ContrastPair(name: "details and hints: ink2 on the screen", foreground: Palette.ink2, background: Palette.bg,
                     minimum: 4.5),
        ContrastPair(name: "details on a card: ink2 on the surface", foreground: Palette.ink2,
                     background: Palette.surface, minimum: 4.5),
        ContrastPair(name: "plan and ready notices: sageText on sageWash", foreground: Palette.sageText,
                     background: Palette.sageWash, minimum: 4.5),
        ContrastPair(name: "late chip and warnings: amberText on amberBg", foreground: Palette.amberText,
                     background: Palette.amberBg, minimum: 4.5),
        ContrastPair(name: "allergy notice: coralText on coralBg", foreground: Palette.coralText,
                     background: Palette.coralBg, minimum: 4.5),
        ContrastPair(name: "errors: coralText on the screen", foreground: Palette.coralText, background: Palette.bg,
                     minimum: 4.5),
        ContrastPair(name: "links: roseText on the screen", foreground: Palette.roseText, background: Palette.bg,
                     minimum: 4.5),
        ContrastPair(name: "links on a card: roseText on the surface", foreground: Palette.roseText,
                     background: Palette.surface, minimum: 4.5),
        ContrastPair(name: "message preview: ink on the field fill", foreground: Palette.ink,
                     background: Palette.sunken, minimum: 4.5)
    ]

    private static let parts: [ContrastPair] = [
        ContrastPair(name: "separators and timeline: ink3 on the screen", foreground: Palette.ink3,
                     background: Palette.bg, minimum: 3),
        ContrastPair(name: "switch track: sage on the surface", foreground: Palette.sage,
                     background: Palette.surface, minimum: 3)
    ]

    @Test("Every text pair the visit screens draw reaches 4.5:1 in every appearance", arguments: Appearance.all)
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
