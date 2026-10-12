//
//  VisitDetailHeader.swift
//  BelloHub
//

import SwiftUI

/// The top of a visit's details: the day it happened (with a way to set it), the service and where the record
/// stands. An old record with no visit day says so instead of showing a guessed one.
struct VisitDetailHeader: View {
    let record: TreatmentRecord
    let visitDate: RecordVisitDate
    let state: VisitRecordState
    let formatters: Formatters
    let now: Date
    let onSetDay: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text(verbatim: dayText)
                    .font(Typography.metaStrong)
                    .foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("visitDetail.day")
                Spacer(minLength: Spacing.sm)
                VisitStateChip(state: state, showsFinalized: true)
                    .accessibilityIdentifier("visitDetail.state")
            }
            Text(verbatim: record.serviceName)
                .font(Typography.title)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            statusLine
            if !visitDate.isVisitDay {
                Button(action: onSetDay) {
                    Label { Text("visitDetail.setDay") } icon: { Image(icon: .calendar) }
                        .font(Typography.metaStrong)
                        .foregroundStyle(Palette.roseText)
                        .frame(minHeight: Spacing.touchTarget)
                }
                .accessibilityIdentifier("visitDetail.setDayInline")
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .belloCard()
        .accessibilityElement(children: .contain)
    }

    /// "Tuesday, September 29" for a known visit day (with the year when it is not this one); for an old record,
    /// when it was written.
    private var dayText: String {
        guard visitDate.isVisitDay else {
            return VisitDateLabel.text(visitDate, formatters: formatters, now: now, locale: locale)
        }
        return formatters.visitDay(visitDate.date, now: now)
    }

    @ViewBuilder
    private var statusLine: some View {
        switch state {
        case .draft:
            Text("visitDetail.status.draft")
                .font(Typography.meta).foregroundStyle(Palette.ink2)
        case .open(let remaining):
            let time = formatters.remaining(remaining)
            Text(LocalizedStringResource("visitDetail.status.open", defaultValue: "Finalized · editable for \(time)")
                .localized(in: locale))
                .font(Typography.meta).foregroundStyle(Palette.amberText)
        case .locked:
            Text("visitDetail.status.locked")
                .font(Typography.meta).foregroundStyle(Palette.ink2)
        }
    }
}
