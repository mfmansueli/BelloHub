//
//  BeforeYouStartContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of 3.3: what to know about the client before she starts, in one glance. It shows what the client told her
/// (allergies, her notes), the plan she is in, her last visit and the checks against the service. It informs and never
/// blocks (D16). Her health answers stay on the Health and consent screen, one tap away.
struct BeforeYouStartContentView: View {
    @State private var viewModel: BeforeYouStartViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(appointmentID: UUID, appointments: AppointmentService, vault: VaultService, profile: ProfileService) {
        _viewModel = State(initialValue: BeforeYouStartViewModel(
            appointmentID: appointmentID, appointments: appointments, vault: vault, profile: profile
        ))
    }

    var body: some View {
        NavigationStack {
            content
                .background(Palette.bg)
                .navigationTitle(Text("beforeYouStart.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: { Text("common.close") }
                            .accessibilityIdentifier("beforeYouStart.closeButton")
                    }
                }
        }
        .task { await viewModel.loadAsync() }
        .onChange(of: viewModel.didComplete) { _, completed in if completed { dismiss() } }
        .presentationDetents([.large])
        .presentationBackground(Palette.bg)
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        if let visit = viewModel.visit, let checklist = viewModel.checklist {
            overview(visit, checklist)
        } else {
            VisitStateView(
                prefix: "beforeYouStart", isMissing: viewModel.isMissing, errorMessage: viewModel.errorMessage,
                retry: viewModel.load
            )
        }
    }

    // MARK: - Overview

    private func overview(_ visit: VisitContext, _ checklist: PreVisitChecklist) -> some View {
        let formatters = viewModel.business.formatters(displayLocale: locale)
        let now = Date()
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VisitSummaryRow(visit: visit, formatters: formatters, now: now, identifier: "beforeYouStart.summary")
                if let message = viewModel.actionErrorMessage {
                    ErrorNotice(
                        message: message, actionTitle: "appointment.error.dismiss", action: viewModel.dismissActionError
                    )
                    .accessibilityIdentifier("beforeYouStart.saveError")
                }
                if hasImportant(checklist) { important(checklist, formatters: formatters) }
                if let plan = checklist.plan { planRow(plan, clientID: visit.client.id) }
                if let last = checklist.lastVisit { lastVisit(last, formatters: formatters, now: now) }
                PreVisitChecksCard(
                    checklist: checklist, serviceName: visit.appointment.serviceName, formatters: formatters, now: now
                )
                NavigationLink { ClientHealthView(clientID: visit.client.id) } label: {
                    Text("beforeYouStart.openHealth")
                        .font(Typography.metaStrong).foregroundStyle(Palette.roseText)
                        .frame(minHeight: Spacing.touchTarget, alignment: .leading)
                }
                .accessibilityIdentifier("beforeYouStart.healthLink")
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
        }
        .safeAreaInset(edge: .bottom) { if viewModel.canComplete { completeButton } }
        .accessibilityIdentifier("beforeYouStart.overview")
    }

    private func hasImportant(_ checklist: PreVisitChecklist) -> Bool {
        !checklist.allergies.isEmpty || checklist.importantNote != nil || !checklist.sensitivities.isEmpty
            || !checklist.preferences.isEmpty
    }

    private func important(_ checklist: PreVisitChecklist, formatters: Formatters) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("beforeYouStart.important").font(Typography.section).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if !checklist.allergies.isEmpty {
                    Text(LocalizedStringResource(
                        "appointment.allergy", defaultValue: "Allergy: \(formatters.list(checklist.allergies))"
                    ).localized(in: locale))
                    .font(Typography.bodyStrong).foregroundStyle(Palette.coralText)
                    .accessibilityIdentifier("beforeYouStart.allergies")
                }
                if let note = checklist.importantNote {
                    Text(verbatim: note).font(Typography.body).foregroundStyle(Palette.ink)
                        .accessibilityIdentifier("beforeYouStart.note")
                }
                if !checklist.sensitivities.isEmpty {
                    Text(verbatim: formatters.list(checklist.sensitivities))
                        .font(Typography.meta).foregroundStyle(Palette.ink2)
                }
                if !checklist.preferences.isEmpty {
                    Text(verbatim: formatters.list(checklist.preferences))
                        .font(Typography.meta).foregroundStyle(Palette.ink2)
                }
                Label { Text("beforeYouStart.noted") } icon: { Image(icon: .lock) }
                    .font(Typography.footnote).foregroundStyle(Palette.ink2)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .belloCard(cornerRadius: Radius.tile)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("beforeYouStart.important")
        }
    }

    private func planRow(_ plan: PreVisitChecklist.Plan, clientID: UUID) -> some View {
        let formatters = viewModel.business.formatters(displayLocale: locale)
        let session = plan.progress.currentSessionNumber ?? plan.progress.totalSessions
        let total = plan.progress.totalSessions
        let every = formatters.weeks(plan.intervalWeeks)
        return NavigationLink { SessionPlanView(clientID: clientID) } label: {
            HStack(spacing: Spacing.row) {
                Image(icon: .repeatArrows).font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Palette.sageText).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: plan.name).font(Typography.bodyStrong).foregroundStyle(Palette.sageText)
                    Text(LocalizedStringResource(
                        "beforeYouStart.plan.progress", defaultValue: "Session \(session) of \(total) · every \(every)"
                    ).localized(in: locale))
                    .font(Typography.meta).foregroundStyle(Palette.sageText)
                }
                Spacer(minLength: Spacing.sm)
                Image(icon: .forward).font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.sageText).flipsForRightToLeftLayoutDirection(true)
                    .accessibilityHidden(true)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, minHeight: Spacing.touchTarget)
            .background(Palette.sageWash, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("beforeYouStart.planLink")
    }

    private func lastVisit(_ visit: Appointment, formatters: Formatters, now: Date) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("beforeYouStart.lastVisit").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
            Text(verbatim: "\(visit.serviceName) · \(formatters.recentDate(visit.startsAt, now: now))")
                .font(Typography.body).foregroundStyle(Palette.ink)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .belloCard(cornerRadius: Radius.tile)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("beforeYouStart.lastVisit")
    }

    private var completeButton: some View {
        Button { viewModel.complete() } label: {
            if viewModel.isWorking { ProgressView() } else { Text("appointment.action.complete") }
        }
        .buttonStyle(.belloPrimary)
        .disabled(viewModel.isWorking)
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
        .accessibilityIdentifier("beforeYouStart.completeButton")
    }
}
