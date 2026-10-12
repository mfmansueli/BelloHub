//
//  VisitTimelineCard.swift
//  BelloHub
//

import SwiftUI

/// One visit on the client's timeline: the day it happened, the service, a short summary, its photos and, when it
/// matters, the record's state. The edit history is not here: it lives at the end of the visit's details, so the
/// card tells what happened to the client and not to the record. Tapping opens the details.
struct VisitTimelineCard: View {
    let visit: VisitSummary
    let formatters: Formatters
    let now: Date
    /// The newest visit, on top: a stronger card.
    var isHighlighted = false
    let loadThumbnail: (Photo) async -> Data?
    let onOpen: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    Text(verbatim: VisitDateLabel.text(visit.visitDate, formatters: formatters, now: now,
                                                       locale: locale))
                        .font(Typography.footnoteStrong)
                        .foregroundStyle(Palette.ink2)
                    Spacer(minLength: Spacing.sm)
                    VisitStateChip(state: visit.state)
                }
                Text(verbatim: visit.record.serviceName)
                    .font(isHighlighted ? Typography.section : Typography.bodyStrong)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                if let summary = visit.summary {
                    Text(verbatim: summary)
                        .font(Typography.meta)
                        .foregroundStyle(Palette.ink2)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                } else if visit.state == .draft {
                    Text("clientRecord.visit.draftEmpty")
                        .font(Typography.meta)
                        .foregroundStyle(Palette.ink2)
                }
                if !visit.photos.isEmpty {
                    VisitPhotoStrip(photos: visit.photos, size: isHighlighted ? 64 : 52, load: loadThumbnail)
                }
                if !visit.incidents.isEmpty {
                    Label {
                        Text(LocalizedStringResource(
                            "clientRecord.visit.incidents", defaultValue: "\(visit.incidents.count) incidents noted"
                        ).localized(in: locale))
                    } icon: {
                        Image(icon: .alert)
                    }
                    .font(Typography.footnoteStrong)
                    .foregroundStyle(Palette.coralText)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .belloCard(elevation: isHighlighted ? .e2 : .e1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(Text("clientRecord.visit.openHint"))
        .accessibilityIdentifier("clientRecord.visit.\(visit.id.uuidString)")
    }

    /// One sentence for VoiceOver: day, service, state, summary and how many photos.
    private var accessibilityText: Text {
        var parts = [VisitDateLabel.text(visit.visitDate, formatters: formatters, now: now, locale: locale),
                     visit.record.serviceName]
        if visit.state == .draft { parts.append(RecordStatus.draft.title.resolved(in: locale)) }
        if let summary = visit.summary { parts.append(summary) }
        if !visit.photos.isEmpty {
            parts.append(LocalizedStringResource(
                "clientRecord.visit.photoCount", defaultValue: "\(visit.photos.count) photos"
            ).resolved(in: locale))
        }
        return Text(verbatim: parts.joined(separator: ", "))
    }
}
