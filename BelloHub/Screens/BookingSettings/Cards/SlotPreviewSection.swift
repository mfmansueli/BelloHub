//
//  SlotPreviewSection.swift
//  BelloHub
//

import SwiftUI

/// "What clients see" (routine item 10): the times her booking page would offer on a sample day, recomputed on the
/// phone as she changes any rule above (`SlotPreviewBuilder`, the same `FreeSlotsCalculator` as the page; no server
/// call). The times shown first are chips; the other bookable ones are one line, as behind "Show all times" on her
/// page. A native menu picks the service previewed. The chips are not buttons: nothing here books anything.
struct SlotPreviewSection: View {
    let viewModel: BookingSettingsViewModel

    @Environment(\.locale) private var locale

    private var formatters: Formatters {
        Formatters(locale: locale, timeZone: viewModel.timeZone, currencyCode: "EUR")
    }

    var body: some View {
        SettingsSection(title: "bookingSettings.preview.title", subtitle: "bookingSettings.preview.subtitle") {
            VStack(alignment: .leading, spacing: Spacing.row) {
                if viewModel.previewableServices.count > 1 { servicePicker }
                if let preview = viewModel.slotPreview {
                    caption(preview)
                    if preview.isEmpty {
                        Text("bookingSettings.preview.noTimes").font(Typography.meta).foregroundStyle(Palette.ink2)
                            .accessibilityIdentifier("bookingSettings.preview.noTimes")
                    } else {
                        times(preview)
                    }
                } else {
                    Text("bookingSettings.preview.noHours").font(Typography.meta).foregroundStyle(Palette.ink2)
                        .accessibilityIdentifier("bookingSettings.preview.noHours")
                }
                Text("bookingSettings.preview.footnote").font(Typography.footnote).foregroundStyle(Palette.ink2)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .belloCard()
        }
    }

    // MARK: - Parts

    private var servicePicker: some View {
        Picker(selection: Binding(
            get: { viewModel.previewServiceID ?? SlotPreviewBuilder.defaultService(in: viewModel.services)?.id },
            set: { viewModel.previewServiceID = $0 }
        )) {
            ForEach(viewModel.previewableServices) { service in
                Text(verbatim: "\(service.name) · \(formatters.minutes(service.durationMinutes))")
                    .tag(Optional(service.id))
            }
        } label: {
            Text("bookingSettings.preview.service")
        }
        .pickerStyle(.menu)
        .tint(Palette.roseText)
        .frame(minHeight: Spacing.touchTarget)
        .accessibilityIdentifier("bookingSettings.preview.servicePicker")
    }

    /// "Tuesday, October 13 · Haircut, 45 min. Already booked: Fringe trim at 10:00."
    private func caption(_ preview: SlotPreview) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(verbatim: "\(formatters.weekdayDayMonth(preview.day)) · \(serviceText(preview))")
                .font(Typography.metaStrong).foregroundStyle(Palette.ink)
            if let visit = preview.sampleVisit {
                let time = formatters.time(visit.start)
                Text(LocalizedStringResource(
                    "bookingSettings.preview.booked",
                    defaultValue: "Already booked in this sample: \(visit.serviceName) at \(time)"
                ).localized(in: locale))
                    .font(Typography.meta).foregroundStyle(Palette.ink2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("bookingSettings.preview.caption")
    }

    private func times(_ preview: SlotPreview) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("bookingSettings.preview.shownFirst").font(Typography.footnoteStrong).foregroundStyle(Palette.ink2)
            FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm) {
                ForEach(preview.shownFirst, id: \.self) { start in
                    Text(verbatim: formatters.time(start))
                        .font(Typography.metaStrong).foregroundStyle(Palette.selectionInk)
                        .padding(.horizontal, Spacing.row)
                        .frame(minHeight: 32)
                        .background(Palette.selectionFill, in: Capsule())
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: formatters.list(preview.shownFirst.map { formatters.time($0) })))
            .accessibilityIdentifier("bookingSettings.preview.shownFirstTimes")
            if !preview.alsoBookable.isEmpty {
                Text(LocalizedStringResource(
                    "bookingSettings.preview.alsoBookable",
                    defaultValue: "Also bookable with “Show all times”: \(alsoText(preview))"
                ).localized(in: locale))
                    .font(Typography.meta).foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("bookingSettings.preview.alsoBookable")
            }
        }
    }

    // MARK: - Words

    private func serviceText(_ preview: SlotPreview) -> String {
        guard let name = preview.serviceName else {
            return LocalizedStringResource(
                "bookingSettings.preview.sampleService",
                defaultValue: "A \(formatters.minutes(preview.durationMinutes)) visit"
            ).resolved(in: locale)
        }
        return "\(name), \(formatters.minutes(preview.durationMinutes))"
    }

    private func alsoText(_ preview: SlotPreview) -> String {
        formatters.list(preview.alsoBookable.map { formatters.time($0) })
    }
}
