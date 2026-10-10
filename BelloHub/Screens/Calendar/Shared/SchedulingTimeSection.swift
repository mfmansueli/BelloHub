//
//  SchedulingTimeSection.swift
//  BelloHub
//

import SwiftUI

/// The day and the time of a visit, for New appointment and Reschedule: the day (a date picker, or chips for the days
/// that have room), the free start times as chips and, when none fits, a time picker for any minute. A chip is a
/// button with the selected trait, so VoiceOver says which time is chosen. With "Keep my day compact" (D56) the chips
/// are the suggested times and "Show all times" reveals the other free ones in place. The views own nothing: the
/// ViewModel answers `onSelect…`.
struct SchedulingTimeSection: View {
    let idPrefix: String
    let formatters: Formatters
    let day: Date
    let start: Date?
    let slots: [Date]
    /// The other free times (D56), revealed by "Show all times".
    var moreSlots: [Date] = []
    /// When set, the days are chips instead of a date picker.
    var offeredDays: [Date]?
    let onSelectDay: (Date) -> Void
    let onSelectStart: (Date) -> Void
    let onSelectMinutes: (Int) -> Void

    @State private var showsCustomTime = false
    @State private var showsAllTimes = false

    private static let shownSlotLimit = 12

    /// The free times, plus the chosen one when it is not among them (a tap on the calendar, or a typed time). All of
    /// them once she asked for all times.
    private var chips: [Date] {
        var shown = showsAllTimes ? (slots + moreSlots).sorted() : Array(slots.prefix(Self.shownSlotLimit))
        if let start, !shown.contains(start), formatters.calendar.isDate(start, inSameDayAs: day) {
            shown.append(start)
            shown.sort()
        }
        return shown
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            dayPicker
            if chips.isEmpty {
                Text("scheduling.time.noSlots")
                    .font(Typography.meta).foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("\(idPrefix).noSlots")
            } else {
                FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm) {
                    ForEach(Array(chips.enumerated()), id: \.element) { index, slot in
                        Button { onSelectStart(slot) } label: { Text(verbatim: formatters.time(slot)) }
                            .buttonStyle(.belloChip(selected: slot == start))
                            .accessibilityAddTraits(slot == start ? .isSelected : [])
                            .accessibilityIdentifier("\(idPrefix).slot.\(index)")
                    }
                }
            }
            if !showsAllTimes, !moreSlots.isEmpty { showAllButton }
            customTime
        }
        .onChange(of: day) { showsAllTimes = false }
    }

    private var showAllButton: some View {
        Button { showsAllTimes = true } label: {
            Text("scheduling.time.showAll")
                .font(Typography.metaStrong).foregroundStyle(Palette.roseText)
                .frame(minHeight: Spacing.touchTarget, alignment: .leading)
        }
        .accessibilityHint(Text("scheduling.time.showAllHint"))
        .accessibilityIdentifier("\(idPrefix).showAllTimesButton")
    }

    // MARK: - Parts

    @ViewBuilder
    private var dayPicker: some View {
        if let offeredDays {
            if offeredDays.isEmpty {
                Text("scheduling.time.noDays")
                    .font(Typography.meta).foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("\(idPrefix).noDays")
            } else {
                FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm) {
                    ForEach(Array(offeredDays.enumerated()), id: \.element) { index, offered in
                        Button { onSelectDay(offered) } label: { Text(verbatim: dayTitle(offered)) }
                            .buttonStyle(.belloChip(selected: formatters.calendar.isDate(offered, inSameDayAs: day)))
                            .accessibilityAddTraits(
                                formatters.calendar.isDate(offered, inSameDayAs: day) ? .isSelected : []
                            )
                            .accessibilityIdentifier("\(idPrefix).day.\(index)")
                    }
                }
            }
        } else {
            DatePicker(
                selection: Binding(get: { day }, set: { onSelectDay($0) }), displayedComponents: .date
            ) {
                Text("scheduling.time.date").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
            }
            .environment(\.timeZone, formatters.timeZone)
            .environment(\.calendar, formatters.calendar)
            .frame(minHeight: Spacing.touchTarget)
            .accessibilityIdentifier("\(idPrefix).datePicker")
        }
    }

    private var customTime: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button { showsCustomTime.toggle() } label: {
                Text("scheduling.time.another")
                    .font(Typography.metaStrong).foregroundStyle(Palette.roseText)
                    .frame(minHeight: Spacing.touchTarget, alignment: .leading)
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("\(idPrefix).anotherTimeButton")
            if showsCustomTime {
                DatePicker(
                    selection: Binding(
                        get: { start ?? formatters.timeOfDay(minutes: 9 * 60) },
                        set: { onSelectMinutes(formatters.minutesOfDay($0)) }
                    ),
                    displayedComponents: .hourAndMinute
                ) {
                    Text("scheduling.time.time").font(Typography.body).foregroundStyle(Palette.ink)
                }
                .environment(\.timeZone, formatters.timeZone)
                .environment(\.calendar, formatters.calendar)
                .frame(minHeight: Spacing.touchTarget)
                .accessibilityIdentifier("\(idPrefix).timePicker")
            }
        }
    }

    /// "Thu, Oct 1".
    private func dayTitle(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: formatters.locale, calendar: formatters.calendar,
                                        timeZone: formatters.timeZone).weekday(.abbreviated).month(.abbreviated).day())
    }
}
