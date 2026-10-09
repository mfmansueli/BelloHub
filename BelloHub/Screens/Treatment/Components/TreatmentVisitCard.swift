//
//  TreatmentVisitCard.swift
//  BelloHub
//

import SwiftUI

/// Who the record is for and which visit it documents: avatar, name, "service · date". One combined element for
/// VoiceOver.
struct TreatmentVisitCard: View {
    let name: String
    let id: UUID
    let subtitle: String

    var body: some View {
        HStack(spacing: Spacing.row) {
            Avatar(name: name, id: id.uuidString, size: 48)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: name).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Text(verbatim: subtitle).font(Typography.meta).foregroundStyle(Palette.ink2)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .belloCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("treatmentFlow.visitCard")
    }
}

#Preview {
    TreatmentVisitCard(name: "Ana Costa", id: UUID(), subtitle: "Brazilian Glow · Sep 30, 15:00")
        .padding()
        .background(Palette.bg)
}
