//
//  SectionHeader.swift
//  BelloHub
//

import SwiftUI

/// Sentence-case title (20/600) with an optional trailing action (14/600, `roseText`).
/// 30 pt above and 12 pt below; the heading trait makes it a VoiceOver rotor stop.
struct SectionHeader: View {
    let title: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Typography.section)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Spacing.row)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(Typography.metaStrong)
                        .foregroundStyle(Palette.roseText)
                        .frame(minHeight: Spacing.touchTarget)
                }
            }
        }
        .padding(.top, Spacing.section)
        .padding(.bottom, Spacing.row)
    }
}
