//
//  KnowledgeSummaryCard.swift
//  BelloHub
//

import SwiftUI

/// "Client knowledge" on the profile: what she wrote about this client in three short lists, as quiet chips. With
/// nothing written it says so and offers the way in. Editing is a separate screen (`ClientKnowledgeView`).
struct KnowledgeSummaryCard: View {
    let client: Client

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if hasAnything {
                ForEach(KnowledgeSection.allCases) { section in
                    let entries = section.entries(of: client)
                    if !entries.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text(section.title)
                                .font(Typography.footnoteStrong)
                                .foregroundStyle(Palette.ink2)
                            FlowLayout {
                                ForEach(entries, id: \.self) { entry in chip(entry, section: section) }
                            }
                        }
                    }
                }
            } else {
                Text("clientProfile.knowledge.empty")
                    .font(Typography.meta)
                    .foregroundStyle(Palette.ink2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .belloCard(cornerRadius: Radius.tileSmall)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("clientProfile.knowledge")
    }

    private var hasAnything: Bool {
        KnowledgeSection.allCases.contains { !$0.entries(of: client).isEmpty }
    }

    /// Sensitivities are the ones to be careful about, so they take the rose wash; the rest are quiet.
    private func chip(_ entry: String, section: KnowledgeSection) -> some View {
        let isSensitivity = section == .sensitivities
        return Text(verbatim: entry)
            .font(Typography.meta)
            .foregroundStyle(isSensitivity ? Palette.roseDeepText : Palette.ink)
            .padding(.horizontal, Spacing.row)
            .frame(minHeight: 32)
            .background(isSensitivity ? Palette.roseWash : Palette.sunken, in: Capsule())
    }
}
