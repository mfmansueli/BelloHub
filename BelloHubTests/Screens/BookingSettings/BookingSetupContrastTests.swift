//
//  BookingSetupContrastTests.swift
//  BelloHubTests
//

@testable import BelloHub
import SwiftUI
import Testing

/// The text pairs the booking setup screens draw (Availability, Booking page, Share link, the two policies and Quick
/// replies), measured in every appearance. Each is one of the shared palette's pairs; they are listed here so a
/// change of what a screen draws on what shows up as a failing pair, not as a surprise on a phone (CLAUDE.md section
/// 5).
@Suite("Booking setup contrast")
struct BookingSetupContrastTests {
    private static func text(_ name: String, _ foreground: Color, on background: Color, minimum: Double = 4.5)
        -> ContrastPair {
        ContrastPair(name: name, foreground: foreground, background: background, minimum: minimum)
    }

    private static let pairs: [ContrastPair] = [
        // Rows, section titles, subtitles and hints on the grouped lists and the cards.
        text("ink on bg (section titles)", Palette.ink, on: Palette.bg),
        text("ink on surface (rows)", Palette.ink, on: Palette.surface),
        text("ink2 on bg (subtitles)", Palette.ink2, on: Palette.bg),
        text("ink2 on surface (row details)", Palette.ink2, on: Palette.surface),
        text("ink on sunken (text fields, pasted texts)", Palette.ink, on: Palette.sunken),
        text("ink2 on sunken (the address host)", Palette.ink2, on: Palette.sunken),
        // Actions and statuses.
        text("roseText on surface (Add a break, link rows)", Palette.roseText, on: Palette.surface),
        text("roseText on bg (Choose a return date)", Palette.roseText, on: Palette.bg),
        text("coralText on bg (address and stretch errors)", Palette.coralText, on: Palette.bg),
        text("coralText on surface (sheet errors)", Palette.coralText, on: Palette.surface),
        text("sageText on bg (address available)", Palette.sageText, on: Palette.bg),
        text("sageText on sageWash (Always counts, the preview)", Palette.sageText, on: Palette.sageWash),
        text("amberText on bg (words not filled in)", Palette.amberText, on: Palette.bg),
        text("amberText on amberBg (error notices)", Palette.amberText, on: Palette.amberBg),
        text("roseDeepText on roseWash (icon tiles)", Palette.roseDeepText, on: Palette.roseWash),
        text("peachText on peachWash (icon tiles)", Palette.peachText, on: Palette.peachWash),
        text("inkOnFill on ink (primary and selected chips)", Palette.inkOnFill, on: Palette.ink),
        // The link card is the hero: its text colors are measured on its gradient in HeroContrastTests; the chips on
        // it:
        ContrastPair(name: "hero ink on a hero button", foreground: HeroPalette.ink, background: HeroPalette.raised,
            minimum: 4.5),
        ContrastPair(name: "hero ink2 on a hero button", foreground: HeroPalette.ink2,
            background: HeroPalette.raised, minimum: 4.5),
        // Parts: the chevrons, the switch track and the field borders.
        text("ink3 chevron on surface", Palette.ink3, on: Palette.surface, minimum: 3),
        text("sage switch track on surface", Palette.sage, on: Palette.surface, minimum: 3),
        text("fieldBorder on sunken", Palette.fieldBorder, on: Palette.sunken, minimum: 3)
    ]

    @Test("Every pair the booking setup screens draw is readable in every appearance", arguments: Appearance.all)
    @MainActor
    func pairsAreReadable(appearance: Appearance) {
        for pair in Self.pairs {
            let ratio = pair.ratio(in: appearance)
            #expect(ratio >= pair.minimum, "\(pair.name) is \(ratio):1 in \(appearance.testDescription)")
        }
    }
}
