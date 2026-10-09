//
//  DayHoursSheet.swift
//  BelloHub
//

import SwiftUI

/// The hours of one weekday: one stretch, or several (a morning and an evening). Edits are drafts; Save checks them
/// with `AvailabilityEditor` and the sheet closes only when they were accepted.
struct DayHoursSheet: View {
    let weekday: Int
    let viewModel: AvailabilityViewModel
    let formatters: Formatters

    @State private var drafts: [StretchDraft]
    @State private var issue: AvailabilityIssue?
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    init(weekday: Int, viewModel: AvailabilityViewModel, formatters: Formatters) {
        self.weekday = weekday
        self.viewModel = viewModel
        self.formatters = formatters
        let stored = AvailabilityEditor.stretches(for: weekday, in: viewModel.settings)
        _drafts = State(initialValue: stored.map {
            StretchDraft(startMinutes: $0.startMinutes, endMinutes: $0.endMinutes)
        })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    if let message = viewModel.saveErrorMessage { ErrorNotice(message: message) }
                    ForEach($drafts) { $draft in
                        stretchCard($draft)
                    }
                    if drafts.count < AvailabilityEditor.maxStretchesPerDay { addButton }
                    if let issue {
                        Text(issueText(issue))
                            .font(Typography.footnote).foregroundStyle(Palette.coralText)
                            .accessibilityIdentifier("availability.hoursSheet.error")
                    }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.vertical, Spacing.md)
            }
            .background(Palette.bg)
            .navigationTitle(Text(verbatim: formatters.weekdayName(weekday)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.cancel") }
                        .accessibilityIdentifier("availability.hoursSheet.cancelButton")
                }
            }
            .safeAreaInset(edge: .bottom) { saveButton }
            .onDisappear { viewModel.dismissSaveError() }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Palette.bg)
    }

    // MARK: - Parts

    private func stretchCard(_ draft: Binding<StretchDraft>) -> some View {
        let index = drafts.firstIndex { $0.id == draft.wrappedValue.id } ?? 0
        return VStack(spacing: 0) {
            TimeOfDayRow(
                title: "availability.stretch.from", minutes: draft.startMinutes, formatters: formatters,
                identifier: "availability.hoursSheet.from.\(index)"
            )
            Divider().overlay(Palette.hairline)
            TimeOfDayRow(
                title: "availability.stretch.to", minutes: draft.endMinutes, formatters: formatters,
                identifier: "availability.hoursSheet.to.\(index)"
            )
            if drafts.count > 1 {
                Divider().overlay(Palette.hairline)
                Button(role: .destructive) { drafts.removeAll { $0.id == draft.wrappedValue.id } } label: {
                    Text("availability.stretch.remove").font(Typography.metaStrong).foregroundStyle(Palette.coralText)
                        .frame(maxWidth: .infinity, minHeight: Spacing.touchTarget, alignment: .leading)
                }
                .accessibilityIdentifier("availability.hoursSheet.remove.\(index)")
            }
        }
        .padding(.horizontal, Spacing.md)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
    }

    private var addButton: some View {
        Button {
            let last = drafts.map(\.endMinutes).max() ?? AvailabilityEditor.defaultStretch.start
            let start = min(last + 60, 23 * 60)
            drafts.append(StretchDraft(startMinutes: start, endMinutes: min(start + 120, 24 * 60)))
        } label: {
            HStack(spacing: Spacing.row) {
                Image(icon: .plus).font(.system(size: 17, weight: .semibold)).accessibilityHidden(true)
                Text("availability.stretch.add").font(Typography.bodyStrong)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Palette.roseText)
            .frame(minHeight: Spacing.touchTarget)
        }
        .accessibilityIdentifier("availability.hoursSheet.addButton")
    }

    private var saveButton: some View {
        Button(action: save) {
            if isSaving { ProgressView() } else { Text("availability.hoursSheet.save") }
        }
        .buttonStyle(.belloPrimary)
        .disabled(isSaving || drafts.isEmpty)
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
        .accessibilityIdentifier("availability.hoursSheet.saveButton")
    }

    private func issueText(_ issue: AvailabilityIssue) -> LocalizedStringKey {
        switch issue {
        case .order: "availability.stretch.error.order"
        case .tooShort: "availability.stretch.error.short"
        case .overlap: "availability.stretch.error.overlap"
        }
    }

    // MARK: - Actions

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        Task {
            issue = await viewModel.saveStretches(of: weekday, drafts)
            isSaving = false
            if issue == nil, viewModel.saveErrorMessage == nil { dismiss() }
        }
    }
}
