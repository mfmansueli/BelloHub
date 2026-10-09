//
//  BreakSheet.swift
//  BelloHub
//

import SwiftUI

/// One recurring break: a name, the days it applies to (every day or one weekday) and its hours. New or edited; an
/// existing break can also be deleted here.
struct BreakSheet: View {
    /// The break's place in her list, or nil for a new one.
    let index: Int?
    let viewModel: AvailabilityViewModel
    let formatters: Formatters
    let weekdays: [Int]

    @State private var label: String
    @State private var weekday: Int?
    @State private var startMinutes: Int
    @State private var endMinutes: Int
    @State private var issue: AvailabilityIssue?
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    init(index: Int?, rule: BreakRule?, viewModel: AvailabilityViewModel, formatters: Formatters, weekdays: [Int]) {
        self.index = index
        self.viewModel = viewModel
        self.formatters = formatters
        self.weekdays = weekdays
        _label = State(initialValue: rule?.label ?? "")
        _weekday = State(initialValue: rule?.weekday)
        _startMinutes = State(initialValue: rule?.startMinutes ?? 12 * 60 + 30)
        _endMinutes = State(initialValue: rule?.endMinutes ?? 13 * 60 + 30)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if let message = viewModel.saveErrorMessage { ErrorNotice(message: message) }
                    BelloTextField(
                        title: "availability.breakSheet.name", text: $label,
                        prompt: "availability.breakSheet.namePrompt", identifier: "availability.breakSheet.nameField"
                    )
                    VStack(spacing: 0) {
                        appliesRow
                        Divider().overlay(Palette.hairline)
                        TimeOfDayRow(
                            title: "availability.stretch.from", minutes: $startMinutes, formatters: formatters,
                            identifier: "availability.breakSheet.from"
                        )
                        Divider().overlay(Palette.hairline)
                        TimeOfDayRow(
                            title: "availability.stretch.to", minutes: $endMinutes, formatters: formatters,
                            identifier: "availability.breakSheet.to"
                        )
                    }
                    .padding(.horizontal, Spacing.md)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                    if issue != nil {
                        Text("availability.breakSheet.error.order")
                            .font(Typography.footnote).foregroundStyle(Palette.coralText)
                            .accessibilityIdentifier("availability.breakSheet.error")
                    }
                    if let index { deleteButton(index) }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.vertical, Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.bg)
            .navigationTitle(Text(
                index == nil ? "availability.breakSheet.addTitle" : "availability.breakSheet.editTitle"
            ))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.cancel") }
                        .accessibilityIdentifier("availability.breakSheet.cancelButton")
                }
            }
            .safeAreaInset(edge: .bottom) { saveButton }
            .onDisappear { viewModel.dismissSaveError() }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Palette.bg)
    }

    // MARK: - Parts

    private var appliesRow: some View {
        HStack {
            Text("availability.breakSheet.applies").font(Typography.body).foregroundStyle(Palette.ink)
            Spacer(minLength: Spacing.sm)
            Picker(selection: $weekday) {
                Text("availability.breakSheet.everyDay").tag(Int?.none)
                ForEach(weekdays, id: \.self) { day in
                    Text(verbatim: formatters.weekdayName(day)).tag(Int?.some(day))
                }
            } label: {
                Text("availability.breakSheet.applies")
            }
            .pickerStyle(.menu)
            .tint(Palette.roseText)
            .accessibilityIdentifier("availability.breakSheet.appliesPicker")
        }
        .frame(minHeight: Spacing.touchTarget)
    }

    private func deleteButton(_ index: Int) -> some View {
        Button {
            Task {
                await viewModel.deleteBreak(at: index)
                if viewModel.saveErrorMessage == nil { dismiss() }
            }
        } label: { Text("availability.breakSheet.delete") }
            .buttonStyle(.belloDestructive)
            .accessibilityIdentifier("availability.breakSheet.deleteButton")
    }

    private var saveButton: some View {
        Button(action: save) {
            if isSaving { ProgressView() } else { Text("availability.breakSheet.save") }
        }
        .buttonStyle(.belloPrimary)
        .disabled(isSaving)
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
        .accessibilityIdentifier("availability.breakSheet.saveButton")
    }

    // MARK: - Actions

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        let rule = BreakRule(weekday: weekday, startMinutes: startMinutes, endMinutes: endMinutes, label: label)
        Task {
            let fallback = String(localized: "availability.break.defaultLabel", defaultValue: "Break")
            issue = await viewModel.saveBreak(rule, at: index, fallbackLabel: fallback)
            isSaving = false
            if issue == nil, viewModel.saveErrorMessage == nil { dismiss() }
        }
    }
}
