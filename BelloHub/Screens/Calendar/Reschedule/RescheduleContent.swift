//
//  RescheduleContent.swift
//  BelloHub
//

import SwiftUI

/// The body of the Reschedule sheet: the visit, the day and time to move it to, a switch to message the client
/// afterwards and the confirmation. Moving the visit keeps its length; the client's message is the Messages slice's
/// sheet (`AgendaSheet.message`), offered once the move is stored.
struct RescheduleContent: View {
    @State private var viewModel: RescheduleViewModel
    private let settings: CalendarSettings

    @State private var agendaSheet: AgendaSheet?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(viewModel: RescheduleViewModel, settings: CalendarSettings) {
        _viewModel = State(initialValue: viewModel)
        self.settings = settings
    }

    private var formatters: Formatters { settings.formatters(locale: locale) }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.phase {
                case .loading: loading
                case .notFound: notFound
                case .choosing: choosing
                case .moved(let moved): movedView(moved)
                }
            }
            .background(Palette.bg)
            .navigationTitle(Text("reschedule.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.close") }
                        .accessibilityIdentifier("reschedule.closeButton")
                }
            }
            .task { await viewModel.loadAsync() }
            .agendaSheet(item: $agendaSheet)
        }
        .presentationDetents([.large])
        .presentationBackground(Palette.bg)
    }

    // MARK: - Phases

    private var loading: some View {
        VStack(spacing: Spacing.row) {
            Skeleton(height: 88, cornerRadius: Radius.card)
            Skeleton(height: 44)
            Skeleton(height: 44)
        }
        .padding(Spacing.gutter)
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("scheduling.loading"))
        .accessibilityIdentifier("reschedule.loading")
    }

    private var notFound: some View {
        VStack(spacing: Spacing.md) {
            if let message = viewModel.errorMessage {
                ErrorNotice(message: message, actionTitle: "scheduling.tryAgain") { viewModel.load() }
                    .accessibilityIdentifier("reschedule.error")
            } else {
                EmptyState(icon: .calendar, title: "reschedule.notFound.title", message: "reschedule.notFound.message")
                    .accessibilityIdentifier("reschedule.notFound")
            }
        }
        .padding(Spacing.gutter)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var choosing: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let appointment = viewModel.appointment { visitCard(appointment) }
                SectionHeader(title: "reschedule.section.day")
                SchedulingTimeSection(
                    idPrefix: "reschedule", formatters: formatters, day: viewModel.day, start: viewModel.start,
                    slots: viewModel.slots, moreSlots: viewModel.moreSlots,
                    offeredDays: viewModel.offeredDays.map(\.day), onSelectDay: viewModel.selectDay,
                    onSelectStart: viewModel.selectStart, onSelectMinutes: viewModel.selectTime
                )
                warningsSection
                messageToggle.padding(.top, Spacing.lg)
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.bottom, Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) { confirmBar }
    }

    private func movedView(_ moved: Appointment) -> some View {
        VStack(spacing: Spacing.md) {
            Spacer(minLength: Spacing.lg)
            SuccessSeal(size: 72)
            Text("reschedule.done.title")
                .font(Typography.title).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("reschedule.done")
            Text(verbatim: formatters.dateTime(moved.startsAt))
                .font(Typography.body).foregroundStyle(Palette.ink2)
                .accessibilityIdentifier("reschedule.done.time")
            if viewModel.messagesClient {
                Button { agendaSheet = .message(appointmentID: moved.id) } label: {
                    Text("reschedule.done.message")
                }
                .buttonStyle(.belloSecondary)
                .accessibilityIdentifier("reschedule.done.messageButton")
            }
            Button { dismiss() } label: { Text("reschedule.done.back") }
                .buttonStyle(.belloPrimary)
                .accessibilityIdentifier("reschedule.done.backButton")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.gutter)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Parts

    private func visitCard(_ appointment: Appointment) -> some View {
        HStack(spacing: Spacing.row) {
            Avatar(name: viewModel.client?.name ?? "", id: appointment.clientID.uuidString, size: 48)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: viewModel.client?.name ?? "")
                    .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Text(verbatim: "\(appointment.serviceName) · "
                    + formatters.duration(minutes: appointment.totalMinutes))
                    .font(Typography.meta).foregroundStyle(Palette.ink2)
                Text(
                    LocalizedStringResource(
                        "reschedule.now", defaultValue: "Now: \(formatters.dateTime(appointment.startsAt))"
                    ).localized(in: locale)
                )
                .font(Typography.footnoteStrong).foregroundStyle(Palette.neutralText)
                .padding(.horizontal, Spacing.row).padding(.vertical, Spacing.xs)
                .background(Palette.neutralWash, in: Capsule())
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .padding(.top, Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("reschedule.visit")
    }

    @ViewBuilder
    private var warningsSection: some View {
        let text = SchedulingWarningText(
            clientName: viewModel.client?.name ?? "", serviceName: viewModel.appointment?.serviceName ?? "",
            neighbourName: { _ in nil }, catalog: nil, formatters: formatters
        )
        let entries = text.entries(for: viewModel.warnings)
        if !entries.isEmpty {
            SchedulingWarningsView(entries: entries, idPrefix: "reschedule").padding(.top, Spacing.md)
        }
    }

    private var messageToggle: some View {
        ToggleRow(
            title: LocalizedStringResource(
                "reschedule.message.title", defaultValue: "Message \(viewModel.client?.name ?? "") on WhatsApp"
            ).resolved(in: locale),
            subtitle: String(localized: LocalizedStringResource(
                "reschedule.message.subtitle", defaultValue: "Tell them about the new time", locale: locale
            )),
            isOn: $viewModel.messagesClient, identifier: "reschedule.messageToggle"
        )
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
    }

    private var confirmBar: some View {
        VStack(spacing: Spacing.sm) {
            if let message = viewModel.saveErrorMessage {
                ErrorNotice(message: message).accessibilityIdentifier("reschedule.saveError")
            }
            Button { Task { await viewModel.confirmAsync() } } label: {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Text(viewModel.hasScheduleConflict ? "reschedule.confirmAnyway" : "reschedule.confirm")
                }
            }
            .buttonStyle(.belloPrimary)
            .disabled(!viewModel.canConfirm || !viewModel.changesTime)
            .accessibilityIdentifier("reschedule.confirmButton")
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
    }
}
