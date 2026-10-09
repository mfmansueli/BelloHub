//
//  RescheduleRequestContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of 2.11: the visit as it is and the time the client asks for, the client's note, how close to the visit
/// the request came against her free-change window, and Decline / Move the visit.
struct RescheduleRequestContentView: View {
    @State private var viewModel: RescheduleRequestViewModel
    let settings: CalendarSettings
    @Environment(\.locale) private var locale

    init(viewModel: RescheduleRequestViewModel, settings: CalendarSettings) {
        _viewModel = State(initialValue: viewModel)
        self.settings = settings
    }

    private var formatters: Formatters { settings.formatters(locale: locale) }

    var body: some View {
        content
            .background(Palette.bg)
            .navigationTitle(Text("rescheduleRequest.title"))
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await viewModel.refreshAsync() }
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            ScrollView { ListLoadingView(rows: 2).padding(Spacing.gutter) }
                .accessibilityIdentifier("rescheduleRequest.loading")
        case .missing:
            ScrollView {
                EmptyState(icon: .bell, title: "inbox.missing.title", message: "inbox.missing.message")
                    .padding(Spacing.gutter)
                    .accessibilityIdentifier("rescheduleRequest.missing")
            }
        default:
            if let request = viewModel.request { details(request) }
        }
    }

    private func details(_ request: RescheduleRequest) -> some View {
        let name = BidiIsolate.wrap(request.clientName)
        let minutes = Int(request.requestedEnd.timeIntervalSince(request.requestedStart) / 60)
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(LocalizedStringResource(
                    "rescheduleRequest.subtitle",
                    defaultValue: "\(name) asked to move a visit. The current time stays booked until you say yes."
                ).localized(in: locale))
                .font(Typography.body).foregroundStyle(Palette.ink2)
                RequestSummaryCard(
                    clientName: request.clientName,
                    serviceLine: "\(request.serviceName) · \(formatters.minutes(max(minutes, 0)))",
                    note: request.note, identifier: "rescheduleRequest"
                ) {
                    times(request)
                }
                if let message = viewModel.errorMessage, viewModel.phase.canAnswer {
                    ErrorNotice(message: message).accessibilityIdentifier("rescheduleRequest.error")
                }
                if viewModel.phase == .slotTaken {
                    InlineNotice(
                        style: .warning, title: "rescheduleRequest.slotTaken.title",
                        message: "rescheduleRequest.slotTaken.message"
                    )
                    .accessibilityIdentifier("rescheduleRequest.slotTaken")
                }
                if viewModel.phase.canAnswer, let timing = viewModel.timing, timing.isLate { lateNotice(timing) }
                RequestOutcomeNotice(
                    phase: viewModel.phase, acceptedText: "rescheduleRequest.accepted",
                    declinedText: "rescheduleRequest.declined", isWaitingForNetwork: viewModel.isWaitingForNetwork,
                    identifier: "rescheduleRequest.outcome"
                )
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.bottom, Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.phase.canAnswer {
                RequestAnswerBar(
                    primaryTitle: Text("rescheduleRequest.accept"), identifierPrefix: "rescheduleRequest",
                    canAccept: viewModel.phase == .open, onDecline: viewModel.decline, onAccept: viewModel.accept
                )
            }
        }
    }

    private func times(_ request: RescheduleRequest) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("rescheduleRequest.now").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                Text(range(request.currentStart, request.currentEnd))
                    .font(Typography.body).foregroundStyle(Palette.ink2)
                    .strikethrough(viewModel.phase != .declined)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("rescheduleRequest.current")
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("rescheduleRequest.asksFor").font(Typography.metaStrong).foregroundStyle(Palette.sageText)
                Text(range(request.requestedStart, request.requestedEnd))
                    .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("rescheduleRequest.requested")
        }
    }

    private func range(_ start: Date, _ end: Date) -> LocalizedStringResource {
        LocalizedStringResource(
            "inbox.timeRange",
            defaultValue: """
            \(formatters.weekdayDayMonth(start)) · \(BidiIsolate.wrapLeftToRight(formatters.time(start))) to \
            \(BidiIsolate.wrapLeftToRight(formatters.time(end)))
            """
        ).localized(in: locale)
    }

    private func lateNotice(_ timing: RescheduleTiming) -> some View {
        let before = formatters.duration(minutes: timing.minutesBefore)
        let window = formatters.duration(minutes: (timing.freeWindowHours ?? 0) * 60)
        return InlineNotice(
            style: .warning,
            title: Text(LocalizedStringResource(
                "rescheduleRequest.timing.title", defaultValue: "Asked \(before) before the visit"
            ).localized(in: locale)),
            message: Text(LocalizedStringResource(
                "rescheduleRequest.timing.rule",
                defaultValue: "Your rule: free changes up to \(window) before, then clients send a request."
            ).localized(in: locale))
        )
        .accessibilityIdentifier("rescheduleRequest.timing")
    }
}

#if DEBUG
#Preview {
    InboxPreviewHost {
        NavigationStack { RescheduleRequestView(requestID: UITestInboxFixtures.rescheduleID) }
    }
}
#endif
