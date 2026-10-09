//
//  SessionPlanContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of 4.8: the plan's name, how many sessions and how far apart, the timeline those numbers give, and whether
/// she wants a reminder to rebook. No prices: only the rhythm.
struct SessionPlanContentView: View {
    @State private var viewModel: SessionPlanViewModel
    @Environment(\.locale) private var locale

    init(clientID: UUID, vault: VaultService, appointments: AppointmentService, profile: ProfileService) {
        _viewModel = State(initialValue: SessionPlanViewModel(
            clientID: clientID, vault: vault, appointments: appointments, profile: profile
        ))
    }

    var body: some View {
        content
            .background(Palette.bg)
            .navigationTitle(Text("sessionPlan.title"))
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.loadAsync() }
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        if viewModel.client != nil {
            form
        } else {
            VisitStateView(
                prefix: "sessionPlan", isMissing: viewModel.isMissing, errorMessage: viewModel.errorMessage,
                retry: viewModel.load
            )
        }
    }

    // MARK: - Form

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("sessionPlan.subtitle").font(Typography.body).foregroundStyle(Palette.ink2)
                if let message = viewModel.saveErrorMessage {
                    ErrorNotice(
                        message: message, actionTitle: "appointment.error.dismiss", action: viewModel.dismissSaveError
                    )
                    .accessibilityIdentifier("sessionPlan.saveError")
                }
                BelloTextField(
                    title: "sessionPlan.name", text: $viewModel.draft.name, prompt: "sessionPlan.name.prompt",
                    errorMessage: nil, identifier: "sessionPlan.nameField"
                )
                steppers
                timeline
                ToggleRow(
                    title: String(localized: "sessionPlan.remind", locale: locale),
                    subtitle: String(localized: "sessionPlan.remind.detail", locale: locale),
                    isOn: $viewModel.draft.remindToRebook, identifier: "sessionPlan.remindToggle"
                )
                .belloCard(cornerRadius: Radius.tile)
                if viewModel.isFinished {
                    Button { viewModel.startNewPlan() } label: { Text("sessionPlan.startNew") }
                        .buttonStyle(.belloSecondary)
                        .accessibilityIdentifier("sessionPlan.startNewButton")
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { saveButton }
        .accessibilityIdentifier("sessionPlan.form")
    }

    private var steppers: some View {
        let formatters = viewModel.business.formatters(displayLocale: locale)
        return VStack(spacing: 0) {
            Stepper(value: $viewModel.draft.totalSessions, in: SessionPlanRules.sessionRange) {
                labeled("sessionPlan.sessions", value: formatters.number(viewModel.draft.totalSessions))
            }
            .frame(minHeight: Spacing.touchTarget)
            .accessibilityIdentifier("sessionPlan.sessionsStepper")
            Rectangle().fill(Palette.hairline).frame(height: 1).padding(.vertical, Spacing.sm).accessibilityHidden(true)
            Stepper(value: $viewModel.draft.intervalWeeks, in: SessionPlanRules.intervalWeekRange) {
                labeled("sessionPlan.interval", value: formatters.weeks(viewModel.draft.intervalWeeks))
            }
            .frame(minHeight: Spacing.touchTarget)
            .accessibilityIdentifier("sessionPlan.intervalStepper")
        }
        .padding(Spacing.md)
        .belloCard(cornerRadius: Radius.tile)
    }

    private func labeled(_ title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title).font(Typography.meta).foregroundStyle(Palette.ink2)
            Text(verbatim: value).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
        }
    }

    // MARK: - Timeline

    private var timeline: some View {
        let formatters = viewModel.business.formatters(displayLocale: locale)
        let progress = viewModel.timeline
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("sessionPlan.timeline").font(Typography.section).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(Array(progress.steps.enumerated()), id: \.element.number) { index, step in
                    if index > 0 {
                        Rectangle().fill(Palette.hairline).frame(height: 1).accessibilityHidden(true)
                    }
                    stepRow(step, formatters: formatters)
                }
            }
            .padding(.horizontal, Spacing.md)
            .belloCard(cornerRadius: Radius.tile)
        }
        .accessibilityIdentifier("sessionPlan.timeline")
    }

    private func stepRow(_ step: SessionPlanProgress.Step, formatters: Formatters) -> some View {
        HStack(spacing: Spacing.row) {
            Image(icon: step.state == .done ? .check : .clock)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color(of: step.state))
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(LocalizedStringResource(
                    "sessionPlan.step", defaultValue: "Session \(step.number)"
                ).localized(in: locale))
                    .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                if let date = step.date {
                    Text(verbatim: formatters.shortDate(date)).font(Typography.meta).foregroundStyle(Palette.ink2)
                }
            }
            Spacer(minLength: Spacing.sm)
            Text(label(of: step.state)).font(Typography.metaStrong).foregroundStyle(color(of: step.state))
        }
        .padding(.vertical, Spacing.row)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("sessionPlan.step.\(step.number)")
    }

    private func color(of state: SessionStepState) -> Color {
        switch state {
        case .done: Palette.sageText
        case .current: Palette.roseText
        case .upcoming: Palette.ink2
        }
    }

    private func label(of state: SessionStepState) -> LocalizedStringKey {
        switch state {
        case .done: "sessionPlan.state.done"
        case .current: "sessionPlan.state.current"
        case .upcoming: "sessionPlan.state.upcoming"
        }
    }

    private var saveButton: some View {
        Button { viewModel.save() } label: {
            if viewModel.isSaving {
                ProgressView()
            } else {
                Text(viewModel.didSave ? "sessionPlan.saved" : "sessionPlan.save")
            }
        }
        .buttonStyle(.belloPrimary)
        .disabled(!viewModel.canSave || viewModel.didSave)
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
        .accessibilityIdentifier("sessionPlan.saveButton")
    }
}
