//
//  AlertsContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of the Alerts tab: the permission strip, the reminders ready to send, and the cards about her next visit,
/// birthdays and the clients to reach. Empty, loading and error states are `ScreenStateView`'s.
struct AlertsContentView: View {
    @State private var viewModel: AlertsViewModel
    @State private var agendaSheet: AgendaSheet?
    @Environment(ProfileService.self) private var profile
    @Environment(\.locale) private var locale

    init(viewModel: AlertsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var formatters: Formatters { viewModel.settings.formatters(locale: locale) }

    var body: some View {
        ScrollView {
            TimelineView(.everyMinute) { context in
                VStack(alignment: .leading, spacing: Spacing.row) {
                    Text("alerts.subtitle")
                        .font(Typography.body).foregroundStyle(Palette.ink2)
                        .accessibilityIdentifier("alerts.subtitle")
                    NotificationPermissionNotice(
                        notice: viewModel.notice, onTurnOn: viewModel.turnOnNotifications,
                        onOpenSettings: viewModel.openSettings
                    )
                    ScreenStateView(
                        phase: viewModel.phase(now: context.date), prefix: "alerts", retry: viewModel.retry
                    ) {
                        EmptyState(icon: .bell, title: "alerts.empty.title", message: "alerts.empty.message")
                            .accessibilityIdentifier("alerts.empty")
                    } content: {
                        sections(
                            viewModel.list(now: context.date), inbox: viewModel.inboxAlerts(now: context.date),
                            now: context.date
                        )
                    }
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.bottom, Spacing.lg)
        }
        .background(Palette.bg)
        .navigationTitle(Text("main.tab.alerts"))
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await viewModel.refreshAsync() }
        .task { viewModel.start() }
        .agendaSheet(item: $agendaSheet)
    }

    // MARK: - Sections

    @ViewBuilder
    private func sections(_ list: AlertsList, inbox: InboxAlerts, now: Date) -> some View {
        if !inbox.isEmpty { inboxSection(inbox) }
        if !list.remindersReady.isEmpty {
            SectionHeader(title: "alerts.section.reminders")
            RemindersReadyCard(items: list.remindersReady, formatters: formatters) { item in
                agendaSheet = .message(appointmentID: item.appointment.id)
            }
        }
        if list.upcomingVisit != nil || !list.birthdays.isEmpty {
            SectionHeader(title: "alerts.section.comingUp")
            if let visit = list.upcomingVisit { upcomingCard(visit) }
            if !list.birthdays.isEmpty { birthdaysCard(list.birthdays) }
        }
        if list.followUpCount > 0 || list.winBackCount > 0 {
            SectionHeader(title: "alerts.section.reachOut")
            if list.followUpCount > 0 { followUpsCard(list.followUpCount) }
            if list.winBackCount > 0 { winBackCard(list.winBackCount) }
        }
    }

    // MARK: - Inbox (S8)

    @ViewBuilder
    private func inboxSection(_ inbox: InboxAlerts) -> some View {
        SectionHeader(title: "alerts.section.requests")
        ForEach(inbox.bookingRequests) { booking in requestCard(booking) }
        ForEach(inbox.reschedules) { request in rescheduleCard(request) }
        if inbox.waitingCount > 0 { waitlistCard(inbox) }
    }

    private func requestCard(_ booking: IncomingBooking) -> some View {
        let who = BidiIsolate.wrap(booking.client.name)
        let when = whenText(booking.startsAt)
        return AlertCard(
            icon: .calendar, tone: booking.pendingReason == .noShowLimit ? .rose : .sage,
            title: Text("alerts.request.title"),
            message: Text(LocalizedStringResource(
                "alerts.request.message", defaultValue: "\(who) asks for \(when)."
            ).localized(in: locale)),
            identifier: "alerts.request.\(booking.id)"
        ) {
            NavigationLink(value: AgendaRoute.bookingRequest(id: booking.id)) { Text("alerts.request.action") }
                .buttonStyle(.belloSecondary)
                .accessibilityIdentifier("alerts.request.\(booking.id).action")
        }
    }

    private func rescheduleCard(_ request: RescheduleRequest) -> some View {
        let who = BidiIsolate.wrap(request.clientName)
        let when = whenText(request.requestedStart)
        return AlertCard(
            icon: .repeatArrows, tone: .peach, title: Text("alerts.reschedule.title"),
            message: Text(LocalizedStringResource(
                "alerts.reschedule.message", defaultValue: "\(who) asks to move a visit to \(when)."
            ).localized(in: locale)),
            identifier: "alerts.reschedule.\(request.id)"
        ) {
            NavigationLink(value: AgendaRoute.rescheduleRequest(id: request.id)) { Text("alerts.request.action") }
                .buttonStyle(.belloSecondary)
                .accessibilityIdentifier("alerts.reschedule.\(request.id).action")
        }
    }

    private func waitlistCard(_ inbox: InboxAlerts) -> some View {
        AlertCard(
            icon: .clock, tone: .sage,
            title: Text(inbox.hasOpenTime ? "alerts.waitlist.openTitle" : "alerts.waitlist.title"),
            message: Text(LocalizedStringResource(
                "alerts.waitlist.message", defaultValue: "People waiting: \(inbox.waitingCount)"
            ).localized(in: locale)),
            identifier: "alerts.waitlist"
        ) {
            NavigationLink(value: AgendaRoute.waitlist) { Text("alerts.waitlist.action") }
                .buttonStyle(.belloSecondary)
                .accessibilityIdentifier("alerts.waitlist.action")
        }
    }

    /// "Thursday, October 15, 10:00" in the business time zone.
    private func whenText(_ date: Date) -> String {
        "\(formatters.weekdayDayMonth(date)), \(BidiIsolate.wrapLeftToRight(formatters.time(date)))"
    }

    private func upcomingCard(_ visit: AgendaDigest.Visit) -> some View {
        let who = BidiIsolate.wrap(visit.client?.name ?? "")
        let time = BidiIsolate.wrapLeftToRight(formatters.time(visit.appointment.startsAt))
        return AlertCard(
            icon: .clock, tone: .sage, title: Text("alerts.upcoming.title"),
            message: Text(LocalizedStringResource(
                "alerts.upcoming.message",
                defaultValue: "\(who) at \(time). Review what matters before you start."
            ).localized(in: locale)),
            identifier: "alerts.upcoming"
        ) {
            Button { agendaSheet = .beforeYouStart(appointmentID: visit.appointment.id) } label: {
                Text("beforeYouStart.title")
            }
            .buttonStyle(.belloSecondary)
            .accessibilityIdentifier("alerts.upcoming.beforeYouStart")
        }
    }

    private func birthdaysCard(_ birthdays: [AlertsList.Birthday]) -> some View {
        let items = birthdays.map { birthday -> String in
            let when = birthday.upcoming.isToday
                ? String(localized: "appointment.today", locale: locale)
                : formatters.weekdayDayMonth(birthday.upcoming.date)
            return "\(BidiIsolate.wrap(birthday.client.name)) (\(when))"
        }
        return AlertCard(
            icon: .gift, tone: .rose, title: Text("alerts.birthdays.title"),
            message: Text(verbatim: formatters.list(items)),
            identifier: "alerts.birthdays"
        ) {
            NavigationLink(value: AgendaRoute.followUps) { Text("alerts.birthdays.action") }
                .buttonStyle(.belloSecondary)
                .accessibilityIdentifier("alerts.birthdays.action")
        }
    }

    private func followUpsCard(_ count: Int) -> some View {
        let noun = BidiIsolate.wrap(count == 1
            ? profile.clientTerm.singularText(in: locale) : profile.clientTerm.pluralText(in: locale))
        return AlertCard(
            icon: .repeatArrows, tone: .peach, title: Text("alerts.followUps.title"),
            message: Text(LocalizedStringResource(
                "alerts.followUps.message", defaultValue: "\(count) \(noun) are ready for a follow-up."
            ).localized(in: locale)),
            identifier: "alerts.followUps"
        ) {
            NavigationLink(value: AgendaRoute.followUps) { Text("home.followUps.view") }
                .buttonStyle(.belloSecondary)
                .accessibilityIdentifier("alerts.followUps.action")
        }
    }

    private func winBackCard(_ count: Int) -> some View {
        let noun = count == 1 ? profile.clientTerm.singularText(in: locale) : profile.clientTerm.pluralText(in: locale)
        return AlertCard(
            icon: .clients, tone: .rose, title: Text("alerts.winBack.title"),
            message: Text(LocalizedStringResource(
                "clients.winBack", defaultValue: "\(count) \(BidiIsolate.wrap(noun)) have not been back in 2+ months"
            ).localized(in: locale)),
            identifier: "alerts.winBack"
        ) {
            NavigationLink(value: AgendaRoute.winBack) { Text("alerts.winBack.action") }
                .buttonStyle(.belloSecondary)
                .accessibilityIdentifier("alerts.winBack.action")
        }
    }
}
