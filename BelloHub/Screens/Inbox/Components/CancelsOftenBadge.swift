//
//  CancelsOftenBadge.swift
//  BelloHub
//

import SwiftUI

/// "Cancels often" next to someone asking through her link (2.9, 2.10), the same words and coral dot as the client list
/// (`ClientRow`), so she recognizes it. Private to her: clients never see it (product rule 4).
struct CancelsOftenBadge: View {
    let identifier: String

    var body: some View {
        HStack(spacing: Spacing.xs + Spacing.xxs) {
            Circle().fill(Palette.coralText).frame(width: 6, height: 6).accessibilityHidden(true)
            Text("clients.badge.cancelsOften").font(Typography.footnoteStrong).foregroundStyle(Palette.coralText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}
