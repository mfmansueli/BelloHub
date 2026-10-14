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
    @State private var visitFlow: TreatmentFlowRequest?
    @State private var recordRoute: RecordRoute?
    @Environment(\.locale) private var locale
    @Environment(ProfileService.self) private var profile
    @Environment(ClientLinkService.self) private var clientLinks

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
            .treatmentFlow(item: $visitFlow)
            // Back from the visit form: the record state (draft, finalized) changed.
            .onChange(of: visitFlow) { _, new in if new == nil { viewModel.refresh() } }
            .recordDestination(item: $recordRoute)
            .confirmationDialog(
                Text("appointment.register.title"), isPresented: $viewModel.offersToRegister, titleVisibility: .visible
            ) {
                Button { visitFlow = viewModel.visitFlowRequest } label: { Text("appointment.register.now") }
                    .accessibilityIdentifier("appointment.registerNowButton")
                Button(role: .cancel) {} label: { Text("appointment.register.later") }
                    .accessibilityIdentifier("appointment.registerLaterButton")
            } message: {
                Text("appointment.register.message")
            }
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
                if let issue = visit.appointment.manualBookingSyncIssue, visit.appointment.status.holdsTime {
                    manualBookingNotice(issue, appointmentID: visit.appointment.id)
                }
                if let checklist = viewModel.checklist {
                    if !checklist.allergies.isEmpty { allergyNotice(checklist) }
                    PreVisitChecksCard(
                        checklist: checklist, serviceName: visit.appointment.serviceName, formatters: formatters,
                        now: now
                    )
                    reminderRow(visit, formatters: formatters, now: now)
                    if let previous = viewModel.previousVisit {
                        AppointmentPreviousVisitCard(
                            visit: previous, formatters: formatters, now: now,
                            loadThumbnail: viewModel.thumbnail(for:),
                            onOpen: { recordRoute = .visit(recordID: previous.id) }
                        )
                    }
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

    /// Her name opens her record: the history, photos and everything she knows about the client.
    private func header(_ visit: VisitContext, formatters: Formatters, now: Date) -> some View {
        NavigationLink(value: AgendaRoute.clientRecord(clientID: visit.client.id)) {
            headerContent(visit, formatters: formatters)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("appointment.clientRecord.hint"))
        .accessibilityIdentifier("appointment.clientRecordLink")
    }

    private func headerContent(_ visit: VisitContext, formatters: Formatters) -> some View {
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
            Image(icon: .forward)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.ink2)
                .flipsForRightToLeftLayoutDirection(true)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
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

    @ViewBuilder
    private func manualBookingNotice(_ issue: ManualBookingSyncIssue, appointmentID: UUID) -> some View {
        switch issue {
        case .conflict:
            InlineNotice(
                style: .warning, title: "appointment.manualSync.conflict.title",
                message: "appointment.manualSync.conflict.message"
            )
        case .failed:
            VStack(alignment: .leading, spacing: Spacing.sm) {
                InlineNotice(
                    style: .warning, title: "appointment.manualSync.failed.title",
                    message: "appointment.manualSync.failed.message"
                )
                Button("appointment.error.retry") {
                    clientLinks.retryManualBooking(
                        id: appointmentID, timeZoneID: CalendarSettings(profile: profile.profile).timeZoneID,
                        locale: profile.profile?.appLocaleID
                    )
                }
                .buttonStyle(.belloSecondary)
                .accessibilityIdentifier("appointment.retryManualBookingButton")
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
        case .waiting(let state):
            // Opening WhatsApp proves no sending (routine-a item 6): the line says what is known, her own mark is
            // called hers, and "I sent it" is offered while only the chat was opened.
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(verbatim: FollowUpReasonText(formatters: formatters).delivery(state))
                        Text("appointment.reminder.noReply")
                    }
                } icon: { Image(icon: .clock) }
                .font(Typography.meta)
                .foregroundStyle(Palette.amberText)
                .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Spacing.row) {
                    if state.isOpened {
                        Button { viewModel.markReminderSent() } label: {
                            Text("followUpQueue.action.sent")
                                .font(Typography.metaStrong)
                                .foregroundStyle(Palette.roseText)
                                .frame(minHeight: Spacing.touchTarget)
                        }
                        .accessibilityIdentifier("appointment.reminderSentButton")
                    }
                    Spacer(minLength: Spacing.sm)
                    Button { sheet = .message(appointmentID: visit.appointment.id) } label: {
                        Text("appointment.reminder.remind")
                            .font(Typography.metaStrong)
                            .foregroundStyle(Palette.roseText)
                            .frame(minHeight: Spacing.touchTarget)
                    }
                    .accessibilityIdentifier("appointment.remindAgainButton")
                }
            }
            .padding(Spacing.md)
            .background(Palette.amberBg, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("appointment.reminderWaiting")
        }
    }
}

// MARK: - Links

extension AppointmentContentView {
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
        case .registerVisit, .continueRecord: visitFlow = viewModel.visitFlowRequest
        case .openRecord:
            if let record = viewModel.record { recordRoute = .visit(recordID: record.id) }
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
