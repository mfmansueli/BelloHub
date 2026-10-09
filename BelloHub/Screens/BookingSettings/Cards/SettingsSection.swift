//
//  SettingsSection.swift
//  BelloHub
//

import SwiftUI

/// A titled block of a settings screen: the title as a heading, an optional line explaining it, then the content. The
/// booking screens are stacks of these over the background, as in the prototype, rather than grouped lists, because
/// their content is chips and choice cards that a list row cannot hold.
struct SettingsSection<Content: View>: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(Typography.section)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle).font(Typography.meta).foregroundStyle(Palette.ink2)
                }
            }
            content
        }
    }
}
