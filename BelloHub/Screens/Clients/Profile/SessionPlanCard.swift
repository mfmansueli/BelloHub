//
//  SessionPlanCard.swift
//  BelloHub
//

import SwiftUI

/// Where she is in a series of sessions ("Skin barrier repair, session 3 of 6, every 4 weeks"). Informational: the
/// session plan screen (4.8) is the calendar stage's, so there is no chevron and no tap until it exists.
struct SessionPlanCard: View {
    let plan: ClientProfileSnapshot.ActivePlan
    let formatters: Formatters
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: Spacing.row) {
            Image(icon: .repeatArrows)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Palette.sageText)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: plan.plan.name)
                    .font(Typography.bodyStrong)
                Text(progress)
                    .font(Typography.meta)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Palette.sageText)
        .padding(Spacing.md)
        .background(Palette.sageWash, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("clientProfile.plan")
    }

    private var progress: LocalizedStringResource {
        let session = plan.progress.currentSessionNumber ?? plan.progress.totalSessions
        let total = plan.progress.totalSessions
        let every = formatters.weeks(plan.plan.intervalWeeks)
        return LocalizedStringResource(
            "clientProfile.plan.progress", defaultValue: "Session \(session) of \(total) · every \(every)"
        ).localized(in: locale)
    }
}
