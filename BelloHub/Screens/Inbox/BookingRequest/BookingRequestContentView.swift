//
//  BookingRequestContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of 2.10: who asks, for what and when, why it waits for her (the request's reason), the "start the count
/// from zero" switch for the no-show limit, and Decline / Approve. Approving that needs a plan (D42) opens the paywall.
struct BookingRequestContentView: View {
    @State private var viewModel: BookingRequestViewModel
    let settings: CalendarSettings
    @Environment(\.locale) private var locale

    init(viewModel: BookingRequestViewModel, settings: CalendarSettings) {
        _viewModel = State(initialValue: viewModel)
        self.settings = settings
    }

    private var formatters: Formatters { settings.formatters(locale: locale) }

    var body: some View {
        content
            .background(Palette.bg)
            .navigationTitle(Text("bookingRequest.title"))
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await viewModel.refreshAsync() }
            .task { await viewModel.loadAsync() }
            .sheet(isPresented: $viewModel.isPaywallPresented) { PaywallSheet() }
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            ScrollView { ListLoadingView(rows: 2).padding(Spacing.gutter) }
                .accessibilityIdentifier("bookingRequest.loading")
        case .missing:
            ScrollView {
                EmptyState(icon: .bell, title: "inbox.missing.title", message: "inbox.missing.message")
                    .padding(Spacing.gutter)
                    .accessibilityIdentifier("bookingRequest.missing")
            }
        default:
            if let booking = viewModel.booking { request(booking) }
        }
    }

    private func request(_ booking: IncomingBooking) -> some View {
        let name = BidiIsolate.wrap(booking.client.name)
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(LocalizedStringResource(
                    "bookingRequest.subtitle",
                    defaultValue: "\(name) asked for this time. Nothing is booked until you say yes."
                ).localized(in: locale))
                .font(Typography.body).foregroundStyle(Palette.ink2)
                RequestSummaryCard(
                    clientName: booking.client.name,
                    serviceLine: "\(booking.serviceName) · \(formatters.minutes(booking.totalMinutes))",
                    note: booking.note, identifier: "bookingRequest"
                ) {
                    timeLine(booking)
                }
                if let message = viewModel.errorMessage, viewModel.phase.canAnswer {
                    ErrorNotice(message: message).accessibilityIdentifier("bookingRequest.error")
                }
                if viewModel.phase.canAnswer { reason(booking, name: name) }
                if viewModel.phase == .needsPlan { needsPlan }
                if viewModel.phase.canAnswer, viewModel.offersCountReset { resetCount }
                RequestOutcomeNotice(
                    phase: viewModel.phase, acceptedText: "bookingRequest.approved",
                    declinedText: "bookingRequest.declined", isWaitingForNetwork: viewModel.isWaitingForNetwork,
                    identifier: "bookingRequest.outcome"
                )
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.bottom, Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.phase.canAnswer {
                RequestAnswerBar(
                    primaryTitle: Text("bookingRequest.approve"), identifierPrefix: "bookingRequest",
                    onDecline: viewModel.decline, onAccept: viewModel.approve
                )
            }
        }
    }

    private func timeLine(_ booking: IncomingBooking) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.row) {
            Image(icon: .calendar).foregroundStyle(Palette.ink2).accessibilityHidden(true)
            Text(LocalizedStringResource(
                "inbox.timeRange",
                defaultValue: """
                \(formatters.weekdayDayMonth(booking.startsAt)) · \
                \(BidiIsolate.wrapLeftToRight(formatters.time(booking.startsAt))) to \
                \(BidiIsolate.wrapLeftToRight(formatters.time(booking.endsAt)))
                """
            ).localized(in: locale))
            .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("bookingRequest.time")
    }

    // MARK: - Sections

    @ViewBuilder
    private func reason(_ booking: IncomingBooking, name: String) -> some View {
        switch booking.pendingReason {
        case .noShowLimit?:
            VStack(alignment: .leading, spacing: Spacing.sm) {
                InlineNotice(
                    style: .safety,
                    title: Text(LocalizedStringResource(
                        "bookingRequest.reason.noShowLimit.title",
                        defaultValue: "You asked to confirm \(name)'s bookings."
                    ).localized(in: locale)),
                    message: Text("bookingRequest.reason.noShowLimit.message")
                )
                .accessibilityIdentifier("bookingRequest.reason")
                if let clientID = viewModel.historyClientID {
                    NavigationLink(value: AgendaRoute.noShowHistory(clientID: clientID)) {
                        Text("bookingRequest.history")
                    }
                    .buttonStyle(.belloTertiary)
                    .accessibilityIdentifier("bookingRequest.historyButton")
                }
            }
        case .freeRegistrationsUsed?:
            InlineNotice(
                style: .warning, title: "bookingRequest.reason.freeRegistrations.title",
                message: "bookingRequest.reason.freeRegistrations.message"
            )
            .accessibilityIdentifier("bookingRequest.reason")
        case .newClient?, nil:
            InlineNotice(
                style: .info, title: "bookingRequest.reason.newClient.title",
                message: "bookingRequest.reason.newClient.message"
            )
            .accessibilityIdentifier("bookingRequest.reason")
        }
    }

    private var needsPlan: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            InlineNotice(
                style: .warning, title: "bookingRequest.needsPlan.title", message: "bookingRequest.needsPlan.message"
            )
            .accessibilityIdentifier("bookingRequest.needsPlan")
            Button(action: viewModel.showPlans) { Text("bookingRequest.seePlans") }
                .buttonStyle(.belloSecondary)
                .accessibilityIdentifier("bookingRequest.seePlansButton")
        }
    }

    private var resetCount: some View {
        ToggleRow(
            title: String(localized: "bookingRequest.resetCount.title", locale: locale),
            subtitle: String(localized: "bookingRequest.resetCount.detail", locale: locale),
            isOn: $viewModel.resetsCount, identifier: "bookingRequest.resetCountToggle"
        )
        .padding(Spacing.md)
        .belloCard(cornerRadius: Radius.tile)
    }
}

#if DEBUG
#Preview {
    InboxPreviewHost { NavigationStack { BookingRequestView(bookingID: UITestInboxFixtures.requestID) } }
}
#endif
