//
//  CredentialRow.swift
//  BelloHub
//

import SwiftUI

/// One course or certificate in the list: its title and, under it, the institution and year. One element for VoiceOver.
struct CredentialRow: View {
    let credential: Credential
    /// "Senac SP · 2019", already written in her language; empty when there is neither.
    let details: String

    var body: some View {
        HStack(spacing: Spacing.row) {
            Image(icon: .star)
                .foregroundStyle(Palette.roseDeepText)
                .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                .background(Palette.roseWash, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: credential.title).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                if !details.isEmpty {
                    Text(verbatim: details).font(Typography.meta).foregroundStyle(Palette.ink2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
