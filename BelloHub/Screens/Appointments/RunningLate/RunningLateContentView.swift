//
//  RunningLateContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of 2.12: how late she will be and the clients to tell, one chat each. The calendar does not change, and
/// nothing is sent by the app: each button opens a chat with the message ready.
struct RunningLateContentView: View {
    @State private var viewModel: RunningLateViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(
        appointmentID: UUID, appointments: AppointmentService, vault: VaultService, profile: ProfileService,
        setup: BookingSetupService, messages: MessageService
    ) {
        _viewModel = State(initialValue: RunningLateViewModel(
            appointmentID: appointmentID, appointments: appointments, vault: vault, profile: profile, setup: setup,
            messages: messages
        ))
    }

    var body: some View {
        NavigationStack {
            content
                .background(Palette.bg)
                .navigationTitle(Text("runningLate.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: { Text("common.close") }
                            .accessibilityIdentifier("runningLate.closeButton")
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
        if viewModel.isLoading || viewModel.isMissing || viewModel.errorMessage != nil {
            VisitStateView(
                prefix: "runningLate", isMissing: viewModel.isMissing, errorMessage: viewModel.errorMessage,
                retry: viewModel.load
            )
        } else {
            form
        }
    }

    // MARK: - Form

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("runningLate.subtitle").font(Typography.body).foregroundStyle(Palette.ink2)
                delay
                if viewModel.showsLongWaitHint {
                    InlineNotice(style: .warning, title: "runningLate.longWait")
                        .accessibilityIdentifier("runningLate.longWait")
                }
                recipients
                if let share = viewModel.share {
                    ShareFallbackCard(text: share.text, identifier: "runningLate.shareFallback")
                }
                FooterNote(text: "runningLate.footer", icon: .chat)
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
        }
        .safeAreaInset(edge: .bottom) { doneButton }
        .accessibilityIdentifier("runningLate.form")
    }

    private var delay: some View {
        let formatters = viewModel.business.formatters(displayLocale: locale)
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("runningLate.how").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                .accessibilityAddTraits(.isHeader)
            FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm, wrapsLongChildren: true) {
                ForEach(RunningLateRules.delayOptions, id: \.self) { minutes in
                    Button { viewModel.delay = minutes } label: { Text(verbatim: formatters.minutes(minutes)) }
                        .buttonStyle(.belloChip(selected: viewModel.delay == minutes))
                        .accessibilityAddTraits(viewModel.delay == minutes ? .isSelected : [])
                        .accessibilityIdentifier("runningLate.delay.\(minutes)")
                }
            }
        }
    }

    private var recipients: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("runningLate.who").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                .accessibilityAddTraits(.isHeader)
            ListCard(dividerInset: Spacing.md) {
                ForEach(viewModel.recipients) { recipient in row(recipient) }
            }
        }
    }

    private func row(_ recipient: RunningLateViewModel.Recipient) -> some View {
        let formatters = viewModel.business.formatters(displayLocale: locale)
        let isOpened = viewModel.opened.contains(recipient.id)
        return HStack(spacing: Spacing.row) {
            Avatar(name: recipient.client.name, id: recipient.client.id.uuidString, size: 44)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: recipient.client.name).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Text(verbatim: "\(formatters.time(recipient.appointment.startsAt)) · "
                    + recipient.appointment.serviceName)
                    .font(Typography.meta).foregroundStyle(Palette.ink2)
            }
            Spacer(minLength: Spacing.sm)
            Button { viewModel.tell(recipient) } label: {
                if isOpened {
                    Label { Text("runningLate.opened") } icon: { Image(icon: .check) }
                } else {
                    Text("runningLate.tell")
                }
            }
            .font(Typography.metaStrong)
            .foregroundStyle(isOpened ? Palette.sageText : Palette.roseText)
            .frame(minWidth: Spacing.touchTarget, minHeight: Spacing.touchTarget)
            .disabled(viewModel.isWorking)
            .accessibilityIdentifier("runningLate.tell.\(recipient.id.uuidString)")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("runningLate.row.\(recipient.id.uuidString)")
    }

    private var doneButton: some View {
        Button { dismiss() } label: { Text("appointment.done") }
            .buttonStyle(.belloPrimary)
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
            .background(Palette.bg)
            .accessibilityIdentifier("runningLate.doneButton")
    }
}
