//
//  VisitSummaryRow.swift
//  BelloHub
//

import SwiftUI

/// The client and the visit in one line, at the top of the sheets: avatar, name, and "Service · when".
struct VisitSummaryRow: View {
    let visit: VisitContext
    let formatters: Formatters
    let now: Date
    var identifier = "visitSummary"
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: Spacing.row) {
            Avatar(name: visit.client.name, id: visit.client.id.uuidString, size: 52)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: visit.client.name)
                    .font(Typography.subtitle)
                    .foregroundStyle(Palette.ink)
                Text(verbatim: subtitle)
                    .font(Typography.meta)
                    .foregroundStyle(Palette.ink2)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private var subtitle: String {
        let when = formatters.visitWhen(
            visit.appointment, now: now, today: LocalizedStringResource("appointment.today").resolved(in: locale),
            tomorrow: LocalizedStringResource("appointment.tomorrow").resolved(in: locale)
        )
        return "\(visit.appointment.serviceName) · \(when)"
    }
}
