//
//  TimeZoneNoticeRow.swift
//  BelloHub
//

import SwiftUI

/// Calendar's quiet line about the time zone: which zone the times are in, and the iPhone's. One tap opens the
/// choices. Secondary ink on the page, so it never competes with the day it sits above.
struct TimeZoneNoticeRow: View {
    let text: TimeZoneNoticeText
    let isSaving: Bool
    let onTap: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        Button(action: onTap) {
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
                    Image(icon: .forward)
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
        .buttonStyle(.plain)
        .disabled(isSaving)
        .accessibilityHint(Text("timeZoneNotice.row.hint"))
        .accessibilityIdentifier("calendar.timeZoneNotice")
    }
}
