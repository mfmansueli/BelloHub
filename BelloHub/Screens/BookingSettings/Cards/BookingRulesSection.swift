//
//  BookingRulesSection.swift
//  BelloHub
//

import SwiftUI

/// "Booking rules" on the booking page settings: the door to her hours with their summary, the buffer, slot interval,
/// minimum notice and booking window menus, the "Keep my day compact" switch (D56), and the doors to her cancellation rules and her no-show protection, each with its
/// one-line summary. The three menus change her availability; the two doors push the policy screens, handing them the
/// editor the settings screen shares with them.
struct BookingRulesSection: View {
    let viewModel: BookingSettingsViewModel

    @Environment(\.locale) private var locale

    private var formatters: Formatters {
        Formatters(locale: locale, timeZone: viewModel.timeZone, currencyCode: "EUR")
    }

    private var availability: AvailabilitySettings { viewModel.availability }

    var body: some View {
        SettingsSection(title: "bookingSettings.section.rules") {
            ListCard(dividerInset: Spacing.md) {
                availabilityRow
                bufferRow
                slotStepRow
                compactRow
                noticeRow
                windowRow
                cancelRow
                noShowRow
            }
        }
    }

    // MARK: - Rows

    private var availabilityRow: some View {
        NavigationLink(value: MoreRoute.availability) {
            MoreRow(
                icon: .clock, tint: .sage, title: Text("bookingSettings.rules.availability"),
                subtitle: Text(verbatim: availabilitySummary), showsChevron: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("bookingSettings.availabilityRow")
    }

    private var bufferRow: some View {
        MenuPickerRow(
            title: "bookingSettings.rules.buffer",
            selection: Binding(
                get: { availability.bufferMinutes }, set: { value in Task { await viewModel.setBuffer(value) } }
            ),
            options: viewModel.options(AvailabilityEditor.bufferOptions, including: availability.bufferMinutes),
            label: bufferLabel, identifier: "bookingSettings.bufferPicker"
        )
    }

    private var slotStepRow: some View {
        MenuPickerRow(
            title: "bookingSettings.rules.slotStep",
            selection: Binding(
                get: { availability.effectiveSlotStep }, set: { value in Task { await viewModel.setSlotStep(value) } }
            ),
            options: AvailabilitySettings.slotStepChoices(including: availability.effectiveSlotStep),
            label: slotStepLabel, identifier: "bookingSettings.slotStepPicker"
        )
    }

    private var compactRow: some View {
        ToggleRow(
            title: LocalizedStringResource("bookingSettings.rules.compact").resolved(in: locale),
            subtitle: LocalizedStringResource("bookingSettings.rules.compactHint").resolved(in: locale),
            isOn: Binding(
                get: { availability.keepsDayCompact }, set: { value in Task { await viewModel.setCompactDay(value) } }
            ),
            identifier: "bookingSettings.compactToggle"
        )
    }

    private var noticeRow: some View {
        MenuPickerRow(
            title: "bookingSettings.rules.notice",
            selection: Binding(
                get: { availability.minNoticeHours },
                set: { value in Task { await viewModel.setMinNoticeHours(value) } }
            ),
            options: viewModel.options(AvailabilityEditor.minNoticeOptions, including: availability.minNoticeHours),
            label: noticeLabel, identifier: "bookingSettings.noticePicker"
        )
    }

    private var windowRow: some View {
        MenuPickerRow(
            title: "bookingSettings.rules.window",
            selection: Binding(
                get: { availability.maxDaysAhead }, set: { value in Task { await viewModel.setMaxDaysAhead(value) } }
            ),
            options: viewModel.options(AvailabilityEditor.windowOptions, including: availability.maxDaysAhead),
            label: windowLabel, identifier: "bookingSettings.windowPicker"
        )
    }

    private var cancelRow: some View {
        NavigationLink {
            CancelPolicyView(
                editor: viewModel.editor, localization: viewModel.localization,
                professionalName: viewModel.professionalName
            )
        } label: {
            MoreRow(
                icon: .repeatArrows, tint: .peach, title: Text("bookingSettings.rules.cancel"),
                subtitle: Text(BookingSetupSummary.cancellation(viewModel.setup.cancellation, formatters: formatters)),
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("bookingSettings.cancelRow")
    }

    private var noShowRow: some View {
        NavigationLink {
            NoShowPolicyView(
                editor: viewModel.editor, localization: viewModel.localization,
                professionalName: viewModel.professionalName
            )
        } label: {
            MoreRow(
                icon: .shield, tint: .rose, title: Text("bookingSettings.rules.noShow"),
                subtitle: Text(BookingSetupSummary.noShow(viewModel.setup.noShow).localized(in: locale)),
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("bookingSettings.noShowRow")
    }

    // MARK: - Words

    private var availabilitySummary: String {
        AvailabilityText(formatters: formatters, firstWeekday: viewModel.firstWeekday).weekSummary(of: availability)
    }

    private func bufferLabel(_ minutes: Int) -> String {
        guard minutes > 0 else { return LocalizedStringResource("availability.buffer.none").resolved(in: locale) }
        return formatters.minutes(minutes)
    }

    private func slotStepLabel(_ minutes: Int) -> String {
        guard minutes > 0 else {
            return LocalizedStringResource("bookingSettings.slotStep.matchService").resolved(in: locale)
        }
        return LocalizedStringResource("bookingSettings.slotStep.every", defaultValue: "Every \(minutes) min")
            .resolved(in: locale)
    }

    private func noticeLabel(_ hours: Int) -> String {
        guard hours > 0 else { return LocalizedStringResource("bookingSettings.notice.none").resolved(in: locale) }
        return LocalizedStringResource("bookingSettings.notice.hours", defaultValue: "\(hours) hours")
            .resolved(in: locale)
    }

    private func windowLabel(_ days: Int) -> String {
        LocalizedStringResource("bookingSettings.window.days", defaultValue: "\(days) days ahead")
            .resolved(in: locale)
    }
}
