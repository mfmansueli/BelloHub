//
//  HomeContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of Home (2.1, routine-a item 4). "New appointment" sits in the navigation bar, so it is one tap away on
/// every day without scrolling. Then the next visit (or the clear day), today's pending items, the rest of today, one
/// secondary card for everyone to reach out to, and the week. The digest is rebuilt every minute (`TimelineView`), so
/// "in 1 h 20 min" and the visits that have already passed stay true while the screen is open. Empty, loading and
/// error states are `ScreenStateView`'s.
struct HomeContentView: View {
    @State private var viewModel: HomeViewModel
    private let settings: CalendarSettings

    @State private var agendaSheet: AgendaSheet?
    @Environment(ProfileService.self) private var profile
    @Environment(MainNavigation.self) private var navigation: MainNavigation?
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize

    init(viewModel: HomeViewModel, settings: CalendarSettings) {
        _viewModel = State(initialValue: viewModel)
        self.settings = settings
    }

    private var formatters: Formatters { settings.formatters(locale: locale) }

    var body: some View {
        ScrollView {
            TimelineView(.everyMinute) { context in
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header(now: context.date)
                    // The iPhone's zone differs from the business zone: say so before the day (tz-mismatch-notice).
                    TimeZoneNoticeView(placement: .card, formatters: formatters, now: context.date)
                    ScreenStateView(phase: viewModel.phase, prefix: "home", rows: 3, retry: viewModel.retry) {
                        EmptyView()
                    } content: {
                        sections(viewModel.digest(now: context.date), now: context.date)
                    }
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.lg)
        }
        .background(Palette.bg)
        .navigationTitle(Text("home.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { agendaSheet = .newAppointment(clientID: nil, startsAt: nil) } label: {
                    Label { Text("home.quick.newAppointment") } icon: { Image(icon: .plus) }
                        .labelStyle(.titleAndIcon)
                }
                .accessibilityIdentifier("home.quick.newAppointment")
            }
        }
        .refreshable { await viewModel.refreshAsync() }
        .task { viewModel.start() }
        .agendaSheet(item: $agendaSheet)
    }

    // MARK: - Header

    private func header(now: Date) -> some View {
        HStack(alignment: .top, spacing: Spacing.row) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                greeting(now: now)
                    .font(Typography.screenTitle)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("home.greeting")
                Text(verbatim: formatters.weekdayDayMonth(now))
                    .font(Typography.body)
                    .foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("home.date")
            }
            Spacer(minLength: Spacing.sm)
            if let person = profile.profile, !typeSize.isAccessibilitySize {
                Avatar(name: person.displayName, id: person.id.uuidString, size: 48)
            }
        }
    }

    private func greeting(now: Date) -> Text {
        let name = profile.profile?.firstName ?? ""
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = settings.timeZone
        switch DayGreeting.at(now, calendar: calendar) {
        case .morning:
            return Text(LocalizedStringResource("home.greeting.morning", defaultValue: "Good morning, \(name)")
                .localized(in: locale))
        case .afternoon:
            return Text(LocalizedStringResource("home.greeting.afternoon", defaultValue: "Good afternoon, \(name)")
                .localized(in: locale))
        case .evening:
            return Text(LocalizedStringResource("home.greeting.evening", defaultValue: "Good evening, \(name)")
                .localized(in: locale))
        }
    }

    // MARK: - Sections

    /// A clear day leads with the empty state and keeps the pending items and the queue right under it; a busy day
    /// leads with the next visit, today's pending items and the agenda, and the queue waits below.
    @ViewBuilder
    private func sections(_ digest: AgendaDigest, now: Date) -> some View {
        let pending = viewModel.pending(digest: digest, now: now)
        let reachOut = viewModel.reachOut(now: now)
        // One container for the blocks that come and go, so a visit that is confirmed, moved or cancelled enters or
        // leaves where she can see it (docs/09-MOTION.md section 3.10). The loading and the first list never animate.
        VStack(alignment: .leading, spacing: Spacing.lg) {
            if digest.isDayClear {
                EmptyState(icon: .calendar, title: "home.empty.title", message: "home.empty.message")
                    .accessibilityIdentifier("home.empty")
                    .motionRow()
            } else if let next = digest.nextVisit {
                HomeNextVisitCard(
                    digest: digest, visit: next, formatters: formatters,
                    onBeforeYouStart: { agendaSheet = .beforeYouStart(appointmentID: next.appointment.id) },
                    onRunningLate: { agendaSheet = .runningLate(appointmentID: next.appointment.id) }
                )
                .motionRow()
            }
            if !pending.isEmpty {
                HomeTodayCard(
                    pending: pending, formatters: formatters,
                    onBookingRequests: { navigation?.selection = .alerts },
                    onTurnOnNotifications: viewModel.turnOnNotifications
                )
                .motionRow()
            }
            if !digest.restOfToday.isEmpty { restOfToday(digest).motionRow() }
            if !reachOut.isEmpty { HomeReachOutCard(reachOut: reachOut, formatters: formatters).motionRow() }
            weekRow(digest)
        }
        .motionRows(ids: HomeBlockIDs.make(digest: digest, pending: pending, reachOut: reachOut))
    }

    private func restOfToday(_ digest: AgendaDigest) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("home.rest.title")
                    .font(Typography.section).foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Spacing.row)
                Text(LocalizedStringResource("home.rest.left", defaultValue: "\(restLeft(digest)) left")
                    .localized(in: locale))
                    .font(Typography.metaStrong).foregroundStyle(Palette.roseDeepText)
                    .motionNumber(restLeft(digest))
                    .accessibilityIdentifier("home.rest.left")
            }
            .padding(.bottom, Spacing.row)
            ListCard(dividerInset: 76) {
                ForEach(digest.restOfToday) { visit in
                    HomeVisitRow(visit: visit, formatters: formatters).motionRow()
                }
            }
        }
    }

    /// How many of the other visits of today still wait (the next one is on the hero card).
    private func restLeft(_ digest: AgendaDigest) -> Int {
        digest.restOfToday.filter { $0.appointment.status.holdsTime }.count
    }

    /// The week in one row: its open slots, and the way into Week at a glance (the tiles that repeated the agenda and
    /// the queue are gone).
    private func weekRow(_ digest: AgendaDigest) -> some View {
        ListCard(dividerInset: 72) {
            NavigationLink(value: AgendaRoute.weekGlance) {
                HomeCountRow(
                    icon: .calendar, tone: .sage, title: Text("home.quick.weekGlance"),
                    subtitle: Text("weekGlance.tile.openSlots"), count: formatters.number(digest.week.openSlotCount)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.quick.weekGlance")
        }
    }
}
