//
//  LegalNoticeSheet.swift
//  BelloHub
//

import SwiftUI

/// The terms or the privacy policy, read in a sheet. Operator fields still pending (H17) are shown the way the
/// consent screens show them (`LegalTextRenderer.forThisBuild`); the word "draft" never appears.
struct LegalNoticeSheet: View {
    let text: LegalNoticeText

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(LegalTextRenderer.attributed(LegalTextRenderer.fill(
                    text.body, values: LegalTextValues(), pending: LegalTextRenderer.forThisBuild
                )))
                .font(Typography.body)
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.gutter)
                .accessibilityIdentifier("legalNotice.body")
            }
            .background(Palette.bg)
            .navigationTitle(Text(text.notice.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("common.close") }
                        .accessibilityIdentifier("legalNotice.closeButton")
                }
            }
        }
        .presentationBackground(Palette.bg)
    }
}
