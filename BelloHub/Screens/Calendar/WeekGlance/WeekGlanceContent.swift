//
//  WeekGlanceContent.swift
//  BelloHub
//

import SwiftUI

/// The body of the "This week" screen. The numbers come from `WeekSummary`; the bars are the system's progress view,
/// so VoiceOver reads "3 of 4" from the row's own label instead of a drawn rectangle.
struct WeekGlanceContent: View {
    @State private var viewModel: WeekGlanceViewModel
    private let settings: CalendarSettings

    @State private var agendaSheet: AgendaSheet?
    @Environment(\.locale) private var locale

    init(viewModel: WeekGlanceViewModel, settings: CalendarSettings) {
        _viewModel = State(initialValue: viewModel)
        self.settings = settings
    }

    private var formatters: Formatters { settings.formatters(locale: locale) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                subtitle
                if let message = viewModel.errorMessage {
                    ErrorNotice(message: message, actionTitle: "scheduling.tryAgain") { viewModel.load() }
                        .padding(.top, Spacing.md)
                        .accessibilityIdentifier("weekGlance.error")
                }
                if let summary = viewModel.summary {
                    tiles(summary)
                    bookingsByDay(summary)
                    openSlots(summary)
                } else if viewModel.errorMessage == nil {
                    loading
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.bottom, Spacing.lg)
        }
        .background(Palette.bg)
        .navigationTitle(Text("weekGlance.title"))
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await viewModel.loadAsync() }
        .task { await viewModel.loadAsync() }
        .agendaSheet(item: $agendaSheet)
    }

    // MARK: - Sections

    private var subtitle: some View {
        let week = viewModel.weekInterval
        return Text(verbatim: formatters.dayRange(from: week.start, to: week.end.addingTimeInterval(-1)))
            .font(Typography.body).foregroundStyle(Palette.ink2)
            .accessibilityIdentifier("weekGlance.subtitle")
    }

    private var loading: some View {
        VStack(spacing: Spacing.row) {
            Skeleton(height: 96, cornerRadius: Radius.tileSmall)
            Skeleton(height: 96, cornerRadius: Radius.tileSmall)
            Skeleton(height: 220, cornerRadius: Radius.card)
        }
        .padding(.top, Spacing.md)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("scheduling.loading"))
        .accessibilityIdentifier("weekGlance.loading")
    }

    private func tiles(_ summary: WeekSummary) -> some View {
        VStack(spacing: Spacing.row) {
            HStack(spacing: Spacing.row) {
                InsightTile(icon: .clock, value: formatters.number(summary.leftToday),
                            label: "weekGlance.tile.leftToday", tone: .sage)
                    .accessibilityIdentifier("weekGlance.tile.leftToday")
                InsightTile(icon: .calendar, value: formatters.number(summary.openSlotCount),
                            label: "weekGlance.tile.openSlots", tone: .peach)
                    .accessibilityIdentifier("weekGlance.tile.openSlots")
            }
            .fixedSize(horizontal: false, vertical: true)
            NavigationLink(value: AgendaRoute.winBack) {
                InsightTile(icon: .clients, value: formatters.number(viewModel.notReturnedCount),
                            label: "weekGlance.tile.notReturned", tone: .rose)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("weekGlance.tile.notReturned")
        }
        .padding(.top, Spacing.md)
    }

    private func bookingsByDay(_ summary: WeekSummary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "weekGlance.section.byDay")
            ListCard(dividerInset: Spacing.md) {
                ForEach(summary.rows) { row in dayRow(row) }
            }
        }
    }

    private func dayRow(_ row: WeekSummary.DayRow) -> some View {
        let label = String(localized: LocalizedStringResource(
            "weekGlance.day.count", defaultValue: "\(row.booked) of \(row.capacity)", locale: locale
        ))
        let name = row.day.formatted(Date.FormatStyle(locale: locale, calendar: formatters.calendar,
                                                      timeZone: formatters.timeZone)
            .weekday(.abbreviated).month(.abbreviated).day())
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(verbatim: name).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                if row.isToday {
                    Text("weekGlance.today").font(Typography.footnoteStrong).foregroundStyle(Palette.roseDeepText)
                }
                Spacer(minLength: Spacing.sm)
                Text(verbatim: label).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    .motionNumber(label)
            }
            ProgressView(value: row.fraction).tint(Palette.sage).accessibilityHidden(true)
                .motionSettle(row.fraction)
        }
        .padding(Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("weekGlance.day.\(Int(row.day.timeIntervalSince1970))")
    }

    private func openSlots(_ summary: WeekSummary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "weekGlance.section.openSlots")
            if summary.suggestions.isEmpty {
                Text("weekGlance.openSlots.none")
                    .font(Typography.meta).foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("weekGlance.openSlots.none")
            } else {
                ListCard(dividerInset: Spacing.md) {
                    ForEach(Array(summary.suggestions.enumerated()), id: \.element.id) { index, slot in
                        Button { agendaSheet = .newAppointment(clientID: nil, startsAt: slot.start) } label: {
                            HStack(spacing: Spacing.row) {
                                Image(icon: .clock).foregroundStyle(Palette.roseDeepText).accessibilityHidden(true)
                                Text(verbatim: formatters.dateTime(slot.start))
                                    .font(Typography.body).foregroundStyle(Palette.ink)
                                Spacer(minLength: Spacing.sm)
                                Image(icon: .forward).font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Palette.ink3).accessibilityHidden(true)
                            }
                            .padding(.horizontal, Spacing.md)
                            .frame(minHeight: 56)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("weekGlance.slot.\(index)")
                    }
                }
            }
            FooterNote(text: "weekGlance.footer", icon: .info).padding(.top, Spacing.row)
        }
    }
}
