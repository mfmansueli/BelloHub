//
//  WaitlistContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of 2.9: the time that opened up (hero), the people waiting for that day with an Offer each, everybody else
/// still waiting, and "Offer to everyone". Offers need the server at once; an error says so and nothing is half-sent.
struct WaitlistContentView: View {
    @State private var viewModel: WaitlistViewModel
    let settings: CalendarSettings
    @Environment(\.locale) private var locale

    init(viewModel: WaitlistViewModel, settings: CalendarSettings) {
        _viewModel = State(initialValue: viewModel)
        self.settings = settings
    }

    private var formatters: Formatters { settings.formatters(locale: locale) }

    var body: some View {
        TimelineView(.everyMinute) { context in
            let board = viewModel.board(now: context.date)
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text(board.openTime == nil ? "waitlist.subtitle.none" : "waitlist.subtitle")
                        .font(Typography.body).foregroundStyle(Palette.ink2)
                    if let text = viewModel.shareText {
                        ShareFallbackCard(text: text, identifier: "waitlist.shareFallback")
                    }
                    if let message = viewModel.errorMessage {
                        ErrorNotice(
                            message: message, actionTitle: "appointment.error.dismiss", action: viewModel.dismissError
                        )
                        .accessibilityIdentifier("waitlist.error")
                    }
                    states(board)
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.bottom, Spacing.lg)
            }
            .safeAreaInset(edge: .bottom) {
                if board.openTime != nil, !board.offerable.isEmpty, !viewModel.isTimeTaken { offerAllBar }
            }
        }
        .background(Palette.bg)
        .navigationTitle(Text("waitlist.title"))
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await viewModel.refreshAsync() }
        .task { await viewModel.loadHabits() }
    }

    // MARK: - States

    @ViewBuilder
    private func states(_ board: WaitlistBoard) -> some View {
        if viewModel.isLoading {
            ListLoadingView(rows: 3).accessibilityIdentifier("waitlist.loading")
        } else if board.isEmpty {
            if let message = viewModel.syncErrorMessage {
                ErrorNotice(message: message).accessibilityIdentifier("waitlist.syncError")
            }
            EmptyState(icon: .clock, title: "waitlist.empty.title", message: "waitlist.empty.message")
                .accessibilityIdentifier("waitlist.empty")
        } else {
            if let open = board.openTime { hero(open) }
            if viewModel.isTimeTaken {
                InlineNotice(style: .warning, title: "waitlist.slotTaken").accessibilityIdentifier("waitlist.slotTaken")
            }
            if !board.forThatDay.isEmpty {
                SectionHeader(title: "waitlist.section.thatDay")
                people(board.forThatDay, canOffer: true)
                FooterNote(text: "waitlist.footnote", icon: .info)
            }
            if !board.others.isEmpty {
                SectionHeader(title: board.openTime == nil ? "waitlist.section.waiting" : "waitlist.section.others")
                people(board.others, canOffer: false)
            }
        }
    }

    private func hero(_ open: WaitlistBoard.OpenTime) -> some View {
        HeroCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label {
                    Text(LocalizedStringResource(
                        "waitlist.freedBy", defaultValue: "Freed by \(BidiIsolate.wrap(open.clientName))"
                    ).localized(in: locale))
                } icon: {
                    Image(icon: .clock)
                }
                .font(Typography.metaStrong).foregroundStyle(HeroPalette.ink2)
                Text(verbatim: BidiIsolate.wrapLeftToRight(formatters.time(open.startsAt)))
                    .font(Typography.numeral).foregroundStyle(HeroPalette.ink)
                Text(verbatim: "\(formatters.weekdayDayMonth(open.startsAt)) · \(open.serviceName)")
                    .font(Typography.bodyStrong).foregroundStyle(HeroPalette.ink)
                Text(LocalizedStringResource(
                    "waitlist.until",
                    defaultValue: """
                    \(formatters.minutes(open.minutes)) · until \
                    \(BidiIsolate.wrapLeftToRight(formatters.time(open.endsAt)))
                    """
                ).localized(in: locale))
                .font(Typography.meta).foregroundStyle(HeroPalette.ink2)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("waitlist.openTime")
        }
    }

    private func people(_ entries: [WaitlistRequest], canOffer: Bool) -> some View {
        ListCard {
            ForEach(entries) { entry in
                WaitlistPersonRow(
                    entry: entry, formatters: formatters, canOffer: canOffer && !viewModel.isTimeTaken,
                    cancelsOften: viewModel.cancelsOften(entry),
                    isOffering: viewModel.offering.contains(entry.id), result: viewModel.results[entry.id],
                    isSent: viewModel.sent.contains(entry.id),
                    onOffer: { viewModel.offer(entry) }, onSend: { viewModel.send(entry) },
                    onRemove: { viewModel.remove(entry) }
                )
            }
        }
    }

    private var offerAllBar: some View {
        Button { viewModel.offerAll() } label: { Text("waitlist.offerAll") }
            .buttonStyle(.belloPrimary)
            .disabled(!viewModel.offering.isEmpty)
            .accessibilityIdentifier("waitlist.offerAllButton")
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
            .background(Palette.bg)
    }
}

#if DEBUG
#Preview {
    InboxPreviewHost { NavigationStack { WaitlistView() } }
}
#endif
