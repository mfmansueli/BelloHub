//
//  FooterNote.swift
//  BelloHub
//

import SwiftUI

/// A quiet block of privacy or explanatory copy under a form or a list.
struct FooterNote: View {
    let text: LocalizedStringKey
    var icon: Icon = .lock

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Image(icon: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.ink3)
                .accessibilityHidden(true)
            Text(text)
                .font(Typography.footnote)
                .foregroundStyle(Palette.ink2)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
