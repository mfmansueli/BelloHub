//
//  FittingGrid.swift
//  BelloHub
//

import SwiftUI

/// Cards in equal columns only while every card's label fits its column on one line; otherwise one card per row.
/// The column count follows the labels, not the text size, so a long word ("Wimpernstylistin") never breaks in the
/// middle of a half-width card (see `FittingRow`). For a handful of cards; not lazy.
struct FittingGrid: Layout {
    var columns = 2
    var spacing: CGFloat = Spacing.sm

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let widest = subviews.map { $0.sizeThatFits(.unspecified).width.rounded(.up) }.max() ?? 0
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? widest * CGFloat(columns) + gaps(columns)
        let rows = arrange(width: width, widest: widest, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + gaps(rows.count)
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let isRightToLeft = subviews.layoutDirection == .rightToLeft
        let widest = subviews.map { $0.sizeThatFits(.unspecified).width.rounded(.up) }.max() ?? 0
        var top = bounds.minY
        for row in arrange(width: bounds.width, widest: widest, subviews: subviews) {
            for (position, index) in row.indices.enumerated() {
                let offset = CGFloat(position) * (row.cell + spacing)
                let originX = isRightToLeft ? bounds.maxX - offset - row.cell : bounds.minX + offset
                // Every card of a row takes the row's height, so the cards line up.
                subviews[index].place(at: CGPoint(x: originX, y: top),
                                      proposal: ProposedViewSize(width: row.cell, height: row.height))
            }
            top += row.height + spacing
        }
    }

    // MARK: - Rows

    private struct Row {
        let indices: [Int]
        let cell: CGFloat
        let height: CGFloat
    }

    private func arrange(width: CGFloat, widest: CGFloat, subviews: Subviews) -> [Row] {
        let split = max((width - gaps(columns)) / CGFloat(max(columns, 1)), 0)
        let count = widest <= split ? max(columns, 1) : 1
        let cell = count == 1 ? width : split
        return stride(from: 0, to: subviews.count, by: count).map { start in
            let indices = Array(start..<min(start + count, subviews.count))
            let height = indices.map { subviews[$0].sizeThatFits(ProposedViewSize(width: cell, height: nil)).height }
                .max() ?? 0
            return Row(indices: indices, cell: cell, height: height)
        }
    }

    private func gaps(_ count: Int) -> CGFloat {
        spacing * CGFloat(max(count - 1, 0))
    }
}
