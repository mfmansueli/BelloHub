//
//  VisitTile.swift
//  BelloHub
//

import SwiftUI

/// "Last visit" or "Next": the service and the day, in one card that reads as one VoiceOver element.
struct VisitTile: View {
    struct Status {
        let label: LocalizedStringKey
        let style: StatusStyle
    }

    let title: LocalizedStringKey
    /// The service name, or nil when there is nothing to show yet.
    let service: String?
    let detail: String?
    let emptyText: LocalizedStringKey
    var status: Status?
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(Typography.footnote)
                .foregroundStyle(Palette.ink2)
            if let service {
                Text(verbatim: service)
                    .font(Typography.bodyStrong)
                    .foregroundStyle(Palette.ink)
                if let detail {
                    Text(verbatim: detail)
                        .font(Typography.meta)
                        .foregroundStyle(Palette.ink2)
                }
                if let status {
                    StatusChip(label: status.label, style: status.style)
                        .padding(.top, Spacing.xxs)
                }
            } else {
                Text(emptyText)
                    .font(Typography.meta)
                    .foregroundStyle(Palette.ink2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(Spacing.md)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.tileSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.tileSmall, style: .continuous).strokeBorder(Palette.hairline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}
