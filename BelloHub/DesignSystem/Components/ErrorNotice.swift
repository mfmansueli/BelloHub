//
//  ErrorNotice.swift
//  BelloHub
//

import SwiftUI

/// An `InlineNotice` in the warning style for a message that is already text (what a ViewModel says when a read or a
/// save failed), with an optional action such as "Try again". The message says what happened and how to fix it; it is
/// never an SDK's error text.
struct ErrorNotice: View {
    let message: String
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: Spacing.row) {
                Image(icon: .alert)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.amberText)
                    .accessibilityHidden(true)
                Text(verbatim: message)
                    .font(Typography.meta)
                    .foregroundStyle(Palette.amberText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(Typography.metaStrong)
                        .foregroundStyle(Palette.amberText)
                        .frame(minHeight: Spacing.touchTarget)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.amberBg, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    ErrorNotice(message: "We could not save this change.", actionTitle: "Try again") {}
        .padding()
}
