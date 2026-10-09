//
//  NextSessionStepView.swift
//  BelloHub
//

import SwiftUI

/// 5.9 Tx-7-NextSession: when should she come back. The interval is a row of chips (the service's own default first
/// in mind), the date follows from it, and "Book now" opens the new-appointment sheet for this client at that date.
/// "Save suggestion" writes the interval into the record. Nothing is sent to the client from here: reminders need the
/// messaging services of a later stage, so the screen does not pretend to send them.
struct NextSessionStepView: View {
    @Bindable var viewModel: TreatmentFlowViewModel
    let onBook: (AgendaSheet) -> Void

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(title).font(Typography.title).foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                weeks
                dateCard
                if viewModel.hasServiceDefault {
                    Text(defaultNote).font(Typography.meta).foregroundStyle(Palette.ink2)
                        .accessibilityIdentifier("treatmentFlow.next.defaultNote")
                }
                if viewModel.suggestionSaved {
                    InlineNotice(style: .info, title: "treatmentFlow.next.saved")
                        .accessibilityIdentifier("treatmentFlow.next.savedNotice")
                }
                if let failure = viewModel.failure {
                    TreatmentFailureNotice(failure: failure)
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
        }
        .background(Palette.bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { viewModel.path.removeAll { $0 == .nextSession } } label: { Text("treatmentFlow.next.skip") }
                    .accessibilityIdentifier("treatmentFlow.next.skipButton")
            }
        }
        .safeAreaInset(edge: .bottom) {
            FlowBottomBar {
                Button {
                    let date = viewModel.suggestedDate(calendar: calendar)
                    onBook(.newAppointment(clientID: viewModel.clientID, startsAt: date))
                } label: { Text("treatmentFlow.next.book") }
                    .buttonStyle(.belloPrimary)
                    .accessibilityIdentifier("treatmentFlow.next.bookButton")
                Button { Task { await save() } } label: { Text("treatmentFlow.next.save") }
                    .buttonStyle(.belloSecondary)
                    .accessibilityIdentifier("treatmentFlow.next.saveButton")
            }
        }
        .accessibilityIdentifier("treatmentFlow.next")
    }

    // MARK: - Parts

    private var weeks: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("treatmentFlow.next.interval").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
            FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm, wrapsLongChildren: true) {
                ForEach(viewModel.weekChoices, id: \.self) { value in
                    Button { viewModel.nextWeeks = value; viewModel.suggestionSaved = false } label: {
                        Text(verbatim: viewModel.formatters.weeks(value))
                    }
                    .buttonStyle(.belloChip(selected: viewModel.nextWeeks == value))
                    .accessibilityAddTraits(viewModel.nextWeeks == value ? .isSelected : [])
                    .accessibilityIdentifier("treatmentFlow.next.weeks.\(value)")
                }
            }
        }
    }

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("treatmentFlow.next.around").font(Typography.meta).foregroundStyle(Palette.ink2)
            Text(verbatim: viewModel.formatters.weekdayDayMonth(viewModel.suggestedDate(calendar: calendar)))
                .font(Typography.subtitle).foregroundStyle(Palette.ink)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .belloCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("treatmentFlow.next.date")
    }

    private var title: String {
        let name = BidiIsolate.wrap(viewModel.client?.firstName ?? "")
        let service = BidiIsolate.wrap(viewModel.serviceName)
        return LocalizedStringResource(
            "treatmentFlow.next.title", defaultValue: "When should \(name) come back for \(service)?"
        ).resolved(in: locale)
    }

    private var defaultNote: String {
        let service = BidiIsolate.wrap(viewModel.serviceName)
        let weeks = viewModel.formatters.weeks(viewModel.defaultWeeks)
        return LocalizedStringResource(
            "treatmentFlow.next.default", defaultValue: "Your default for \(service) is \(weeks)."
        ).resolved(in: locale)
    }

    private func save() async {
        _ = await viewModel.saveSuggestion(formatters: viewModel.formatters)
    }
}
