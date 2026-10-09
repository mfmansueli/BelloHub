//
//  TagRow.swift
//  BelloHub
//

import SwiftUI

/// One tag in the list: its colored dot, its name and how many people carry it. One element for VoiceOver.
struct TagRow: View {
    let tag: Tag
    /// How many clients carry the tag, nil while that is not known yet.
    let clientCount: Int?

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: Spacing.row) {
            TagDot(color: TagColor(token: tag.colorToken), size: 20)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: tag.name).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                if let clientCount {
                    Text(LocalizedStringResource(
                        "tags.row.count", defaultValue: "\(clientCount) people"
                    ).localized(in: locale))
                        .font(Typography.meta).foregroundStyle(Palette.ink2)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 56)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        TagRow(tag: Tag(id: UUID(), name: "Sensitive skin", colorToken: "rose", position: 0), clientCount: 2)
        TagRow(tag: Tag(id: UUID(), name: "Bridal", colorToken: "sage", position: 1), clientCount: 1)
    }
}
