//
//  AddRowLabel.swift
//  BelloHub
//

import SwiftUI

/// The label of the "+ New …" row that ends a list: a plus, a rose title, a full-height tap area. The caller wraps
/// it in a `Button` and gives that the identifier.
struct AddRowLabel: View {
    let title: LocalizedStringKey

    var body: some View {
        HStack(spacing: Spacing.row) {
            Image(icon: .plus)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)
            Text(title).font(Typography.bodyStrong)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Palette.roseText)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}
