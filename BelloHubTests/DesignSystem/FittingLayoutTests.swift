//
//  FittingLayoutTests.swift
//  BelloHubTests
//

@testable import BelloHub
import SwiftUI
import Testing

/// Fixed-size boxes stand in for labels: a box's natural width is what a label needs on one line.
@MainActor
@Suite("FittingRow and FittingGrid")
struct FittingLayoutTests {
    private func box(width: CGFloat = 100) -> some View {
        Color.clear.frame(width: width, height: 20)
    }

    private func size(of view: some View, width: CGFloat) -> CGSize {
        UIHostingController(rootView: view).sizeThatFits(in: CGSize(width: width, height: .infinity))
    }

    @Test("Side by side while both fit on one line")
    func rowSideBySide() {
        let row = FittingRow(spacing: 8) { box(); box() }
        #expect(size(of: row, width: 300).height == 20)
    }

    @Test("Stacked when they do not fit side by side, instead of squeezing them")
    func rowStacks() {
        let row = FittingRow(spacing: 8) { box(); box() }
        #expect(size(of: row, width: 150).height == 48)
    }

    @Test("Equal widths: the widest child decides, so a long label stacks both")
    func rowEqualWidths() {
        // 100 + 8 + 160 fits 300, but two cells of 160 do not.
        let natural = FittingRow(spacing: 8) { box(); box(width: 160) }
        let equal = FittingRow(spacing: 8, fillsWidth: true) { box(); box(width: 160) }
        #expect(size(of: natural, width: 300).height == 20)
        #expect(size(of: equal, width: 300).height == 48)
    }

    @Test("Equal widths side by side take the whole width")
    func rowFillsWidth() {
        let row = FittingRow(spacing: 8, fillsWidth: true) { box(); box() }
        #expect(size(of: row, width: 300).width == 300)
    }

    @Test("Two columns while every card fits half the width")
    func gridTwoColumns() {
        let grid = FittingGrid(spacing: 8) { box(); box(); box(); box() }
        #expect(size(of: grid, width: 300).height == 48)
    }

    @Test("One card per row when one card does not fit half the width")
    func gridOneColumn() {
        let grid = FittingGrid(spacing: 8) { box(); box(); box(width: 200); box() }
        #expect(size(of: grid, width: 300).height == 104)
    }
}
