//
//  VisitDaySheet.swift
//  BelloHub
//

import SwiftUI

/// Sets the day the treatment happened. On a locked record the change is a logged correction, so it asks why, like
/// any correction. A day in the future is refused.
struct VisitDaySheet: View {
    let viewModel: VisitDetailViewModel

    @State private var day: Date
    @State private var reason = ""
    @State private var triedToSave = false
    @Environment(\.dismiss) private var dismiss

    init(viewModel: VisitDetailViewModel) {
        self.viewModel = viewModel
        _day = State(initialValue: viewModel.visitDate?.date ?? Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text(viewModel.visitDayNeedsReason ? "visitDay.introLocked" : "visitDay.intro")
                        .font(Typography.meta)
                        .foregroundStyle(Palette.ink2)
                    DatePicker(selection: $day, in: ...Date(), displayedComponents: [.date, .hourAndMinute]) {
                        Text("visitDay.picker")
                    }
                    .datePickerStyle(.graphical)
                    .tint(Palette.roseText)
                    .accessibilityIdentifier("visitDay.picker")
                    if viewModel.visitDayNeedsReason {
                        BelloNoteField(
                            title: Text("recordHistory.correction.reason"), text: $reason,
                            prompt: "recordHistory.correction.reasonPrompt", isSensitive: true,
                            identifier: "visitDay.reason"
                        )
                    }
                    if triedToSave { problemText }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.vertical, Spacing.md)
            }
            .background(Palette.bg)
            .navigationTitle(Text("visitDay.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.cancel") }
                        .accessibilityIdentifier("visitDay.cancel")
                }
            }
            .safeAreaInset(edge: .bottom) {
                FlowBottomBar {
                    Button(action: save) {
                        if viewModel.isWorking { ProgressView() } else { Text("visitDay.save") }
                    }
                    .buttonStyle(.belloPrimary)
                    .disabled(viewModel.isWorking)
                    .accessibilityIdentifier("visitDay.save")
                }
            }
        }
        .presentationBackground(Palette.bg)
        .interactiveDismissDisabled(viewModel.isWorking)
    }

    @ViewBuilder
    private var problemText: some View {
        switch viewModel.visitDayProblem(day: day, reason: reason) {
        case .unchanged: problem("visitDay.unchanged")
        case .inFuture: problem("visitDay.inFuture")
        case .reasonMissing: problem("recordHistory.correction.reasonMissing")
        case nil: EmptyView()
        }
    }

    private func problem(_ text: LocalizedStringKey) -> some View {
        Text(text).font(Typography.meta).foregroundStyle(Palette.coralText)
            .accessibilityIdentifier("visitDay.problem")
    }

    private func save() {
        triedToSave = true
        guard viewModel.visitDayProblem(day: day, reason: reason) == nil else { return }
        Task {
            if await viewModel.saveVisitDay(day, reason: reason) { dismiss() }
        }
    }
}
