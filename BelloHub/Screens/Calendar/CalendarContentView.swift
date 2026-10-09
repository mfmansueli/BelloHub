//
//  CalendarContentView.swift
//  BelloHub
//

import SwiftUI

/// The Calendar tab: the header (date, Day/Week, week strip), then the day timeline or the week. The day view is the
/// accessible default; the week grid is the dense exception, and at accessibility text sizes the week becomes a list.
/// The header is pinned except at those sizes, where it scrolls with the content so the schedule is not squeezed.
struct CalendarContentView: View {
    @State private var viewModel: CalendarViewModel
    private let settings: CalendarSettings

    @State private var agendaSheet: AgendaSheet?
    @State private var blockToRemove: UUID?
    @State private var removeFailed = false
    @ScaledMetric(relativeTo: .body) private var dayHourHeight: CGFloat = 64
    @ScaledMetric(relativeTo: .caption) private var weekHourHeight: CGFloat = 36
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.locale) private var locale
    @Environment(TimeBlockService.self) private var timeBlocks

    init(viewModel: CalendarViewModel, settings: CalendarSettings) {
        _viewModel = State(initialValue: viewModel)
        self.settings = settings
    }

    private var formatters: Formatters { settings.formatters(locale: locale) }

    var body: some View {
        TimelineView(.everyMinute) { context in
            screen(now: context.date)
        }
        .background(Palette.bg)
        .navigationTitle(Text("main.tab.calendar"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbar }
        .agendaSheet(item: $agendaSheet)
        .confirmationDialog(
            Text("calendar.block.remove.title"), isPresented: Binding(
                get: { blockToRemove != nil }, set: { if !$0 { blockToRemove = nil } }
            ), titleVisibility: .visible
        ) {
            Button(role: .destructive) { removeBlock() } label: { Text("calendar.block.remove.confirm") }
                .accessibilityIdentifier("calendar.block.removeConfirm")
            Button(role: .cancel) { blockToRemove = nil } label: { Text("common.cancel") }
        } message: {
            Text("calendar.block.remove.message")
        }
        .alert(Text("calendar.block.remove.failed"), isPresented: $removeFailed) {
            Button { removeFailed = false } label: { Text("common.close") }
        }
        .task { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
    }

    // MARK: - Screen

    private func screen(now: Date) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if typeSize.isAccessibilitySize { header(now: now) }
                    content(now: now)
                }
                .padding(.bottom, Spacing.lg)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if !typeSize.isAccessibilitySize { header(now: now).background(Palette.bg) }
            }
            .onChange(of: viewModel.selectedDay) { scroll(proxy, now: now) }
            .onChange(of: viewModel.isLoading) { scroll(proxy, now: now) }
            .onChange(of: viewModel.mode) { scroll(proxy, now: now) }
        }
    }

    private func header(now: Date) -> some View {
        CalendarHeader(
            mode: $viewModel.mode, selectedDay: viewModel.selectedDay, weekDays: viewModel.weekDays, now: now,
            formatters: formatters, onSelectDay: viewModel.select, onStep: viewModel.step,
            onToday: { viewModel.goToToday(now: now) }
        )
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        if let message = viewModel.errorMessage {
            ErrorNotice(message: message, actionTitle: "scheduling.tryAgain") { viewModel.startListening() }
                .padding(Spacing.gutter)
                .accessibilityIdentifier("calendar.error")
        } else if viewModel.isLoading {
            loading
        } else if viewModel.mode == .day {
            dayContent(now: now)
        } else {
            weekContent(now: now)
        }
    }

    private var loading: some View {
        VStack(spacing: Spacing.row) {
            Skeleton(height: 72, cornerRadius: Radius.control)
            Skeleton(height: 72, cornerRadius: Radius.control)
            Skeleton(height: 72, cornerRadius: Radius.control)
        }
        .padding(Spacing.gutter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("scheduling.loading"))
        .accessibilityIdentifier("calendar.loading")
    }

    // MARK: - Day

    private func dayContent(now: Date) -> some View {
        let day = viewModel.selectedDay
        let layout = viewModel.layout(for: day)
        let visits = viewModel.visits(on: day)
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            if layout.isClosed { closedNotice(layout) }
            if visits.isEmpty && !layout.isClosed {
                Text("calendar.day.empty")
                    .font(Typography.meta).foregroundStyle(Palette.ink2)
                    .padding(.horizontal, Spacing.gutter)
                    .accessibilityIdentifier("calendar.day.empty")
            }
            DayTimelineView(
                layout: layout, appointments: visits, blocks: viewModel.blocks,
                clientName: viewModel.clientName(of:), now: now, formatters: formatters, hourHeight: dayHourHeight,
                onTapSlot: { agendaSheet = .newAppointment(clientID: nil, startsAt: $0) },
                onReschedule: { agendaSheet = .reschedule(appointmentID: $0) },
                onCancel: { agendaSheet = .cancel(appointmentID: $0) }, onRemoveBlock: { blockToRemove = $0 }
            )
            .padding(.top, Spacing.sm)
        }
    }

    private func closedNotice(_ layout: CalendarDayLayout) -> some View {
        let title: LocalizedStringKey = layout.dayOff == nil ? "calendar.closed.weekday" : "calendar.closed.dayOff"
        return InlineNotice(style: .info, title: title, message: "calendar.closed.message")
            .padding(.horizontal, Spacing.gutter)
            .accessibilityIdentifier("calendar.closedNotice")
    }

    // MARK: - Week

    @ViewBuilder
    private func weekContent(now: Date) -> some View {
        if typeSize.isAccessibilitySize {
            WeekAgendaList(
                days: viewModel.weekDays, visits: viewModel.visits(on:), clientName: viewModel.clientName(of:),
                now: now, formatters: formatters, onSelectDay: openDay,
                onAdd: { agendaSheet = .newAppointment(clientID: nil, startsAt: addTime(on: $0)) }
            )
        } else {
            let scale = viewModel.scale
            let layouts = viewModel.weekDays.map { day in
                CalendarDayLayout.make(
                    day: day, appointments: viewModel.visits(on: day), blocks: viewModel.blocks, scale: scale
                )
            }
            VStack(alignment: .leading, spacing: Spacing.sm) {
                WeekGridView(
                    layouts: layouts, appointments: viewModel.appointments, clientName: viewModel.clientName(of:),
                    now: now, formatters: formatters, hourHeight: weekHourHeight, onSelectDay: openDay,
                    onTapSlot: { agendaSheet = .newAppointment(clientID: nil, startsAt: $0) },
                    onReschedule: { agendaSheet = .reschedule(appointmentID: $0) },
                    onCancel: { agendaSheet = .cancel(appointmentID: $0) }
                )
                Button { viewModel.mode = .day } label: {
                    Text("calendar.week.useDayView")
                        .font(Typography.metaStrong).foregroundStyle(Palette.roseText)
                        .frame(minHeight: Spacing.touchTarget)
                }
                .padding(.horizontal, Spacing.gutter)
                .accessibilityIdentifier("calendar.week.dayViewButton")
            }
        }
    }

    // MARK: - Toolbar and actions

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            NavigationLink(value: AgendaRoute.weekGlance) { Image(icon: .sparkle) }
                .accessibilityLabel(Text("calendar.toolbar.weekGlance"))
                .accessibilityIdentifier("calendar.weekGlanceButton")
            Menu {
                Button { agendaSheet = .blockTime(day: viewModel.selectedDay) } label: {
                    Label { Text("calendar.toolbar.blockTime") } icon: { Image(icon: .lock) }
                }
                .accessibilityIdentifier("calendar.blockTimeButton")
            } label: {
                Image(systemName: "ellipsis")
            }
            .accessibilityLabel(Text("calendar.toolbar.more"))
            .accessibilityIdentifier("calendar.moreMenu")
            Button { agendaSheet = .newAppointment(clientID: nil, startsAt: nil) } label: { Image(icon: .plus) }
                .accessibilityLabel(Text("calendar.toolbar.new"))
                .accessibilityIdentifier("calendar.newButton")
        }
    }

    /// A heading in the week opens that day in the day view.
    private func openDay(_ day: Date) {
        viewModel.select(day: day)
        viewModel.mode = .day
    }

    /// The time "Add" on a day of the agenda list offers: the day's first working time, or nine o'clock.
    private func addTime(on day: Date) -> Date {
        let layout = viewModel.layout(for: day)
        return layout.workingWindows.first?.start ?? viewModel.days.date(on: day, minutes: 9 * 60)
    }

    private func removeBlock() {
        guard let id = blockToRemove else { return }
        blockToRemove = nil
        Task {
            do { try await timeBlocks.removeBlock(id: id) } catch { removeFailed = true }
        }
    }

    /// Brings the part of the day she needs to the top: an hour before now today, otherwise her first visit or her
    /// opening hour.
    private func scroll(_ proxy: ScrollViewProxy, now: Date) {
        guard viewModel.mode == .day, !viewModel.isLoading else { return }
        let layout = viewModel.layout(for: viewModel.selectedDay)
        let target: Date
        if layout.window.contains(now), viewModel.days.isSameDay(now, layout.day) {
            target = now.addingTimeInterval(-3_600)
        } else {
            target = layout.visits.first?.interval.start ?? layout.workingWindows.first?.start ?? layout.window.start
        }
        let index = layout.hourMarks.lastIndex { $0 <= target } ?? 0
        proxy.scrollTo("calendar.hour.\(index)", anchor: .top)
    }
}
