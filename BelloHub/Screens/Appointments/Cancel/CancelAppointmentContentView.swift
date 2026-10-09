//
//  CancelAppointmentContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of 3.5: who is cancelling, what it means for the client under her rules, the message to her, and the
/// confirmation. After it is saved the sheet says so and, when she asked for a message, how the chat was opened.
struct CancelAppointmentContentView: View {
    @State private var viewModel: CancelAppointmentViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(
        appointmentID: UUID, appointments: AppointmentService, vault: VaultService, profile: ProfileService,
        setup: BookingSetupService, messages: MessageService
    ) {
        _viewModel = State(initialValue: CancelAppointmentViewModel(
            appointmentID: appointmentID, appointments: appointments, vault: vault, profile: profile, setup: setup,
            messages: messages
        ))
    }

    var body: some View {
        NavigationStack {
            content
                .background(Palette.bg)
                .navigationTitle(Text("cancelAppointment.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: { Text("common.close") }
                            .accessibilityIdentifier("cancelAppointment.closeButton")
                    }
                }
        }
        .task { await viewModel.loadAsync() }
        .presentationDetents([.large])
        .presentationBackground(Palette.bg)
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        if let done = viewModel.done {
            finished(done)
        } else if let visit = viewModel.visit {
            form(visit)
        } else {
            VisitStateView(
                prefix: "cancelAppointment", isMissing: viewModel.isMissing, errorMessage: viewModel.errorMessage,
                retry: viewModel.load
            )
        }
    }

    // MARK: - Form

    private func form(_ visit: VisitContext) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VisitSummaryRow(
                    visit: visit, formatters: viewModel.business.formatters(displayLocale: locale), now: Date(),
                    identifier: "cancelAppointment.summary"
                )
                if viewModel.canCancel {
                    if let message = viewModel.actionErrorMessage {
                        ErrorNotice(
                            message: message, actionTitle: "appointment.error.dismiss",
                            action: viewModel.dismissActionError
                        )
                            .accessibilityIdentifier("cancelAppointment.saveError")
                    }
                    who(visit)
                    notice(visit)
                    if viewModel.offersMessage { messageCard(visit) }
                } else {
                    InlineNotice(style: .info, title: "cancelAppointment.closed")
                        .accessibilityIdentifier("cancelAppointment.closed")
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
        }
        .safeAreaInset(edge: .bottom) { if viewModel.canCancel { buttons } }
        .accessibilityIdentifier("cancelAppointment.form")
    }

    private func who(_ visit: VisitContext) -> some View {
        let name = firstName(visit.client)
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("cancelAppointment.who")
                .font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                .accessibilityAddTraits(.isHeader)
            ChoiceCard(
                title: String(localized: "cancelAppointment.who.me", locale: locale),
                subtitle: String(localized: "cancelAppointment.who.me.detail", locale: locale),
                isSelected: viewModel.cancelledBy == .professional, identifier: "cancelAppointment.who.professional"
            ) { viewModel.cancelledBy = .professional }
            ChoiceCard(
                title: LocalizedStringResource("cancelAppointment.who.client", defaultValue: "\(name) is cancelling")
                    .resolved(in: locale),
                subtitle: String(localized: "cancelAppointment.who.client.detail", locale: locale),
                isSelected: viewModel.cancelledBy == .client, identifier: "cancelAppointment.who.client"
            ) { viewModel.cancelledBy = .client }
        }
    }

    @ViewBuilder
    private func notice(_ visit: VisitContext) -> some View {
        let name = firstName(visit.client)
        switch viewModel.notice {
        case .byProfessional:
            InlineNotice(style: .info, title: Text(LocalizedStringResource(
                "cancelAppointment.notice.professional",
                defaultValue: "Cancelled by you, so it does not count against \(name)."
            ).localized(in: locale)))
            .accessibilityIdentifier("cancelAppointment.notice")
        case .clientInTime(let hours):
            InlineNotice(style: .info, title: Text(LocalizedStringResource(
                "cancelAppointment.notice.inTime",
                defaultValue: "\(name) is cancelling in time (free up to \(hours) hours before). Nothing is noted."
            ).localized(in: locale)))
            .accessibilityIdentifier("cancelAppointment.notice")
        case .clientLate(let hours, let counts):
            InlineNotice(style: .warning, title: lateText(hours: hours, counts: counts, name: name))
                .accessibilityIdentifier("cancelAppointment.notice")
        case nil:
            EmptyView()
        }
    }

    private func lateText(hours: Int, counts: Bool, name: String) -> Text {
        if counts {
            return Text(LocalizedStringResource(
                "cancelAppointment.notice.lateCounts",
                defaultValue: """
                This is inside the \(hours)-hour free window. It is saved as a late cancellation and counts \
                toward \(name)'s limit.
                """
            ).localized(in: locale))
        }
        return Text(LocalizedStringResource(
            "cancelAppointment.notice.late",
            defaultValue: """
            This is inside the \(hours)-hour free window. It is saved as a late cancellation, and your rule does \
            not count it toward \(name)'s limit.
            """
        ).localized(in: locale))
    }

    private func messageCard(_ visit: VisitContext) -> some View {
        let name = firstName(visit.client)
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Toggle(isOn: $viewModel.sendsMessage) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(LocalizedStringResource("cancelAppointment.message.title", defaultValue: "Message \(name)")
                        .localized(in: locale))
                        .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    Text("cancelAppointment.message.detail").font(Typography.meta).foregroundStyle(Palette.ink2)
                }
            }
            .tint(Palette.sage)
            .frame(minHeight: Spacing.touchTarget)
            .accessibilityIdentifier("cancelAppointment.messageToggle")
            if viewModel.sendsMessage, let preview = viewModel.messagePreview {
                Text(verbatim: preview)
                    .font(Typography.meta).foregroundStyle(Palette.sageText)
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.sageWash, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                    .accessibilityIdentifier("cancelAppointment.messagePreview")
            }
        }
        .padding(Spacing.md)
        .belloCard(cornerRadius: Radius.tile)
    }

    private var buttons: some View {
        VStack(spacing: Spacing.sm) {
            Button { viewModel.confirm() } label: {
                if viewModel.isWorking { ProgressView() } else { Text("cancelAppointment.confirm") }
            }
            .buttonStyle(.belloPrimary)
            .disabled(viewModel.isWorking)
            .accessibilityIdentifier("cancelAppointment.confirmButton")
            Button { dismiss() } label: { Text("cancelAppointment.keep") }
                .buttonStyle(.belloTertiary)
                .accessibilityIdentifier("cancelAppointment.keepButton")
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
    }

    // MARK: - Done

    private func finished(_ done: CancelAppointmentViewModel.Done) -> some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                SuccessSeal().padding(.top, Spacing.xl)
                Text("cancelAppointment.done.title")
                    .font(Typography.title).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("cancelAppointment.done.title")
                if let message = done.message { messageOutcome(message) }
                Button { dismiss() } label: { Text("appointment.done") }
                    .buttonStyle(.belloPrimary)
                    .accessibilityIdentifier("cancelAppointment.doneButton")
            }
            .padding(.horizontal, Spacing.gutter)
        }
        .accessibilityIdentifier("cancelAppointment.done")
    }

    @ViewBuilder
    private func messageOutcome(_ outcome: MessageService.Outcome) -> some View {
        switch outcome {
        case .opened(let channel):
            Text(channel == .whatsapp ? "appointment.opened.whatsapp" : "appointment.opened.sms")
                .font(Typography.meta).foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("cancelAppointment.opened")
        case .needsShareSheet(let text):
            ShareFallbackCard(text: text, identifier: "cancelAppointment.shareFallback")
        }
    }

    private func firstName(_ client: Client) -> String {
        client.name.split(separator: " ").first.map(String.init) ?? client.name
    }
}
