//
//  CalendarHeader.swift
//  BelloHub
//

import SwiftUI

/// The top of the Calendar tab: the date (a native compact date picker, which is also the way to jump to any day),
/// previous and next, "Today", the Day/Week control and, in the day mode, the week strip.
struct CalendarHeader: View {
    @Binding var mode: CalendarViewModel.Mode
    let selectedDay: Date
    let weekDays: [Date]
    let now: Date
    let formatters: Formatters
    let onSelectDay: (Date) -> Void
    let onStep: (Bool) -> Void
    let onToday: () -> Void

    private var isOnToday: Bool {
        formatters.calendar.isDate(selectedDay, inSameDayAs: now)
            && (mode == .day || weekDays.contains { formatters.calendar.isDate($0, inSameDayAs: now) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            dateRow
            Picker(selection: $mode) {
                Text("calendar.mode.day").tag(CalendarViewModel.Mode.day)
                Text("calendar.mode.week").tag(CalendarViewModel.Mode.week)
            } label: { Text("calendar.mode.label") }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("calendar.modePicker")
            if mode == .day { weekStrip }
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Parts

    private var dateRow: some View {
        HStack(spacing: Spacing.sm) {
            DatePicker(
                selection: Binding(get: { selectedDay }, set: { onSelectDay($0) }), displayedComponents: .date
            ) { Text("calendar.date.label") }
            .labelsHidden()
            .environment(\.timeZone, formatters.timeZone)
            .environment(\.calendar, formatters.calendar)
            .frame(minHeight: Spacing.touchTarget)
            .accessibilityIdentifier("calendar.datePicker")
            Spacer(minLength: Spacing.sm)
            if !isOnToday {
                Button(action: onToday) {
                    Text("calendar.today").font(Typography.metaStrong).foregroundStyle(Palette.roseText)
                        .frame(minHeight: Spacing.touchTarget)
                }
                .accessibilityIdentifier("calendar.todayButton")
            }
            stepButton(forward: false)
            stepButton(forward: true)
        }
    }

    private func stepButton(forward: Bool) -> some View {
        Button { onStep(forward) } label: {
            Image(icon: forward ? .forward : .back)
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                .background(Palette.sunken, in: Circle())
        }
        .accessibilityLabel(stepLabel(forward: forward))
        .accessibilityIdentifier(forward ? "calendar.nextButton" : "calendar.previousButton")
    }

    private func stepLabel(forward: Bool) -> Text {
        switch (mode, forward) {
        case (.day, false): Text("calendar.nav.previousDay")
        case (.day, true): Text("calendar.nav.nextDay")
        case (.week, false): Text("calendar.nav.previousWeek")
        case (.week, true): Text("calendar.nav.nextWeek")
        }
    }

    private var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { day in
                let isSelected = formatters.calendar.isDate(day, inSameDayAs: selectedDay)
                let isToday = formatters.calendar.isDate(day, inSameDayAs: now)
                Button { onSelectDay(day) } label: {
                    VStack(spacing: Spacing.xs) {
                        Text(verbatim: weekdayShort(day)).font(Typography.footnote).foregroundStyle(Palette.ink2)
                        Text(verbatim: formatters.number(formatters.calendar.component(.day, from: day)))
                            .font(Typography.bodyStrong)
                            .foregroundStyle(numberColor(isSelected: isSelected, isToday: isToday))
                            .frame(minWidth: 36, minHeight: 36)
                            .background(isSelected ? Palette.selectionFill : Color.clear, in: Circle())
                            // The ring carries the state: the selection fill alone is 1.4:1 on the page in light.
                            .overlay { if isSelected { Circle().strokeBorder(Palette.selectionInk, lineWidth: 1.5) } }
                    }
                    .frame(maxWidth: .infinity, minHeight: Spacing.touchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: formatters.weekdayDayMonth(day)))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("calendar.stripDay.\(formatters.calendar.component(.day, from: day))")
            }
        }
    }

    private func numberColor(isSelected: Bool, isToday: Bool) -> Color {
        if isSelected { return Palette.selectionInk }
        return isToday ? Palette.roseText : Palette.ink
    }

    private func weekdayShort(_ day: Date) -> String {
        day.formatted(Date.FormatStyle(locale: formatters.locale, calendar: formatters.calendar,
                                       timeZone: formatters.timeZone).weekday(.abbreviated))
    }
}
