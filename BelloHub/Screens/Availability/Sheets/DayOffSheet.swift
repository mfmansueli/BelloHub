//
//  DayOffSheet.swift
//  BelloHub
//

import SwiftUI

/// Days she is closed: a kind (day off, vacation, blocked) and the first and last day. Visits already booked on those
/// days are not moved (the note says so); the calendar's "block days" with its cancel-or-invite choice is S6.
struct DayOffSheet: View {
    let dayOff: DayOff?
    let viewModel: AvailabilityViewModel
    let formatters: Formatters
    let today: Date

    @State private var kind: DayOffKind
    @State private var firstDay: Date
    @State private var lastDay: Date
    @State private var issue: AvailabilityIssue?
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(dayOff: DayOff?, viewModel: AvailabilityViewModel, formatters: Formatters, today: Date) {
        self.dayOff = dayOff
        self.viewModel = viewModel
        self.formatters = formatters
        self.today = today
        _kind = State(initialValue: dayOff?.kind ?? .dayOff)
        _firstDay = State(initialValue: dayOff?.startDate ?? today)
        _lastDay = State(initialValue: dayOff?.endDate ?? today)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    if let message = viewModel.saveErrorMessage { ErrorNotice(message: message) }
                    VStack(spacing: 0) {
                        kindRow
                        Divider().overlay(Palette.hairline)
                        dayRow("availability.dayOffSheet.from", $firstDay, identifier: "availability.dayOffSheet.from")
                        Divider().overlay(Palette.hairline)
                        dayRow("availability.dayOffSheet.to", $lastDay, identifier: "availability.dayOffSheet.to")
                    }
                    .padding(.horizontal, Spacing.md)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                    if issue != nil {
                        Text("availability.dayOffSheet.error.order")
                            .font(Typography.footnote).foregroundStyle(Palette.coralText)
                            .accessibilityIdentifier("availability.dayOffSheet.error")
                    }
                    FooterNote(text: "availability.dayOffSheet.note", icon: .info)
                    if let dayOff { deleteButton(dayOff) }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.vertical, Spacing.md)
            }
            .background(Palette.bg)
            .navigationTitle(Text(
                dayOff == nil ? "availability.dayOffSheet.addTitle" : "availability.dayOffSheet.editTitle"
            ))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.cancel") }
                        .accessibilityIdentifier("availability.dayOffSheet.cancelButton")
                }
            }
            .safeAreaInset(edge: .bottom) { saveButton }
            .onChange(of: firstDay) { _, new in if lastDay < new { lastDay = new } }
            .onDisappear { viewModel.dismissSaveError() }
        }
        .presentationDetents([.large])
        .presentationBackground(Palette.bg)
    }

    // MARK: - Parts

    private var kindRow: some View {
        HStack {
            Text("availability.dayOffSheet.kind").font(Typography.body).foregroundStyle(Palette.ink)
            Spacer(minLength: Spacing.sm)
            Picker(selection: $kind) {
                ForEach(DayOffKind.allCases, id: \.self) { option in
                    Text(option.name.localized(in: locale)).tag(option)
                }
            } label: {
                Text("availability.dayOffSheet.kind")
            }
            .pickerStyle(.menu)
            .tint(Palette.roseText)
            .accessibilityIdentifier("availability.dayOffSheet.kindPicker")
        }
        .frame(minHeight: Spacing.touchTarget)
    }

    private func dayRow(_ title: LocalizedStringKey, _ date: Binding<Date>, identifier: String) -> some View {
        DatePicker(selection: date, in: min(today, dayOff?.startDate ?? today)..., displayedComponents: .date) {
            Text(title).font(Typography.body).foregroundStyle(Palette.ink)
        }
        .environment(\.timeZone, formatters.timeZone)
        .environment(\.calendar, formatters.calendar)
        .frame(minHeight: Spacing.touchTarget)
        .accessibilityIdentifier(identifier)
    }

    private func deleteButton(_ dayOff: DayOff) -> some View {
        Button {
            Task {
                await viewModel.deleteDayOff(id: dayOff.id)
                if viewModel.saveErrorMessage == nil { dismiss() }
            }
        } label: { Text("availability.dayOffSheet.delete") }
            .buttonStyle(.belloDestructive)
            .accessibilityIdentifier("availability.dayOffSheet.deleteButton")
    }

    private var saveButton: some View {
        Button(action: save) {
            if isSaving { ProgressView() } else { Text("availability.dayOffSheet.save") }
        }
        .buttonStyle(.belloPrimary)
        .disabled(isSaving)
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
        .accessibilityIdentifier("availability.dayOffSheet.saveButton")
    }

    // MARK: - Actions

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        let value = DayOff(id: dayOff?.id ?? UUID(), startDate: firstDay, endDate: lastDay, kind: kind)
        Task {
            issue = await viewModel.saveDayOff(value)
            isSaving = false
            if issue == nil, viewModel.saveErrorMessage == nil { dismiss() }
        }
    }
}
