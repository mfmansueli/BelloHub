//
//  PauseSheet.swift
//  BelloHub
//

import SwiftUI

/// Pausing the booking page: what a pause does, an optional return date and the button that pauses. The switch on the
/// settings screen only flips when she confirms here, so a stray tap never closes her page. Without a date the pause
/// lasts until she opens bookings again.
struct PauseSheet: View {
    let viewModel: BookingSettingsViewModel
    let formatters: Formatters

    @State private var choosesDate = false
    @State private var returnDate: Date
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    init(viewModel: BookingSettingsViewModel, formatters: Formatters) {
        self.viewModel = viewModel
        self.formatters = formatters
        let earliest = viewModel.earliestReturnDate
        let week = formatters.calendar.date(byAdding: .day, value: 7, to: earliest) ?? earliest
        _returnDate = State(initialValue: week)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text("bookingSettings.pauseSheet.message").font(Typography.body).foregroundStyle(Palette.ink2)
                    if let message = viewModel.saveErrorMessage { ErrorNotice(message: message) }
                    VStack(spacing: 0) {
                        Toggle(isOn: $choosesDate) {
                            Text("bookingSettings.pauseSheet.chooseDate").font(Typography.bodyStrong)
                                .foregroundStyle(Palette.ink)
                        }
                        .tint(Palette.sage)
                        .frame(minHeight: 56)
                        .accessibilityIdentifier("bookingSettings.pauseSheet.dateSwitch")
                        if choosesDate {
                            Divider().overlay(Palette.hairline)
                            DatePicker(
                                selection: $returnDate, in: viewModel.earliestReturnDate..., displayedComponents: .date
                            ) {
                                Text("bookingSettings.backOn").font(Typography.body).foregroundStyle(Palette.ink)
                            }
                            .environment(\.timeZone, formatters.timeZone)
                            .environment(\.calendar, formatters.calendar)
                            .frame(minHeight: Spacing.touchTarget)
                            .accessibilityIdentifier("bookingSettings.pauseSheet.datePicker")
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.vertical, Spacing.md)
            }
            .background(Palette.bg)
            .navigationTitle(Text("bookingSettings.pauseSheet.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.cancel") }
                        .accessibilityIdentifier("bookingSettings.pauseSheet.cancelButton")
                }
            }
            .safeAreaInset(edge: .bottom) { confirmButton }
            .onDisappear { viewModel.dismissSaveError() }
        }
        .presentationDetents([.large])
        .presentationBackground(Palette.bg)
    }

    private var confirmButton: some View {
        Button {
            guard !isSaving else { return }
            isSaving = true
            Task {
                await viewModel.pause(until: choosesDate ? returnDate : nil)
                isSaving = false
                if viewModel.saveErrorMessage == nil { dismiss() }
            }
        } label: {
            if isSaving { ProgressView() } else { Text("bookingSettings.pauseSheet.confirm") }
        }
        .buttonStyle(.belloPrimary)
        .disabled(isSaving)
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
        .accessibilityIdentifier("bookingSettings.pauseSheet.confirmButton")
    }
}
