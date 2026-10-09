//
//  CredentialsPreviewSheet.swift
//  BelloHub
//

import SwiftUI

/// "See how it looks to clients": what her booking page shows under Training and credentials, in a sheet. When the page
/// switch is off it says so instead of showing what clients cannot see. Read-only.
struct CredentialsPreviewSheet: View {
    let trainings: [Credential]
    let registration: Credential?
    let showsOnPage: Bool
    /// "Senac SP · 2019", in her language.
    let details: (Credential) -> String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if !showsOnPage {
                        InlineNotice(style: .info, title: "credentials.preview.hidden")
                            .accessibilityIdentifier("credentialsPreview.hidden")
                    } else if trainings.isEmpty && registration == nil {
                        InlineNotice(style: .info, title: "credentials.preview.empty")
                            .accessibilityIdentifier("credentialsPreview.empty")
                    } else {
                        pageCard
                    }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.vertical, Spacing.md)
            }
            .background(Palette.bg)
            .navigationTitle(Text("credentials.preview.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("credentials.preview.done") }
                        .accessibilityIdentifier("credentialsPreview.doneButton")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Palette.bg)
    }

    /// The card the booking page draws: a heading, each course, then the registration.
    private var pageCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("credentials.title").font(Typography.section).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            ForEach(trainings) { credential in
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: credential.title).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    let line = details(credential)
                    if !line.isEmpty {
                        Text(verbatim: line).font(Typography.meta).foregroundStyle(Palette.ink2)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            if let number = registration?.registrationNumber {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("credentials.registration.title").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    Text(verbatim: number).font(Typography.meta).foregroundStyle(Palette.ink2)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .belloCard()
        .accessibilityIdentifier("credentialsPreview.card")
    }
}
