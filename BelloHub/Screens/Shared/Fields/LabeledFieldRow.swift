//
//  LabeledFieldRow.swift
//  BelloHub
//

import SwiftUI

/// A row of a form card: the label on the leading side and the field after it ("Name  Name it your way"). At the
/// accessibility text sizes the field moves under the label, because a fixed label column would leave the field no
/// room. The label is plain text for the eye; the field carries the accessibility label itself.
struct LabeledFieldRow<Field: View>: View {
    let label: LocalizedStringKey
    @ViewBuilder var field: Field

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    labelText
                    fieldView
                }
                .padding(.vertical, Spacing.sm)
            } else {
                HStack(spacing: Spacing.md) {
                    labelText.frame(width: 96, alignment: .leading)
                    fieldView
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: 56)
    }

    private var labelText: some View {
        Text(label).font(Typography.body).foregroundStyle(Palette.ink2).accessibilityHidden(true)
    }

    private var fieldView: some View {
        field.font(Typography.bodyStrong).foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
