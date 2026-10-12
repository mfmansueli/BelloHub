//
//  VisitNextSessionPicker.swift
//  BelloHub
//

import SwiftUI

/// When she would like the client back: a row of week chips (the service's own interval among them) and the date it
/// points to. Choosing one writes "4 wk" into the record's next-session note; booking happens in the confirmation,
/// and nothing is sent to the client from here.
struct VisitNextSessionPicker: View {
    @Bindable var viewModel: TreatmentFlowViewModel
    @Environment(\.calendar) private var calendar

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("treatmentFlow.next.interval").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
            FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm, wrapsLongChildren: true) {
                ForEach(viewModel.weekChoices, id: \.self) { value in
                    let isChosen = viewModel.nextSessionNote == viewModel.formatters.weeks(value)
                    Button { viewModel.setNextWeeks(value) } label: {
                        Text(verbatim: viewModel.formatters.weeks(value))
                    }
                    .buttonStyle(.belloChip(selected: isChosen))
                    .accessibilityAddTraits(isChosen ? .isSelected : [])
                    .accessibilityIdentifier("treatmentFlow.next.weeks.\(value)")
                }
            }
            .disabled(viewModel.isLocked)
            if !viewModel.nextSessionNote.isEmpty {
                Text(verbatim: viewModel.formatters.weekdayDayMonth(viewModel.suggestedDate(calendar: calendar)))
                    .font(Typography.bodyStrong)
                    .foregroundStyle(Palette.ink)
                    .accessibilityIdentifier("treatmentFlow.next.date")
            }
        }
    }
}
