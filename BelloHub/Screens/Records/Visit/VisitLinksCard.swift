//
//  VisitLinksCard.swift
//  BelloHub
//

import SwiftUI

/// What is tied to this visit by link: incidents noted for it and documents she attached to it. An incident can also
/// be noted from here, already tied to this visit.
struct VisitLinksCard: View {
    let incidents: [Incident]
    let documents: [ConsentRecord]
    let formatters: Formatters
    let onReportIncident: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("visitDetail.incidents")
                .font(Typography.section)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            if incidents.isEmpty {
                Text("visitDetail.incidents.empty")
                    .font(Typography.meta)
                    .foregroundStyle(Palette.ink2)
            } else {
                VStack(spacing: 0) {
                    ForEach(incidents) { incident in IncidentRow(incident: incident, formatters: formatters) }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                        .strokeBorder(Palette.hairline, lineWidth: 1)
                }
            }
            Button(action: onReportIncident) {
                Label { Text("visitDetail.incidents.add") } icon: { Image(icon: .alert) }
            }
            .buttonStyle(.belloChip(selected: false))
            .accessibilityIdentifier("visitDetail.reportIncident")
            if !documents.isEmpty {
                Text("visitDetail.documents")
                    .font(Typography.section)
                    .foregroundStyle(Palette.ink)
                    .padding(.top, Spacing.sm)
                    .accessibilityAddTraits(.isHeader)
                ForEach(documents) { document in documentRow(document) }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .belloCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("visitDetail.links")
    }

    private func documentRow(_ document: ConsentRecord) -> some View {
        HStack(spacing: Spacing.row) {
            Image(icon: document.document == nil ? .document : .paperclip)
                .foregroundStyle(Palette.ink2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: document.displayLabel(kindTitle: document.kind.title.resolved(in: locale)))
                    .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Text(verbatim: formatters.shortDate(document.effectiveDate))
                    .font(Typography.meta).foregroundStyle(Palette.ink2)
            }
            Spacer(minLength: Spacing.sm)
            if document.isSigned {
                StatusChip(label: "health.consent.status.signed", style: StatusPalette.confirmed)
            } else {
                StatusChip(label: "health.consent.status.notSigned", style: StatusPalette.pending)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("visitDetail.document.\(document.id.uuidString)")
    }
}
