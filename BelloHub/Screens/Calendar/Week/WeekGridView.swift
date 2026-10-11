//
//  WeekGridView.swift
//  BelloHub
//

import SwiftUI

/// The week as a grid: seven day columns that share one hour scale. **This is the dense exception to the 44 pt rule**
/// (docs/03-BUILD-PLAN.md S6): a column is about 48 pt wide, so a visit shows only the client's first name. What makes
/// it usable: every visit is its own VoiceOver element with the day, time, client, service and status; a day heading
/// opens that day in the day view; and at accessibility text sizes the screen shows `WeekAgendaList` instead.
struct WeekGridView: View {
    let layouts: [CalendarDayLayout]
    let appointments: [Appointment]
    let clientName: (Appointment) -> String
    let now: Date
    let formatters: Formatters
    let hourHeight: CGFloat
    let onSelectDay: (Date) -> Void
    let onTapSlot: (Date) -> Void
    let onReschedule: (UUID) -> Void
    let onCancel: (UUID) -> Void

    private static let gutterWidth: CGFloat = 44

    private var text: CalendarVisitText { CalendarVisitText(formatters: formatters) }
    private var window: DateInterval? { layouts.first?.window }
    private var totalHeight: CGFloat {
        hourHeight * CGFloat((layouts.first?.window.duration ?? 0) / 3_600)
    }

    var body: some View {
        VStack(spacing: 0) {
            headings
            HStack(alignment: .top, spacing: 0) {
                gutter
                ForEach(layouts, id: \.day) { layout in column(layout) }
            }
            .motionRows(ids: layouts.flatMap { $0.visits.map(\.id) }, context: layouts.first?.day ?? Date.distantPast)
            .padding(.top, Spacing.sm)
        }
        .padding(.horizontal, Spacing.sm)
    }

    // MARK: - Parts

    private var headings: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: Self.gutterWidth, height: 1).accessibilityHidden(true)
            ForEach(layouts, id: \.day) { layout in
                let isToday = formatters.calendar.isDate(layout.day, inSameDayAs: now)
                Button { onSelectDay(layout.day) } label: {
                    VStack(spacing: Spacing.xxs) {
                        Text(verbatim: weekdayShort(layout.day)).font(Typography.caption).foregroundStyle(Palette.ink2)
                        Text(verbatim: formatters.number(formatters.calendar.component(.day, from: layout.day)))
                            .font(Typography.metaStrong)
                            .foregroundStyle(isToday ? Palette.selectionInk : Palette.ink)
                            .frame(minWidth: 28, minHeight: 28)
                            .background(isToday ? Palette.selectionFill : Color.clear, in: Circle())
                            .overlay { if isToday { Circle().strokeBorder(Palette.selectionInk, lineWidth: 1.5) } }
                    }
                    .frame(maxWidth: .infinity, minHeight: Spacing.touchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: headingLabel(layout)))
                .accessibilityAddTraits(.isHeader)
                .accessibilityHint(Text("calendar.week.dayHint"))
                .accessibilityIdentifier("calendar.week.day.\(formatters.calendar.component(.day, from: layout.day))")
            }
        }
    }

    private var gutter: some View {
        ZStack(alignment: .topTrailing) {
            ForEach(Array((layouts.first?.hourMarks ?? []).enumerated()), id: \.offset) { index, mark in
                Text(verbatim: formatters.time(mark))
                    .font(Typography.caption).foregroundStyle(Palette.ink2)
                    .minimumScaleFactor(0.7).lineLimit(1)
                    .padding(.trailing, Spacing.xs)
                    .offset(y: CGFloat(index) * hourHeight - 7)
            }
        }
        .frame(width: Self.gutterWidth, height: totalHeight, alignment: .topTrailing)
        .accessibilityHidden(true)
    }

    private func column(_ layout: CalendarDayLayout) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(layout.isClosed ? Palette.sunken : Color.clear)
                    .overlay(alignment: .leading) { Rectangle().fill(Palette.hairline).frame(width: 1) }
                    .contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { value in
                        onTapSlot(layout.time(atFraction: Double(value.location.y / max(totalHeight, 1))))
                    })
                    .accessibilityHidden(true)
                ForEach(layout.hourMarks.indices, id: \.self) { index in
                    Rectangle().fill(Palette.hairline).frame(height: 1)
                        .offset(y: CGFloat(index) * hourHeight).allowsHitTesting(false).accessibilityHidden(true)
                }
                ForEach(layout.bands) { band in
                    Rectangle().fill(Palette.neutralWash)
                        .frame(height: max(height(of: band.interval, in: layout), 1))
                        .offset(y: y(band.interval.start, in: layout))
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
                ForEach(layout.visits) { placed in visit(placed, in: layout, width: proxy.size.width) }
                if layout.window.contains(now) {
                    Rectangle().fill(Palette.roseText).frame(height: 2)
                        .offset(y: y(now, in: layout)).motionSettle(y(now, in: layout))
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: totalHeight)
    }

    @ViewBuilder
    private func visit(_ placed: CalendarDayLayout.Visit, in layout: CalendarDayLayout, width: CGFloat) -> some View {
        if let appointment = appointments.first(where: { $0.id == placed.id }) {
            let columnWidth = width / CGFloat(placed.columnCount)
            VisitBlock(
                appointment: appointment, clientName: clientName(appointment), density: .compact, text: text,
                onReschedule: { onReschedule(appointment.id) }, onCancel: { onCancel(appointment.id) }
            )
            .frame(width: max(columnWidth - 2, 0), height: max(height(of: placed.interval, in: layout), 22))
            .offset(x: columnWidth * CGFloat(placed.column) + 1, y: y(placed.interval.start, in: layout))
            .motionSettle([columnWidth * CGFloat(placed.column), y(placed.interval.start, in: layout), columnWidth,
                           height(of: placed.interval, in: layout)])
            .motionRow()
        }
    }

    // MARK: - Helpers

    private func y(_ date: Date, in layout: CalendarDayLayout) -> CGFloat {
        CGFloat(layout.fraction(of: date)) * totalHeight
    }

    private func height(of interval: DateInterval, in layout: CalendarDayLayout) -> CGFloat {
        y(interval.end, in: layout) - y(interval.start, in: layout)
    }

    private func weekdayShort(_ day: Date) -> String {
        day.formatted(Date.FormatStyle(locale: formatters.locale, calendar: formatters.calendar,
                                       timeZone: formatters.timeZone).weekday(.abbreviated))
    }

    /// "Wednesday, September 30, 3 visits": the heading VoiceOver reads for a column.
    private func headingLabel(_ layout: CalendarDayLayout) -> String {
        let count = layout.visits.count
        let visits = String(localized: LocalizedStringResource(
            "calendar.week.visitCount", defaultValue: "\(count) visits", locale: formatters.locale
        ))
        return "\(formatters.weekdayDayMonth(layout.day)), \(visits)"
    }
}
