//
//  BlockTimeContent.swift
//  BelloHub
//

import SwiftUI

/// The body of the Block time sheet: days, how long, a private reason, and what happens to the visits already booked
/// in that time. Cancelling them is the professional's choice and never counts against a client; each client can
/// then be told through the Messages sheet (`AgendaSheet.message`).
struct BlockTimeContent: View {
    @State private var viewModel: BlockTimeViewModel
    private let settings: CalendarSettings

    @State private var agendaSheet: AgendaSheet?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(viewModel: BlockTimeViewModel, settings: CalendarSettings) {
        _viewModel = State(initialValue: viewModel)
        self.settings = settings
    }

    private var formatters: Formatters { settings.formatters(locale: locale) }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.phase {
                case .editing: editing
                case .done(let outcome):
                    BlockTimeDoneView(
                        outcome: outcome, formatters: formatters, clientName: viewModel.clientName(for:),
                        onMessage: { agendaSheet = .message(appointmentID: $0) }, onBack: { dismiss() }
                    )
                }
            }
            .background(Palette.bg)
            .navigationTitle(Text("blockTime.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text(isDone ? "common.close" : "common.cancel") }
                        .accessibilityIdentifier("blockTime.cancelButton")
                }
            }
            .task { await viewModel.loadAsync() }
            .agendaSheet(item: $agendaSheet)
        }
        .presentationDetents([.large])
        .presentationBackground(Palette.bg)
    }

    private var isDone: Bool {
        if case .done = viewModel.phase { return true }
        return false
    }

    // MARK: - Editing

    private var editing: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("blockTime.intro")
                    .font(Typography.body).foregroundStyle(Palette.ink2)
                    .padding(.top, Spacing.sm)
                if let message = viewModel.errorMessage {
                    ErrorNotice(message: message, actionTitle: "scheduling.tryAgain") { viewModel.load() }
                        .padding(.top, Spacing.md)
                        .accessibilityIdentifier("blockTime.error")
                }
                SectionHeader(title: "blockTime.section.days")
                daysChips
                SectionHeader(title: "blockTime.section.how")
                scopeSection
                SectionHeader(title: "blockTime.section.reason")
                Text("blockTime.reason.private")
                    .font(Typography.meta).foregroundStyle(Palette.ink2).padding(.bottom, Spacing.sm)
                reasonChips
                if !viewModel.affectedVisits.isEmpty { visitsSection }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.bottom, Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) { saveBar }
    }

    private var daysChips: some View {
        FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm, wrapsLongChildren: true) {
            ForEach(Array(viewModel.candidateDays.enumerated()), id: \.element) { index, day in
                let selected = viewModel.selectedDays.contains(day)
                Button { viewModel.toggleDay(day) } label: { Text(verbatim: dayTitle(day)) }
                    .buttonStyle(.belloChip(selected: selected))
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("blockTime.day.\(index)")
            }
        }
    }

    private var scopeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            Picker(selection: $viewModel.scope) {
                Text("blockTime.scope.wholeDay").tag(BlockTimeViewModel.ScopeChoice.wholeDay)
                Text("blockTime.scope.someHours").tag(BlockTimeViewModel.ScopeChoice.someHours)
            } label: { Text("blockTime.section.how") }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("blockTime.scopePicker")
            if viewModel.scope == .someHours {
                VStack(spacing: 0) {
                    timeRow("blockTime.from", minutes: viewModel.startMinutes, identifier: "blockTime.fromPicker") {
                        viewModel.setStart(minutes: $0)
                    }
                    Divider().overlay(Palette.hairline)
                    timeRow("blockTime.until", minutes: viewModel.endMinutes, identifier: "blockTime.untilPicker") {
                        viewModel.setEnd(minutes: $0)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                if viewModel.issue == .emptyHours {
                    Text("blockTime.error.emptyHours")
                        .font(Typography.footnote).foregroundStyle(Palette.coralText)
                        .accessibilityIdentifier("blockTime.emptyHoursError")
                }
            }
        }
    }

    private func timeRow(
        _ title: LocalizedStringKey, minutes: Int, identifier: String, set: @escaping (Int) -> Void
    ) -> some View {
        DatePicker(
            selection: Binding(
                get: { formatters.timeOfDay(minutes: minutes) }, set: { set(formatters.minutesOfDay($0)) }
            ),
            displayedComponents: .hourAndMinute
        ) {
            Text(title).font(Typography.body).foregroundStyle(Palette.ink)
        }
        .environment(\.timeZone, formatters.timeZone)
        .environment(\.calendar, formatters.calendar)
        .frame(minHeight: Spacing.touchTarget)
        .accessibilityIdentifier(identifier)
    }

    private var reasonChips: some View {
        FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm, wrapsLongChildren: true) {
            ForEach(BlockReason.allCases) { option in
                let selected = viewModel.reason == option
                Button { viewModel.reason = selected ? nil : option } label: {
                    Text(option.title.localized(in: locale))
                }
                .buttonStyle(.belloChip(selected: selected))
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("blockTime.reason.\(option.rawValue)")
            }
        }
    }

    private var visitsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "blockTime.section.visits")
            VStack(spacing: 0) {
                ForEach(Array(viewModel.affectedVisits.enumerated()), id: \.element.id) { index, visit in
                    if index > 0 { Divider().overlay(Palette.hairline) }
                    visitRow(visit, index: index)
                }
            }
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
            VStack(spacing: Spacing.sm) {
                ChoiceCard(
                    title: String(localized: LocalizedStringResource(
                        "blockTime.choice.cancel.title", defaultValue: "Cancel and invite to rebook", locale: locale
                    )),
                    subtitle: String(localized: LocalizedStringResource(
                        "blockTime.choice.cancel.subtitle",
                        defaultValue: "Cancelled by you, so it never counts against a client.", locale: locale
                    )),
                    isSelected: viewModel.visitChoice == .cancelAndInvite,
                    identifier: "blockTime.choice.cancelAndInvite"
                ) { viewModel.visitChoice = .cancelAndInvite }
                ChoiceCard(
                    title: String(localized: LocalizedStringResource(
                        "blockTime.choice.keep.title", defaultValue: "Keep them for now", locale: locale
                    )),
                    subtitle: String(localized: LocalizedStringResource(
                        "blockTime.choice.keep.subtitle", defaultValue: "The visits stay booked. You decide later.",
                        locale: locale
                    )),
                    isSelected: viewModel.visitChoice == .keep, identifier: "blockTime.choice.keep"
                ) { viewModel.visitChoice = .keep }
            }
            .padding(.top, Spacing.row)
        }
    }

    private func visitRow(_ visit: Appointment, index: Int) -> some View {
        HStack(spacing: Spacing.row) {
            Avatar(name: viewModel.clientName(for: visit), id: visit.clientID.uuidString, size: 40)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: viewModel.clientName(for: visit))
                    .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Text(verbatim: "\(visit.serviceName) · \(formatters.dateTime(visit.startsAt))")
                    .font(Typography.meta).foregroundStyle(Palette.ink2)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("blockTime.visit.\(index)")
    }

    private var saveBar: some View {
        VStack(spacing: Spacing.sm) {
            if let message = viewModel.saveErrorMessage {
                ErrorNotice(message: message).accessibilityIdentifier("blockTime.saveError")
            }
            Button { Task { await viewModel.saveAsync(reasonText: reasonText) } } label: {
                if viewModel.isSaving { ProgressView() } else { saveTitle }
            }
            .buttonStyle(.belloPrimary)
            .disabled(!viewModel.canSave)
            .accessibilityIdentifier("blockTime.saveButton")
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
    }

    private var saveTitle: Text {
        guard viewModel.cancelsVisits else { return Text("blockTime.save") }
        let count = viewModel.affectedVisits.count
        return Text(LocalizedStringResource(
            "blockTime.saveAndCancel", defaultValue: "Block and cancel \(count) visits"
        ).localized(in: locale))
    }

    private var reasonText: String? {
        viewModel.reason.map { String(localized: $0.title.localized(in: locale)) }
    }

    // MARK: - Helpers

    /// "Wed, Oct 1 · 2 booked".
    private func dayTitle(_ day: Date) -> String {
        let name = day.formatted(Date.FormatStyle(locale: formatters.locale, calendar: formatters.calendar,
                                                  timeZone: formatters.timeZone)
            .weekday(.abbreviated).month(.abbreviated).day())
        let booked = viewModel.bookedCounts[day] ?? 0
        guard booked > 0 else { return name }
        let count = String(localized: LocalizedStringResource(
            "blockTime.day.booked", defaultValue: "\(booked) booked", locale: formatters.locale
        ))
        return "\(name) · \(count)"
    }
}
