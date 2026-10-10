//
//  HomeContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of Home (2.1). The digest is rebuilt every minute (`TimelineView`), so "in 1 h 20 min" and the visits that
/// have already passed stay true while the screen is open. Empty, loading and error states are `ScreenStateView`'s.
struct HomeContentView: View {
    @State private var viewModel: HomeViewModel
    private let settings: CalendarSettings

    @State private var agendaSheet: AgendaSheet?
    @Environment(ProfileService.self) private var profile
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

    @ViewBuilder
    private func sections(_ digest: AgendaDigest, now: Date) -> some View {
        if digest.isDayClear {
            EmptyState(
                icon: .calendar, title: "home.empty.title", message: "home.empty.message",
                actionTitle: "home.empty.action"
            ) { agendaSheet = .newAppointment(clientID: nil, startsAt: nil) }
                .accessibilityIdentifier("home.empty")
        } else {
            if let next = digest.nextVisit {
                HomeNextVisitCard(
                    digest: digest, visit: next, formatters: formatters,
                    onBeforeYouStart: { agendaSheet = .beforeYouStart(appointmentID: next.appointment.id) },
                    onRunningLate: { agendaSheet = .runningLate(appointmentID: next.appointment.id) }
                )
            }
            if !digest.restOfToday.isEmpty { restOfToday(digest) }
        }
        if !digest.remindersReady.isEmpty { reminders(digest) }
        tiles(digest)
        if !digest.followUps.isEmpty { followUps(digest) }
        if !digest.winBack.isEmpty {
            HomeWinBackLink(counted: profile.clientTerm.countText(digest.winBack.count, in: locale))
        }
        quickActions(isDayClear: digest.isDayClear)
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
                    .accessibilityIdentifier("home.rest.left")
            }
            .padding(.bottom, Spacing.row)
            ListCard(dividerInset: 76) {
                ForEach(digest.restOfToday) { visit in HomeVisitRow(visit: visit, formatters: formatters) }
            }
        }
    }

    /// How many of the other visits of today still wait (the next one is on the hero card).
    private func restLeft(_ digest: AgendaDigest) -> Int {
        digest.restOfToday.filter { $0.appointment.status.holdsTime }.count
    }

    private func reminders(_ digest: AgendaDigest) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("home.reminders.title")
                .font(Typography.section).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, Spacing.xs)
            Text("home.reminders.subtitle")
                .font(Typography.meta).foregroundStyle(Palette.ink2)
                .padding(.bottom, Spacing.row)
            RemindersReadyCard(items: digest.remindersReady, formatters: formatters) { item in
                agendaSheet = .message(appointmentID: item.appointment.id)
            }
        }
    }

    private func tiles(_ digest: AgendaDigest) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: Spacing.row))
            : AnyLayout(HStackLayout(spacing: Spacing.row))
        return layout {
            InsightTile(icon: .clock, value: formatters.number(digest.leftToday),
                        label: "weekGlance.tile.leftToday", tone: .sage)
                .accessibilityIdentifier("home.tile.leftToday")
            NavigationLink(value: AgendaRoute.weekGlance) {
                InsightTile(icon: .calendar, value: formatters.number(digest.week.openSlotCount),
                            label: "weekGlance.tile.openSlots", tone: .peach)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.tile.openSlots")
            NavigationLink(value: AgendaRoute.winBack) {
                InsightTile(icon: .repeatArrows, value: formatters.number(digest.winBack.count),
                            label: "weekGlance.tile.notReturned", tone: .rose)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.tile.notReturned")
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func followUps(_ digest: AgendaDigest) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("home.followUps.title")
                .font(Typography.section).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, Spacing.row)
            HomeFollowUpsCard(
                digest: digest, counted: profile.clientTerm.countText(digest.followUps.count, in: locale),
                formatters: formatters
            )
        }
    }

    /// "New appointment" is Home's primary action. On a clear day the empty state already shows it as the primary
    /// button, so the quick action steps down to secondary there (one primary per screen).
    private func quickActions(isDayClear: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            Text("home.quick.title")
                .font(Typography.section).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Button { agendaSheet = .newAppointment(clientID: nil, startsAt: nil) } label: {
                Label { Text("home.quick.newAppointment") } icon: { Image(icon: .plus) }
            }
            .buttonStyle(isDayClear ? .belloSecondary : .belloPrimary)
            .accessibilityIdentifier("home.quick.newAppointment")
            NavigationLink(value: AgendaRoute.weekGlance) {
                Label { Text("home.quick.weekGlance") } icon: { Image(icon: .calendar) }
            }
            .buttonStyle(.belloSecondary)
            .accessibilityIdentifier("home.quick.weekGlance")
        }
    }
}
