//
//  TimeZoneNoticeRow.swift
//  BelloHub
//

import SwiftUI

/// Calendar's quiet line about the time zone: which zone the times are in, and the iPhone's. It is the label of the
/// menu of choices (`TimeZoneNoticeContent`). Secondary ink on the page, so it never competes with the day below.
struct TimeZoneNoticeRow: View {
    let text: TimeZoneNoticeText
    let isSaving: Bool

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.row) {
            Image(icon: .globe)
                .font(Typography.meta)
                .foregroundStyle(Palette.ink2)
                .accessibilityHidden(true)
            Text(text.row.localized(in: locale))
                .font(Typography.meta)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if isSaving {
                ProgressView()
            } else {
                Image(icon: .chevronUpDown)
                    .font(Typography.footnoteStrong)
                    .foregroundStyle(Palette.ink2)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: Spacing.touchTarget)
        .contentShape(Rectangle())
    }
}
