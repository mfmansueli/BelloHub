//
//  BookingRulesSection.swift
//  BelloHub
//

import SwiftUI

/// "Booking rules" on the booking page settings, organized progressively (routine item 10): first the suggestion for
/// her profession when her values differ from it, then the basics (her hours, time between clients, minimum notice,
/// booking window, cancellation rules, no-show protection), then "More options", a native disclosure with the start
/// times and "Keep my day compact" (D56), open by itself only when one of them is not at its default. Every menu
/// explains itself with an example from her routine. The menus and the switch change her availability; the two doors
/// push the policy screens, handing them the editor the settings screen shares with them.
struct BookingRulesSection: View {
    let viewModel: BookingSettingsViewModel

    @State private var showsMoreOptions = false
    @Environment(\.locale) private var locale

    private var formatters: Formatters {
        Formatters(locale: locale, timeZone: viewModel.timeZone, currencyCode: "EUR")
    }

    private var availability: AvailabilitySettings { viewModel.availability }

    var body: some View {
        SettingsSection(title: "bookingSettings.section.rules") {
            if let suggestion = viewModel.professionSuggestion {
                ProfessionSuggestionCard(
                    professionName: viewModel.professionName, defaults: suggestion.defaults,
                    formatters: formatters, onUse: { Task { await viewModel.useSuggestedDefaults() } }
                )
            }
            ListCard(dividerInset: Spacing.md) {
                availabilityRow
                bufferRow
                noticeRow
                windowRow
                cancelRow
                noShowRow
            }
            moreOptions
        }
        .task(id: viewModel.hasLoaded) {
            if viewModel.hasAdvancedChanges { showsMoreOptions = true }
        }
    }

    /// The start times and the compact day: useful, but most people never need to touch them.
    private var moreOptions: some View {
        DisclosureGroup(isExpanded: $showsMoreOptions) {
            ListCard(dividerInset: Spacing.md) {
                slotStepRow
                compactRow
            }
            .padding(.top, Spacing.sm)
        } label: {
            Text("bookingSettings.rules.moreOptions")
                .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                .frame(minHeight: Spacing.touchTarget, alignment: .leading)
                // On the label: on the group it would also rename every row inside it.
                .accessibilityIdentifier("bookingSettings.moreOptions")
        }
        .tint(Palette.roseText)
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
            label: bufferLabel, identifier: "bookingSettings.bufferPicker", hint: "bookingSettings.rules.bufferExample"
        )
    }

    private var slotStepRow: some View {
        MenuPickerRow(
            title: "bookingSettings.rules.slotStep",
            selection: Binding(
                get: { availability.effectiveSlotStep }, set: { value in Task { await viewModel.setSlotStep(value) } }
            ),
            options: AvailabilitySettings.slotStepChoices(including: availability.effectiveSlotStep),
            label: slotStepLabel, identifier: "bookingSettings.slotStepPicker",
            hint: "bookingSettings.rules.slotStepExample"
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
            label: noticeLabel, identifier: "bookingSettings.noticePicker", hint: "bookingSettings.rules.noticeExample"
        )
    }

    private var windowRow: some View {
        MenuPickerRow(
            title: "bookingSettings.rules.window",
            selection: Binding(
                get: { availability.maxDaysAhead }, set: { value in Task { await viewModel.setMaxDaysAhead(value) } }
            ),
            options: viewModel.options(AvailabilityEditor.windowOptions, including: availability.maxDaysAhead),
            label: windowLabel, identifier: "bookingSettings.windowPicker", hint: "bookingSettings.rules.windowExample"
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
