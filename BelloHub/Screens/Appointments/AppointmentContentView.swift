//
//  AppointmentContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of 3.2 Appointment: who, what, when and the state of the visit, what to know before starting, and the
/// actions the visit allows (`AppointmentActionRules`). The other screens of the flow open as sheets or pushes through
/// `AgendaSheet` and `AgendaRoute`.
struct AppointmentContentView: View {
    @State private var viewModel: AppointmentViewModel
    @State private var sheet: AgendaSheet?
    @Environment(\.locale) private var locale

    init(
        appointmentID: UUID, appointments: AppointmentService, vault: VaultService, profile: ProfileService,
        setup: BookingSetupService
    ) {
        _viewModel = State(initialValue: AppointmentViewModel(
            appointmentID: appointmentID, appointments: appointments, vault: vault, profile: profile, setup: setup
        ))
    }

    var body: some View {
        content
            .background(Palette.bg)
            .navigationTitle(Text("appointment.title"))
            .navigationBarTitleDisplayMode(.inline)
            .task { viewModel.startListening() }
            .agendaSheet(item: $sheet)
            .alert(Text("appointment.error.actionTitle"), isPresented: actionFailed) {
                Button(role: .cancel) {} label: { Text("common.close") }
            } message: {
                Text(verbatim: viewModel.actionErrorMessage ?? "")
            }
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        if let visit = viewModel.visit {
            detail(visit)
        } else {
            VisitStateView(
                prefix: "appointment", isMissing: viewModel.isMissing, errorMessage: viewModel.errorMessage,
                retry: viewModel.refresh
            )
        }
    }

    // MARK: - Detail

    private func detail(_ visit: VisitContext) -> some View {
        let now = viewModel.now()
        let formatters = viewModel.business.formatters(displayLocale: locale)
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header(visit, formatters: formatters, now: now)
                statusRow(visit, formatters: formatters, now: now)
                if let checklist = viewModel.checklist {
                    if !checklist.allergies.isEmpty { allergyNotice(checklist) }
                    PreVisitChecksCard(
                        checklist: checklist, serviceName: visit.appointment.serviceName, formatters: formatters,
                        now: now
                    )
                    reminderRow(visit, formatters: formatters, now: now)
                    links(checklist, visit: visit)
                } else {
                    reminderRow(visit, formatters: formatters, now: now)
                }
                AppointmentExtrasCard(appointment: visit.appointment, formatters: formatters)
                if let layout = viewModel.layout {
                    AppointmentActionsSection(layout: layout, isWorking: viewModel.isWorking) {
                        perform($0, visit: visit)
                    }
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xl)
        }
        .refreshable { await viewModel.refreshAsync() }
        .accessibilityIdentifier("appointment.detail")
    }

    private func header(_ visit: VisitContext, formatters: Formatters, now: Date) -> some View {
        HStack(spacing: Spacing.md) {
            Avatar(name: visit.client.name, id: visit.client.id.uuidString, size: 64)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: visit.client.name)
                    .font(Typography.title)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("appointment.clientName")
                Text(verbatim: serviceLine(visit.appointment, formatters: formatters))
                    .font(Typography.meta)
                    .foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("appointment.service")
            }
            Spacer(minLength: 0)
        }
    }

    private func statusRow(_ visit: VisitContext, formatters: Formatters, now: Date) -> some View {
        let appointment = visit.appointment
        return FlowLayout(spacing: Spacing.row, lineSpacing: Spacing.sm, wrapsLongChildren: true) {
            AppointmentStatusChip(status: appointment.status)
            Text(verbatim: formatters.visitWhen(
                appointment, now: now, today: LocalizedStringResource("appointment.today").resolved(in: locale),
                tomorrow: LocalizedStringResource("appointment.tomorrow").resolved(in: locale)
            ))
            .font(Typography.meta)
            .foregroundStyle(Palette.ink2)
            .accessibilityIdentifier("appointment.when")
            if let late = appointment.lateByMinutes, late > 0, appointment.status.holdsTime {
                HStack(spacing: Spacing.sm) {
                    StatusChip(label: "appointment.late.chip", style: StatusPalette.pending)
                    Text(verbatim: formatters.minutes(late)).font(Typography.meta).foregroundStyle(Palette.ink2)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("appointment.lateChip")
            }
        }
    }

    private func allergyNotice(_ checklist: PreVisitChecklist) -> some View {
        let list = viewModel.business.formatters(displayLocale: locale).list(checklist.allergies)
        return InlineNotice(
            style: .safety,
            title: Text(LocalizedStringResource("appointment.allergy", defaultValue: "Allergy: \(list)")
                .localized(in: locale))
        )
        .accessibilityIdentifier("appointment.allergyNotice")
    }

    @ViewBuilder
    private func reminderRow(_ visit: VisitContext, formatters: Formatters, now: Date) -> some View {
        switch viewModel.reminder {
        case .notSent:
            EmptyView()
        case .confirmed:
            Label { Text("appointment.reminder.confirmed") } icon: { Image(icon: .check) }
                .font(Typography.meta)
                .foregroundStyle(Palette.sageText)
                .accessibilityIdentifier("appointment.reminderConfirmed")
        case .waiting(let sentAt):
            let when = formatters.recentDate(sentAt, now: now)
            HStack(alignment: .center, spacing: Spacing.row) {
                Label {
                    Text(LocalizedStringResource(
                        "appointment.reminder.waiting", defaultValue: "Reminder sent \(when). No reply yet."
                    ).localized(in: locale))
                } icon: { Image(icon: .clock) }
                .font(Typography.meta)
                .foregroundStyle(Palette.amberText)
                Spacer(minLength: Spacing.sm)
                Button { sheet = .message(appointmentID: visit.appointment.id) } label: {
                    Text("appointment.reminder.remind")
                        .font(Typography.metaStrong)
                        .foregroundStyle(Palette.roseText)
                        .frame(minHeight: Spacing.touchTarget)
                }
                .accessibilityIdentifier("appointment.remindAgainButton")
            }
            .padding(Spacing.md)
            .background(Palette.amberBg, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("appointment.reminderWaiting")
        }
    }

    // MARK: - Links

    @ViewBuilder
    private func links(_ checklist: PreVisitChecklist, visit: VisitContext) -> some View {
        if let plan = checklist.plan {
            linkRow(
                icon: .repeatArrows, route: .sessionPlan(clientID: visit.client.id),
                title: planTitle(plan), identifier: "appointment.sessionPlanRow"
            )
        }
        if viewModel.showsNoShowHistory {
            linkRow(
                icon: .clock, route: .noShowHistory(clientID: visit.client.id),
                title: Text("appointment.noShowHistory.title"), identifier: "appointment.noShowHistoryRow"
            )
        }
    }

    private func linkRow(icon: Icon, route: AgendaRoute, title: Text, identifier: String) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: Spacing.row) {
                Image(icon: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Palette.sageText)
                    .accessibilityHidden(true)
                title
                    .font(Typography.meta)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: Spacing.sm)
                Image(icon: .forward)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink2)
                    .flipsForRightToLeftLayoutDirection(true)
                    .accessibilityHidden(true)
            }
            .padding(Spacing.md)
            .frame(minHeight: Spacing.touchTarget)
            .belloCard(cornerRadius: Radius.tile, elevation: .e1)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func planTitle(_ plan: PreVisitChecklist.Plan) -> Text {
        let name = plan.name
        guard let session = plan.progress.currentSessionNumber else {
            return Text(LocalizedStringResource(
                "appointment.plan.finished", defaultValue: "\(name): all sessions done"
            ).localized(in: locale))
        }
        let total = plan.progress.totalSessions
        return Text(LocalizedStringResource(
            "appointment.plan.progress", defaultValue: "\(name), session \(session) of \(total)"
        ).localized(in: locale))
    }

    private func perform(_ action: AppointmentAction, visit: VisitContext) {
        let id = visit.appointment.id
        switch action {
        case .beforeYouStart: sheet = .beforeYouStart(appointmentID: id)
        case .complete: viewModel.complete()
        case .message: sheet = .message(appointmentID: id)
        case .runningLate: sheet = .runningLate(appointmentID: id)
        case .reschedule: sheet = .reschedule(appointmentID: id)
        case .noShow: sheet = .noShowMark(appointmentID: id)
        case .cancel: sheet = .cancel(appointmentID: id)
        }
    }

    // MARK: - Helpers

    private func serviceLine(_ appointment: Appointment, formatters: Formatters) -> String {
        "\(appointment.serviceName) · \(formatters.duration(minutes: appointment.totalMinutes))"
    }

    private var actionFailed: Binding<Bool> {
        Binding(get: { viewModel.actionErrorMessage != nil }, set: { if !$0 { viewModel.dismissActionError() } })
    }
}
