//
//  HomeNextVisitCard.swift
//  BelloHub
//

import SwiftUI

/// The one hero card of Home: the visit that is happening or comes next, with the time, who and what, the status, and
/// the three things she does next: review what matters before she starts, open the visit, tell the client she is late.
struct HomeNextVisitCard: View {
    let digest: AgendaDigest
    let visit: AgendaDigest.Visit
    let formatters: Formatters
    let onBeforeYouStart: () -> Void
    let onRunningLate: () -> Void
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize

    private var appointment: Appointment { visit.appointment }
    private var clientName: String { visit.clientName }
    private var firstName: String { visit.client?.firstName ?? clientName }

    var body: some View {
        HeroCard(isAnimated: true) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                header
                clientRow
                AppointmentStatusChip(status: appointment.status)
                actions
                if appointment.status.holdsTime, visit.client != nil {
                    Button(action: onRunningLate) {
                        Text(LocalizedStringResource(
                            "home.next.runningLate", defaultValue: "Running late? Tell \(firstName)"
                        ).localized(in: locale))
                            .font(Typography.metaStrong)
                            .foregroundStyle(HeroPalette.ink)
                            .frame(maxWidth: .infinity, minHeight: Spacing.touchTarget)
                    }
                    .accessibilityIdentifier("home.next.runningLate")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.next")
    }

    // MARK: - Parts

    private var header: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.sm))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Spacing.sm))
        return layout {
            HStack(spacing: Spacing.sm) {
                Circle().fill(HeroPalette.glowRose).frame(width: 8, height: 8).accessibilityHidden(true)
                label
                    .font(Typography.metaStrong)
                    .foregroundStyle(HeroPalette.ink2)
                    .motionNumber(digest.minutesUntilNext, countsDown: true)
            }
            Spacer(minLength: Spacing.sm)
            Text(verbatim: formatters.time(appointment.startsAt))
                .font(Typography.title)
                .foregroundStyle(HeroPalette.ink)
                .motionNumber(appointment.startsAt)
                .accessibilityIdentifier("home.next.time")
        }
    }

    private var label: Text {
        if digest.nextIsInProgress { return Text("home.next.now") }
        if digest.nextIsToday {
            let wait = formatters.duration(minutes: digest.minutesUntilNext)
            return Text(LocalizedStringResource("home.next.in", defaultValue: "Next up · in \(wait)")
                .localized(in: locale))
        }
        let day = formatters.weekdayDayMonth(appointment.startsAt)
        return Text(LocalizedStringResource("home.next.on", defaultValue: "Next up · \(day)").localized(in: locale))
    }

    private var clientRow: some View {
        HStack(spacing: Spacing.row) {
            Avatar(name: clientName, id: appointment.clientID.uuidString, size: 56)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: clientName)
                    .font(Typography.subtitle)
                    .foregroundStyle(HeroPalette.ink)
                    .accessibilityIdentifier("home.next.client")
                Text(verbatim: "\(appointment.serviceName) · \(formatters.minutes(appointment.totalMinutes))")
                    .font(Typography.meta)
                    .foregroundStyle(HeroPalette.ink2)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        FittingRow(fillsWidth: true) {
            Button(action: onBeforeYouStart) { Text("beforeYouStart.title") }
                .buttonStyle(.belloOnHero)
                .accessibilityIdentifier("home.next.beforeYouStart")
            NavigationLink(value: AgendaRoute.appointment(id: appointment.id)) { Text("home.next.open") }
                .buttonStyle(.belloOnHero)
                .accessibilityIdentifier("home.next.open")
        }
    }
}
