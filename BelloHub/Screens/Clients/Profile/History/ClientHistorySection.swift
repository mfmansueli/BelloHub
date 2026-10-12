//
//  ClientHistorySection.swift
//  BelloHub
//

import SwiftUI

/// "History", open by default: the last visit on top, then every visit, pending record and booking that did not
/// happen, newest first. Photos with no visit wait in their own card with a way to organize them.
struct ClientHistorySection: View {
    let timeline: ClientTimeline
    let formatters: Formatters
    let now: Date
    let loadThumbnail: (Photo) async -> Data?
    let onOpenVisit: (VisitSummary) -> Void
    let onFillPending: (Appointment) -> Void
    let onOrganizePhotos: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if timeline.entries.isEmpty, timeline.unlinkedPhotos.isEmpty {
                EmptyState(
                    icon: .document, title: "clientRecord.history.empty.title",
                    message: "clientRecord.history.empty.message"
                )
                .accessibilityIdentifier("clientRecord.history.empty")
            }
            if let last = timeline.lastVisit {
                Text("clientRecord.history.last")
                    .font(Typography.metaStrong)
                    .foregroundStyle(Palette.ink2)
                    .accessibilityAddTraits(.isHeader)
                VisitTimelineCard(
                    visit: last, formatters: formatters, now: now, isHighlighted: true,
                    loadThumbnail: loadThumbnail, onOpen: { onOpenVisit(last) }
                )
            }
            if !timeline.unlinkedPhotos.isEmpty {
                UnlinkedPhotosCard(photos: timeline.unlinkedPhotos, loadThumbnail: loadThumbnail,
                                   onOrganize: onOrganizePhotos)
            }
            if !rest.isEmpty {
                Text("clientRecord.history.timeline")
                    .font(Typography.metaStrong)
                    .foregroundStyle(Palette.ink2)
                    .padding(.top, Spacing.sm)
                    .accessibilityAddTraits(.isHeader)
                LazyVStack(alignment: .leading, spacing: Spacing.row) {
                    ForEach(rest) { entry in row(entry) }
                }
            }
        }
        .accessibilityIdentifier("clientRecord.history")
    }

    /// Every line but the last visit, which is already on top.
    private var rest: [ClientTimelineEntry] {
        guard let last = timeline.lastVisit else { return timeline.entries }
        let lastID = ClientTimelineEntry.visit(last).id
        return timeline.entries.filter { $0.id != lastID }
    }

    @ViewBuilder
    private func row(_ entry: ClientTimelineEntry) -> some View {
        switch entry {
        case .visit(let visit):
            VisitTimelineCard(visit: visit, formatters: formatters, now: now, loadThumbnail: loadThumbnail,
                              onOpen: { onOpenVisit(visit) })
        case .pendingRecord(let appointment):
            TimelineBookingRow(appointment: appointment, formatters: formatters, now: now,
                               onRecord: { onFillPending(appointment) })
        case .notHeld(let appointment):
            TimelineBookingRow(appointment: appointment, formatters: formatters, now: now)
        case .incident(let incident):
            IncidentRow(incident: incident, formatters: formatters)
                .belloCard(cornerRadius: Radius.tile)
        }
    }
}
