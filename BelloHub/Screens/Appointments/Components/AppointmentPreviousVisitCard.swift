//
//  AppointmentPreviousVisitCard.swift
//  BelloHub
//

import SwiftUI

/// The client's last visit before this appointment, as its card: what was done and its photos. Tapping opens it.
struct AppointmentPreviousVisitCard: View {
    let visit: VisitSummary
    let formatters: Formatters
    let now: Date
    let loadThumbnail: (Photo) async -> Data?
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("clientRecord.history.last")
                .font(Typography.metaStrong)
                .foregroundStyle(Palette.ink2)
                .accessibilityAddTraits(.isHeader)
            VisitTimelineCard(visit: visit, formatters: formatters, now: now, loadThumbnail: loadThumbnail,
                              onOpen: onOpen)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appointment.previousVisit")
    }
}
