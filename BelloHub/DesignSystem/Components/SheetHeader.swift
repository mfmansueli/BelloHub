//
//  SheetHeader.swift
//  BelloHub
//

import SwiftUI

/// Title, optional subtitle and a close button for the content of a native sheet. The system draws
/// the handle and the corner radius (`presentationDetents`, `presentationDragIndicator`).
struct SheetHeader: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    let closeLabel: LocalizedStringKey
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.row) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(Typography.title)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle).font(Typography.meta).foregroundStyle(Palette.ink2)
                }
            }
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(icon: .close)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                    .background(Palette.sunken, in: Circle())
            }
            .accessibilityLabel(closeLabel)
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.top, Spacing.md)
    }
}
