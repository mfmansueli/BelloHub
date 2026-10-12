//
//  AlertsContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of the Alerts tab: the permission strip, requests, what her clients sent, the records still owed (each one
/// opens the visit form), and the cards about her next visit and the clients to reach. Empty, loading and error states
/// are `ScreenStateView`'s.
struct AlertsContentView: View {
    @State private var viewModel: AlertsViewModel
    @State private var agendaSheet: AgendaSheet?
    @State private var visitFlow: TreatmentFlowRequest?
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
        .treatmentFlow(item: $visitFlow)
    }

    // MARK: - Sections

    private func sections(_ list: AlertsList, inbox: InboxAlerts, now: Date) -> some View {
        let mailbox = viewModel.mailboxAlerts
        let count = viewModel.reachOutCount(now: now)
        let records = viewModel.records(now: now)
        // A request that is answered, a check-in that is handled: the card leaves where she can see it. The first
        // list and a load never animate (`motionRows`).
        return VStack(alignment: .leading, spacing: Spacing.row) {
            if !inbox.isEmpty { inboxSection(inbox) }
            if !mailbox.isEmpty {
                MailboxAlertCards(
                    alerts: mailbox, onResolve: viewModel.resolve, onImportsSeen: viewModel.markImportsSeen
                )
            }
            if !records.isEmpty {
                RecordPendingAlertCards(
                    pending: records, clientNames: viewModel.clientNames, formatters: formatters, now: now,
                    onOpen: { visitFlow = $0.flowRequest }
                )
            }
            if let visit = list.upcomingVisit {
                SectionHeader(title: "alerts.section.comingUp").motionRow()
                upcomingCard(visit).motionRow()
            }
            if count > 0 {
                SectionHeader(title: "alerts.section.reachOut").motionRow()
                reachOutCard(count).motionRow()
            }
        }
        .motionRows(ids: AlertBlockIDs.make(
            list: list, inbox: inbox, mailbox: mailbox, records: records, reachOut: count
        ))
    }

    // MARK: - Inbox (S8)

    @ViewBuilder
    private func inboxSection(_ inbox: InboxAlerts) -> some View {
        SectionHeader(title: "alerts.section.requests").motionRow()
        ForEach(inbox.bookingRequests) { booking in requestCard(booking).motionRow() }
        ForEach(inbox.reschedules) { request in rescheduleCard(request).motionRow() }
        if inbox.waitingCount > 0 { waitlistCard(inbox).motionRow() }
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

    /// "Thursday, October 15, 10:00" in the business time zone. The time is not wrapped in a left-to-right isolate:
    /// digits and the colon already stay together in right-to-left text, and the invisible marks made the
    /// accessibility audit measure the line as clipped (pt-BR).
    private func whenText(_ date: Date) -> String {
        "\(formatters.weekdayDayMonth(date)), \(formatters.time(date))"
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

    /// One card for the whole follow-up queue: reminders, visits to close, check-ins, returns, clients not back and
    /// birthdays are listed there, once.
    private func reachOutCard(_ count: Int) -> some View {
        let counted = BidiIsolate.wrap(profile.clientTerm.countText(count, in: locale))
        return AlertCard(
            icon: .repeatArrows, tone: .peach, title: Text("home.reachOut.title"),
            message: Text(LocalizedStringResource(
                "alerts.reachOut.message", defaultValue: "Waiting for a message or a decision: \(counted)"
            ).localized(in: locale)),
            identifier: "alerts.reachOut"
        ) {
            NavigationLink(value: AgendaRoute.followUps(.all)) { Text("home.reachOut.open") }
                .buttonStyle(.belloSecondary)
                .accessibilityIdentifier("alerts.reachOut.action")
        }
    }
}
