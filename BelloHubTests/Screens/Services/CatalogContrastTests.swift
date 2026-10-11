//
//  CatalogContrastTests.swift
//  BelloHubTests
//

@testable import BelloHub
import SwiftUI
import Testing

/// Every text pair the services, add-ons, products, credentials and team screens draw, measured in every appearance
/// (CLAUDE.md section 5). Most are also in `PaletteContrastTests`; they are listed again here so a change to one of
/// these screens that picks a new pair has one obvious place to add it.
@Suite("Catalog screens contrast")
struct CatalogContrastTests {
    private static let text: [ContrastPair] = [
        ContrastPair(name: "service name: ink on the list row", foreground: Palette.ink, background: Palette.surface,
                     minimum: 4.5),
        ContrastPair(name: "service details: ink2 on the list row", foreground: Palette.ink2,
                     background: Palette.surface, minimum: 4.5),
        ContrastPair(name: "subtitle and footnotes: ink2 on the screen", foreground: Palette.ink2,
                     background: Palette.bg, minimum: 4.5),
        ContrastPair(name: "setting badge: neutralText on neutralWash", foreground: Palette.neutralText,
                     background: Palette.neutralWash, minimum: 4.5),
        ContrastPair(name: "contraindication badge: coralText on coralBg", foreground: Palette.coralText,
                     background: Palette.coralBg, minimum: 4.5),
        ContrastPair(name: "inactive badge: amberText on amberBg", foreground: Palette.amberText,
                     background: Palette.amberBg, minimum: 4.5),
        ContrastPair(name: "Shared chip: sageText on sageWash", foreground: StatusPalette.confirmed.foreground,
                     background: StatusPalette.confirmed.background, minimum: 4.5),
        ContrastPair(name: "Private chip: neutralText on neutralWash", foreground: StatusPalette.completed.foreground,
                     background: StatusPalette.completed.background, minimum: 4.5),
        ContrastPair(name: "add rows: roseText on the list row", foreground: Palette.roseText,
                     background: Palette.surface, minimum: 4.5),
        ContrastPair(name: "what clients see: sageText on sageWash", foreground: Palette.sageText,
                     background: Palette.sageWash, minimum: 4.5),
        ContrastPair(name: "add-on chip in the preview: ink on surface", foreground: Palette.ink,
                     background: Palette.surface, minimum: 4.5),
        ContrastPair(name: "credential icon: roseDeepText on roseWash", foreground: Palette.roseDeepText,
                     background: Palette.roseWash, minimum: 4.5),
        ContrastPair(name: "field errors: coralText on the screen", foreground: Palette.coralText,
                     background: Palette.bg, minimum: 4.5),
        ContrastPair(name: "field text: ink on the field fill", foreground: Palette.ink, background: Palette.sunken,
                     minimum: 4.5),
        ContrastPair(name: "field prompt: ink2 on the field fill", foreground: Palette.ink2,
                     background: Palette.sunken, minimum: 4.5),
        ContrastPair(name: "invalid field text: coralText on the field fill", foreground: Palette.coralText,
                     background: Palette.sunken, minimum: 4.5),
        ContrastPair(name: "selected chip: selectionInk on selectionFill", foreground: Palette.selectionInk,
                     background: Palette.selectionFill, minimum: 4.5)
    ]

    private static let parts: [ContrastPair] = [
        ContrastPair(name: "chevrons and icons: ink3 on the list row", foreground: Palette.ink3,
                     background: Palette.surface, minimum: 3),
        ContrastPair(name: "switch track: sage on the list row", foreground: Palette.sage,
                     background: Palette.surface, minimum: 3),
        ContrastPair(name: "field border: fieldBorder on the field fill", foreground: Palette.fieldBorder,
                     background: Palette.sunken, minimum: 3)
    ]

    @Test("Every text pair the catalog screens draw reaches 4.5:1 in every appearance", arguments: Appearance.all)
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
