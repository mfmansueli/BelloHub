//
//  QuickReplyRow.swift
//  BelloHub
//

import SwiftUI

/// One reply in the list: its name and the first line of its message, cut with an ellipsis. The words in curly braces
/// are shown as written, as in the prototype, because they are what she edits. It is the label of a button; the
/// caller gives the button its identifier.
struct QuickReplyRow: View {
    let reply: QuickReply

    var body: some View {
        HStack(spacing: Spacing.row) {
            Image(icon: .chat)
                .foregroundStyle(Palette.sageText)
                .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                .background(Palette.sageWash, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: reply.title).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Text(verbatim: reply.text).font(Typography.meta).foregroundStyle(Palette.ink2).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(icon: .forward).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink3)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 64)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
