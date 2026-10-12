//
//  FittingRow.swift
//  BelloHub
//

import SwiftUI

/// Buttons side by side only while every label fits on one line; otherwise one under the other. Deciding by the
/// labels themselves, not by the text size, is what keeps a word whole: a fixed "stack at accessibility sizes" rule
/// let "New appointment" break as "appointme / nt" on an iPhone 15 Pro at a large (not accessibility) size, and a
/// German or Turkish label can be twice as long at the default size. Follows the reading direction.
struct FittingRow: Layout {
    var spacing: CGFloat = Spacing.sm
    /// Side by side, the children share the width equally; stacked, each takes the full width. For pairs of full
    /// buttons. Off: each child keeps its natural width (chips), stacked along the leading edge.
    var fillsWidth = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let naturals = subviews.map { $0.sizeThatFits(.unspecified) }
        let needed = neededWidth(naturals)
        // An infinite or missing proposal (a list measuring its natural size) is answered with what the row needs: a
        // layout must never report a non-finite size.
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? needed
        if needed <= width {
            if fillsWidth {
                let cell = cellWidth(in: width, count: subviews.count)
                let height = subviews.map { $0.sizeThatFits(ProposedViewSize(width: cell, height: nil)).height }.max()
                return CGSize(width: width, height: height ?? 0)
            }
            return CGSize(width: needed, height: naturals.map(\.height).max() ?? 0)
        }
        let stacked = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)) }
        let height = stacked.reduce(0) { $0 + $1.height } + gaps(subviews.count)
        return CGSize(width: fillsWidth ? width : min(width, stacked.map(\.width).max() ?? 0), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let isRightToLeft = subviews.layoutDirection == .rightToLeft
        let naturals = subviews.map { $0.sizeThatFits(.unspecified) }
        if neededWidth(naturals) <= bounds.width {
            let cell = cellWidth(in: bounds.width, count: subviews.count)
            var cursor = isRightToLeft ? bounds.maxX : bounds.minX
            for (index, subview) in subviews.enumerated() {
                // A natural child is placed with no proposal so it keeps its measured single line: text laid out in
                // exactly its measured width can round past it and wrap (see `FlowLayout`).
                let proposal = fillsWidth ? ProposedViewSize(width: cell, height: nil) : .unspecified
                let width = fillsWidth ? cell : naturals[index].width
                let height = subview.sizeThatFits(proposal).height
                let originX = isRightToLeft ? cursor - width : cursor
                subview.place(at: CGPoint(x: originX, y: bounds.minY + (bounds.height - height) / 2),
                              proposal: proposal)
                cursor += isRightToLeft ? -(width + spacing) : width + spacing
            }
            return
        }
        var top = bounds.minY
        for subview in subviews {
            let proposal = ProposedViewSize(width: bounds.width, height: nil)
            let size = subview.sizeThatFits(proposal)
            let originX = isRightToLeft ? bounds.maxX - size.width : bounds.minX
            subview.place(at: CGPoint(x: originX, y: top), proposal: ProposedViewSize(width: size.width, height: nil))
            top += size.height + spacing
        }
    }

    // MARK: - Metrics

    /// The width the children need side by side, each label on one line. Rounded up so a label that measures
    /// 120.3 pt never gets 120.
    private func neededWidth(_ naturals: [CGSize]) -> CGFloat {
        let widths = naturals.map { $0.width.rounded(.up) }
        let content = fillsWidth ? (widths.max() ?? 0) * CGFloat(widths.count) : widths.reduce(0, +)
        return content + gaps(widths.count)
    }

    private func cellWidth(in width: CGFloat, count: Int) -> CGFloat {
        max((width - gaps(count)) / CGFloat(max(count, 1)), 0)
    }

    private func gaps(_ count: Int) -> CGFloat {
        spacing * CGFloat(max(count - 1, 0))
    }
}
