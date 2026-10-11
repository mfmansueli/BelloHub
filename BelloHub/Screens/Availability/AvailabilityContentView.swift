//
//  AvailabilityContentView.swift
//  BelloHub
//

import SwiftUI

/// The Availability list: working hours by weekday, breaks, the time between clients and days off. A native `List`,
/// so the switches, swipe actions and Dynamic Type behave as everywhere on iOS. Each row opens a sheet for its
/// details; every change is saved at once.
struct AvailabilityContentView: View {
    @State private var viewModel: AvailabilityViewModel
    @State private var editor: AvailabilityEditorMode?
    /// Her week start (`ProfessionalProfile.weekConfig`); the phone's until her profile is read.
    private let weekStart: Int?

    @Environment(\.locale) private var locale

    init(service: BookingSetupService, timeZoneID: String, firstWeekday: Int?) {
        _viewModel = State(initialValue: AvailabilityViewModel(service: service, timeZoneID: timeZoneID))
        weekStart = firstWeekday
    }

    // MARK: - Helpers

    private var formatters: Formatters {
        Formatters(locale: locale, timeZone: viewModel.settings.timeZone, currencyCode: "EUR")
    }

    private var firstWeekday: Int {
        weekStart ?? Calendar.current.firstWeekday
    }

    private var text: AvailabilityText {
        AvailabilityText(formatters: formatters, firstWeekday: firstWeekday)
    }

    private var weekdays: [Int] { AvailabilityEditor.weekdays(firstWeekday: firstWeekday) }

    private var rowInsets: EdgeInsets {
        EdgeInsets(top: 0, leading: Spacing.md, bottom: 0, trailing: Spacing.md)
    }

    // MARK: - Body

    var body: some View {
        List {
            introSection
            hoursSection
            breaksSection
            bufferSection
            daysOffSection
            Section {
                FooterNote(text: "availability.footer", icon: .lock)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.bg)
        .navigationTitle(Text("availability.title"))
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await viewModel.loadAsync() }
        .task { await viewModel.loadAsync() }
        .sheet(item: $editor) { mode in sheet(for: mode) }
    }

    // MARK: - Sections

    private var introSection: some View {
        Section {
            Text("availability.subtitle")
                .font(Typography.body).foregroundStyle(Palette.ink2)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                // A little inset: at none the first letter of a wrapped line is clipped by the list's edge.
                .listRowInsets(EdgeInsets(top: 0, leading: Spacing.sm, bottom: Spacing.sm, trailing: Spacing.sm))
            if viewModel.isStarter && viewModel.hasLoaded && viewModel.errorMessage == nil {
                InlineNotice(style: .info, title: "availability.starter.title", message: "availability.starter.message")
                    .accessibilityIdentifier("availability.starterNotice")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
            if let message = viewModel.errorMessage {
                ErrorNotice(message: message, actionTitle: "bookingSetup.retry", action: viewModel.load)
                    .accessibilityIdentifier("availability.error")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
            if let message = viewModel.saveErrorMessage {
                ErrorNotice(message: message, actionTitle: "bookingSetup.dismiss", action: viewModel.dismissSaveError)
                    .accessibilityIdentifier("availability.saveError")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
    }

    private var hoursSection: some View {
        Section {
            if viewModel.showsSkeleton {
                ForEach(0..<7, id: \.self) { _ in Skeleton(height: 44).listRowBackground(Palette.surface) }
            } else {
                ForEach(weekdays, id: \.self) { weekday in
                    WeekdayRow(
                        weekday: weekday, name: formatters.weekdayName(weekday),
                        hours: text.hours(of: weekday, in: viewModel.settings),
                        isOpen: Binding(
                            get: { AvailabilityEditor.isOpen(weekday, in: viewModel.settings) },
                            set: { open in Task { await viewModel.setDay(weekday, open: open) } }
                        ),
                        onEdit: { editor = .hours(weekday: weekday) }
                    )
                    .listRowBackground(Palette.surface)
                    .listRowInsets(rowInsets)
                }
            }
        } header: {
            header("availability.section.hours")
        }
    }

    private var breaksSection: some View {
        Section {
            ForEach(viewModel.sortedBreaks, id: \.index) { entry in
                Button { editor = .editBreak(index: entry.index, rule: entry.rule) } label: {
                    detailRow(title: entry.rule.label, detail: text.detail(of: entry.rule))
                }
                .buttonStyle(.plain)
                .listRowBackground(Palette.surface)
                .listRowInsets(rowInsets)
                .accessibilityIdentifier("availability.break.\(entry.index)")
            }
            if viewModel.sortedBreaks.isEmpty && viewModel.hasLoaded {
                Text("availability.breaks.empty")
                    .font(Typography.meta).foregroundStyle(Palette.ink2)
                    .listRowBackground(Palette.surface)
                    .listRowInsets(rowInsets)
                    .padding(.vertical, Spacing.row)
                    .accessibilityIdentifier("availability.breaks.empty")
            }
            if viewModel.canAddBreak {
                Button { editor = .addBreak } label: { AddRowLabel(title: "availability.break.add") }
                    .buttonStyle(.plain)
                    .listRowBackground(Palette.surface)
                    .listRowInsets(rowInsets)
                    .accessibilityIdentifier("availability.addBreakButton")
            }
        } header: {
            header("availability.section.breaks")
        }
    }

    private var bufferSection: some View {
        Section {
            HStack {
                Text("availability.buffer.label").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Spacer(minLength: Spacing.sm)
                Picker(selection: bufferBinding) {
                    ForEach(bufferOptions, id: \.self) { minutes in
                        Text(verbatim: bufferLabel(minutes)).tag(minutes)
                    }
                } label: {
                    Text("availability.buffer.label")
                }
                .pickerStyle(.menu)
                .tint(Palette.roseText)
                .accessibilityIdentifier("availability.bufferPicker")
            }
            .frame(minHeight: 56)
            .listRowBackground(Palette.surface)
            .listRowInsets(rowInsets)
        } header: {
            header("availability.section.buffer")
        } footer: {
            Text("availability.buffer.subtitle").font(Typography.meta).foregroundStyle(Palette.ink2)
        }
    }

    private var daysOffSection: some View {
        Section {
            ForEach(viewModel.upcomingDaysOff) { dayOff in
                Button { editor = .editDayOff(dayOff) } label: {
                    detailRow(
                        title: nil, titleResource: dayOff.kind.name.localized(in: locale),
                        detail: text.range(of: dayOff)
                    )
                }
                .buttonStyle(.plain)
                .listRowBackground(Palette.surface)
                .listRowInsets(rowInsets)
                .swipeActions {
                    Button(role: .destructive) { Task { await viewModel.deleteDayOff(id: dayOff.id) } } label: {
                        Text("availability.dayOffSheet.delete")
                    }
                }
                .accessibilityIdentifier("availability.dayOff.\(dayOff.id.uuidString)")
            }
            if viewModel.upcomingDaysOff.isEmpty && viewModel.hasLoaded {
                Text("availability.daysOff.empty")
                    .font(Typography.meta).foregroundStyle(Palette.ink2)
                    .listRowBackground(Palette.surface)
                    .listRowInsets(rowInsets)
                    .padding(.vertical, Spacing.row)
                    .accessibilityIdentifier("availability.daysOff.empty")
            }
            Button { editor = .addDayOff } label: { AddRowLabel(title: "availability.dayOff.add") }
                .buttonStyle(.plain)
                .listRowBackground(Palette.surface)
                .listRowInsets(rowInsets)
                .accessibilityIdentifier("availability.addDayOffButton")
        } header: {
            header("availability.section.daysOff")
        }
    }

    // MARK: - Parts

    private func header(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(Typography.section).foregroundStyle(Palette.ink)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
    }

    private func detailRow(title: String?, titleResource: LocalizedStringResource? = nil, detail: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                if let title {
                    Text(verbatim: title).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                } else if let titleResource {
                    Text(titleResource).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                }
                Text(verbatim: detail).font(Typography.meta).foregroundStyle(Palette.ink2)
            }
            Spacer(minLength: 0)
            Image(icon: .forward).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink3)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }

    private var bufferOptions: [Int] {
        Set(AvailabilityEditor.bufferOptions + [viewModel.settings.bufferMinutes]).sorted()
    }

    private var bufferBinding: Binding<Int> {
        Binding(
            get: { viewModel.settings.bufferMinutes },
            set: { minutes in Task { await viewModel.setBuffer(minutes) } }
        )
    }

    private func bufferLabel(_ minutes: Int) -> String {
        minutes == 0
            ? String(localized: LocalizedStringResource(
                "availability.buffer.none", defaultValue: "No time", locale: locale
            ))
            : formatters.minutes(minutes)
    }

    @ViewBuilder
    private func sheet(for mode: AvailabilityEditorMode) -> some View {
        switch mode {
        case .hours(let weekday):
            DayHoursSheet(weekday: weekday, viewModel: viewModel, formatters: formatters)
        case .addBreak:
            BreakSheet(index: nil, rule: nil, viewModel: viewModel, formatters: formatters, weekdays: weekdays)
        case .editBreak(let index, let rule):
            BreakSheet(index: index, rule: rule, viewModel: viewModel, formatters: formatters, weekdays: weekdays)
        case .addDayOff:
            DayOffSheet(dayOff: nil, viewModel: viewModel, formatters: formatters, today: startOfToday)
        case .editDayOff(let dayOff):
            DayOffSheet(dayOff: dayOff, viewModel: viewModel, formatters: formatters, today: startOfToday)
        }
    }

    private var startOfToday: Date {
        formatters.calendar.startOfDay(for: Date())
    }
}

#Preview {
    NavigationStack {
        AvailabilityContentView(
            service: BookingSetupService(vault: VaultService(repository: nil)),
            timeZoneID: "America/Sao_Paulo", firstWeekday: 1
        )
    }
}
