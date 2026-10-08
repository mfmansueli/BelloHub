//
//  FlowLayout.swift
//  BelloHub
//

import SwiftUI

/// Places its children in rows and wraps to a new row when one does not fit: tag chips. Follows the reading
/// direction, so in Arabic the rows start on the right.
struct FlowLayout: Layout {
    var spacing: CGFloat = Spacing.sm
    var lineSpacing: CGFloat = Spacing.sm
    /// Centers each row, for a short sentence with a link at the end that may wrap.
    var isCentered = false
    /// Measures every child with the row's full width, so a label longer than the row wraps onto more lines instead
    /// of running past the edge. Off by default: children keep their natural single-line width.
    var wrapsLongChildren = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        let height = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let isRightToLeft = subviews.layoutDirection == .rightToLeft
        var rowTop = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            let slack = isCentered ? max(bounds.width - row.width, 0) / 2 : 0
            var cursor = isRightToLeft ? bounds.maxX - slack : bounds.minX + slack
            for item in row.items {
                let size = item.size
                let originX = isRightToLeft ? cursor - size.width : cursor
                subviews[item.index].place(at: CGPoint(x: originX, y: rowTop), proposal: ProposedViewSize(size))
                cursor += isRightToLeft ? -(size.width + spacing) : size.width + spacing
            }
            rowTop += row.height + lineSpacing
        }
    }

    // MARK: - Rows

    private struct Row {
        var items: [(index: Int, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for (index, subview) in subviews.enumerated() {
            let proposal = wrapsLongChildren ? ProposedViewSize(width: width, height: nil) : .unspecified
            let size = subview.sizeThatFits(proposal)
            let needed = current.items.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.items.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.items.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.items.append((index, size))
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}
