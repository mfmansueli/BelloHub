//
//  DayTimelineView.swift
//  BelloHub
//

import SwiftUI

/// One day as a timeline: hour labels on the leading side, hour lines, her breaks and blocks, the visits in columns
/// where they overlap, and the current-time marker. It is the **accessible default**: every size is a multiple of
/// `hourHeight` (which grows with Dynamic Type), every visit is at least 44 pt tall, and each hour is a button that
/// says "Add an appointment at 10:00", so VoiceOver reaches a free time without the grid.
struct DayTimelineView: View {
    let layout: CalendarDayLayout
    let appointments: [Appointment]
    let blocks: [TimeBlock]
    let clientName: (Appointment) -> String
    let now: Date
    let formatters: Formatters
    let hourHeight: CGFloat
    let onTapSlot: (Date) -> Void
    let onReschedule: (UUID) -> Void
    let onCancel: (UUID) -> Void
    let onRemoveBlock: (UUID) -> Void

    private static let gutterWidth: CGFloat = 60
    private static let columnGap: CGFloat = 4

    private var text: CalendarVisitText { CalendarVisitText(formatters: formatters) }
    private var totalHeight: CGFloat { hourHeight * CGFloat(layout.window.duration / 3_600) }

    private func y(_ date: Date) -> CGFloat { CGFloat(layout.fraction(of: date)) * totalHeight }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            gutter
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    hourRows
                    ForEach(layout.bands) { band in bandView(band, width: proxy.size.width) }
                    ForEach(layout.visits) { placed in visitView(placed, width: proxy.size.width) }
                    if layout.window.contains(now) { nowMarker }
                }
                // A visit that is booked, confirmed, cancelled or removed enters from above or leaves; one that is
                // moved glides to its slot. The first day shown never animates (docs/09-MOTION.md section 3.10).
                .motionRows(ids: layout.visits.map { $0.id.uuidString } + layout.bands.map(\.id), context: layout.day)
            }
            .frame(height: totalHeight)
        }
        .padding(.trailing, Spacing.gutter)
        .padding(.leading, Spacing.sm)
    }

    // MARK: - Parts

    private var gutter: some View {
        ZStack(alignment: .topTrailing) {
            ForEach(Array(layout.hourMarks.enumerated()), id: \.offset) { index, mark in
                Text(verbatim: formatters.time(mark))
                    .font(Typography.footnote).foregroundStyle(Palette.ink2)
                    .padding(.trailing, Spacing.sm)
                    .offset(y: CGFloat(index) * hourHeight - 8)
            }
        }
        .frame(width: Self.gutterWidth, height: totalHeight, alignment: .topTrailing)
        .accessibilityHidden(true)
    }

    /// One row per hour, each a button. Real stacked rows (not offsets), so the screen can scroll to an hour by id.
    private var hourRows: some View {
        VStack(spacing: 0) {
            ForEach(Array(layout.hourMarks.enumerated()), id: \.offset) { index, mark in
                let top = CGFloat(index) * hourHeight
                Color.clear
                    .frame(height: hourHeight)
                    .overlay(alignment: .top) { Rectangle().fill(Palette.hairline).frame(height: 1) }
                    .contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { value in
                        onTapSlot(layout.time(atFraction: Double((top + value.location.y) / totalHeight)))
                    })
                    .id("calendar.hour.\(index)")
                    .accessibilityElement()
                    .accessibilityLabel(Text(verbatim: text.addLabel(at: mark)))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { onTapSlot(mark) }
                    .accessibilityIdentifier("calendar.slot.\(formatters.calendar.component(.hour, from: mark))")
            }
        }
    }

    private func bandView(_ band: CalendarDayLayout.Band, width: CGFloat) -> some View {
        let height = max(y(band.interval.end) - y(band.interval.start), Spacing.touchTarget)
        return Group {
            switch band.kind {
            case .breakTime(let label):
                bandBody(Text(verbatim: "\(label) · \(spanText(band.interval))"), fill: Palette.sunken)
            case .blocked(let id):
                Button { onRemoveBlock(id) } label: {
                    bandBody(
                        blockedText(id, interval: band.interval), fill: Palette.neutralWash,
                        foreground: Palette.neutralText
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("calendar.block.\(id.uuidString)")
            }
        }
        .frame(width: max(width - Self.columnGap, 0), height: height, alignment: .topLeading)
        .offset(x: 0, y: y(band.interval.start))
        .motionSettle([y(band.interval.start), height])
        .motionRow()
    }

    private func bandBody(_ label: Text, fill: Color, foreground: Color = Palette.ink2) -> some View {
        label.font(Typography.meta).foregroundStyle(foreground)
            .padding(.horizontal, Spacing.row).padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(fill, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
    }

    private func blockedText(_ id: UUID, interval: DateInterval) -> Text {
        let reason = blocks.first { $0.id == id }?.reason
        let base = String(localized: LocalizedStringResource(
            "calendar.band.blocked", defaultValue: "Blocked · \(spanText(interval))", locale: formatters.locale
        ))
        return Text(verbatim: reason.map { "\(base) · \($0)" } ?? base)
    }

    private func spanText(_ interval: DateInterval) -> String {
        (interval.start..<interval.end).formatted(
            Date.IntervalFormatStyle(locale: formatters.locale, calendar: formatters.calendar,
                                     timeZone: formatters.timeZone).hour().minute()
        )
    }

    @ViewBuilder
    private func visitView(_ placed: CalendarDayLayout.Visit, width: CGFloat) -> some View {
        if let appointment = appointments.first(where: { $0.id == placed.id }) {
            let columnWidth = max(width / CGFloat(placed.columnCount), 0)
            let height = max(y(placed.interval.end) - y(placed.interval.start), Spacing.touchTarget)
            VisitBlock(
                appointment: appointment, clientName: clientName(appointment), density: .full, text: text,
                onReschedule: { onReschedule(appointment.id) }, onCancel: { onCancel(appointment.id) }
            )
            .frame(width: max(columnWidth - Self.columnGap, 0), height: height)
            .offset(x: columnWidth * CGFloat(placed.column), y: y(placed.interval.start))
            .motionSettle([columnWidth * CGFloat(placed.column), y(placed.interval.start), columnWidth, height])
            .motionRow()
        }
    }

    private var nowMarker: some View {
        HStack(spacing: 0) {
            Circle().fill(Palette.roseText).frame(width: 10, height: 10)
            Rectangle().fill(Palette.roseText).frame(height: 2)
        }
        .offset(x: -5, y: y(now) - 5)
        .motionSettle(y(now))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .accessibilityIdentifier("calendar.nowMarker")
    }
}
