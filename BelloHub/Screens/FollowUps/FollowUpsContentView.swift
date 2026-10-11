//
//  FollowUpsContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of the follow-up queue (routine-a items 5, 6 and 12): booking requests kept apart with the way to Alerts,
/// the filters, one card per client with every reason she is here, the suggestions she set aside, and a footer that
/// says where the suggestions come from and that she decides. Every message opens as a sheet with the text ready;
/// nothing is sent by the app (D14). Empty, loading and error states are `ScreenStateView`'s.
struct FollowUpsContentView: View {
    @State private var viewModel: FollowUpsViewModel
    @State private var agendaSheet: AgendaSheet?
    @State private var treatment: TreatmentFlowRequest?
    /// How many messages she marked as sent while this screen was open; the confirmation watches it.
    @State private var markedSent = 0
    @Environment(MessageService.self) private var messages
    @Environment(MainNavigation.self) private var navigation: MainNavigation?
    @Environment(\.locale) private var locale

    init(viewModel: FollowUpsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var formatters: Formatters { viewModel.settings.formatters(locale: locale) }

    var body: some View {
        ScrollView {
            TimelineView(.everyMinute) { context in
                VStack(alignment: .leading, spacing: Spacing.row) {
                    Text("followUpQueue.subtitle")
                        .font(Typography.body).foregroundStyle(Palette.ink2)
                        .accessibilityIdentifier("followUps.subtitle")
                    requests(count: viewModel.requestCount(now: context.date))
                    ScreenStateView(
                        phase: viewModel.phase(now: context.date), prefix: "followUps", retry: viewModel.retry
                    ) {
                        EmptyState(
                            icon: .repeatArrows, title: "followUps.empty.title", message: "followUps.empty.message"
                        )
                        .accessibilityIdentifier("followUps.empty")
                    } content: {
                        sections(viewModel.queue(now: context.date))
                    }
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.bottom, Spacing.lg)
        }
        .background(Palette.bg)
        .navigationTitle(Text("followUpQueue.title"))
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await viewModel.refreshAsync() }
        .confirmationSeal(whenIncreases: markedSent)
        .task { viewModel.start() }
        .onChange(of: messages.recentlyOpened) { viewModel.chatsChanged() }
        .agendaSheet(item: $agendaSheet)
        .treatmentFlow(item: $treatment)
    }

    // MARK: - Sections

    private func sections(_ queue: FollowUpQueue) -> some View {
        let rows = queue.rows(viewModel.filter)
        let aside = queue.setAside(viewModel.filter)
        // The cards that come and go (snoozed, dismissed, sent, a new reason) are the only things that move; changing
        // the filter is a different list, so it does not animate (the filter is the context).
        return VStack(alignment: .leading, spacing: Spacing.row) {
            filters(queue)
            if let message = viewModel.errorMessage {
                ErrorNotice(message: message).accessibilityIdentifier("followUps.error")
            }
            if rows.isEmpty {
                Text("followUpQueue.filterEmpty")
                    .font(Typography.body).foregroundStyle(Palette.ink2)
                    .padding(.vertical, Spacing.md)
                    .accessibilityIdentifier("followUps.filterEmpty")
                    .motionRow()
            }
            ForEach(rows) { row in card(row).motionRow() }
            if !aside.isEmpty { setAside(aside).motionRow() }
            FooterNote(text: "followUpQueue.footer", icon: .info).padding(.top, Spacing.xs)
        }
        .motionRows(
            ids: rows.map { "row.\($0.id)" } + aside.map { "aside.\($0.id)" }, context: viewModel.filter
        )
    }

    /// Booking requests need a decision about the agenda, so they are never mixed into the queue: one labelled line
    /// that opens Alerts, where they are answered.
    @ViewBuilder
    private func requests(count: Int) -> some View {
        if count > 0 {
            ListCard(dividerInset: 72) {
                Button { navigation?.selection = .alerts } label: {
                    HomeCountRow(
                        icon: .calendar, tone: .sage, title: Text("home.today.requests"),
                        subtitle: Text("home.today.requests.subtitle"), count: formatters.number(count)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("followUps.requests")
            }
        }
    }

    private func filters(_ queue: FollowUpQueue) -> some View {
        FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm) {
            ForEach(FollowUpFilter.allCases) { filter in
                let count = queue.count(filter)
                Button { viewModel.filter = filter } label: {
                    HStack(spacing: Spacing.xs) {
                        Text(filter.label)
                        Text(verbatim: formatters.number(count)).motionNumber(count)
                    }
                }
                .buttonStyle(.belloChip(selected: viewModel.filter == filter))
                .accessibilityAddTraits(viewModel.filter == filter ? .isSelected : [])
                .accessibilityIdentifier("followUps.filter.\(filter.rawValue)")
            }
        }
    }

    private func card(_ row: FollowUpQueue.Row, isSetAside: Bool = false) -> some View {
        FollowUpRowCard(
            row: row, formatters: formatters, isSetAside: isSetAside,
            onAction: perform, onBook: { agendaSheet = .newAppointment(clientID: $0, startsAt: nil) },
            onMarkSent: { markedSent += 1; viewModel.markSent($0) }, onSnooze: viewModel.snooze,
            onDismiss: viewModel.dismiss,
            onRestore: viewModel.restore, onFinishClosing: viewModel.finishClosing
        )
    }

    private func setAside(_ rows: [FollowUpQueue.Row]) -> some View {
        DisclosureGroup(isExpanded: $viewModel.showsSetAside) {
            VStack(spacing: Spacing.row) {
                ForEach(rows) { row in card(row, isSetAside: true).motionRow() }
            }
            .padding(.top, Spacing.sm)
        } label: {
            HStack(spacing: Spacing.xs) {
                Text("followUpQueue.setAside").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Text(verbatim: formatters.number(rows.count)).font(Typography.meta).foregroundStyle(Palette.ink2)
                    .motionNumber(rows.count)
            }
            // On the label: an identifier on the group would replace the cards' own.
            .accessibilityIdentifier("followUps.setAside")
        }
        .tint(Palette.ink)
        .padding(.top, Spacing.sm)
    }

    private func perform(_ action: FollowUpAction) {
        switch action {
        case .sheet(let sheet): agendaSheet = sheet
        case .resumeVisit(let request): treatment = request
        }
    }
}
