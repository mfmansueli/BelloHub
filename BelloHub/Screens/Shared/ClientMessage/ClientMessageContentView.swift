//
//  ClientMessageContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of the client message sheet: who it goes to, the text ready to read and edit, and the button that opens
/// the chat. She always reads it before it opens (D14: the app never sends by itself).
struct ClientMessageContentView: View {
    @State private var viewModel: ClientMessageViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(
        request: ClientMessageRequest, appointments: AppointmentService, vault: VaultService, profile: ProfileService,
        setup: BookingSetupService, messages: MessageService
    ) {
        _viewModel = State(initialValue: ClientMessageViewModel(
            request: request, appointments: appointments, vault: vault, profile: profile, setup: setup,
            messages: messages
        ))
    }

    var body: some View {
        NavigationStack {
            content
                .background(Palette.bg)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: { Text("common.close") }
                            .accessibilityIdentifier("clientMessage.closeButton")
                    }
                }
        }
        .task { await viewModel.loadAsync() }
        .presentationDetents([.large])
        .presentationBackground(Palette.bg)
    }

    private var title: Text {
        guard let client = viewModel.client else { return Text("messageClient.title.plain") }
        let name = client.firstName
        return Text(LocalizedStringResource("messageClient.title", defaultValue: "Message \(name)")
            .localized(in: locale))
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        if let client = viewModel.client {
            form(client)
        } else if viewModel.isMissing {
            EmptyState(
                icon: .user, title: Text("clientMessage.missing.title"), message: Text("clientMessage.missing.message")
            )
            .accessibilityIdentifier("clientMessage.missing")
            .frame(maxHeight: .infinity)
        } else if let message = viewModel.errorMessage {
            EmptyState(
                icon: .alert, title: Text("appointment.error.title"), message: Text(verbatim: message),
                actionTitle: "appointment.error.retry", action: viewModel.load
            )
            .accessibilityIdentifier("clientMessage.error")
            .frame(maxHeight: .infinity)
        } else {
            ListLoadingView(rows: 3)
                .padding(Spacing.gutter)
                .frame(maxHeight: .infinity, alignment: .top)
                .accessibilityIdentifier("clientMessage.loading")
        }
    }

    // MARK: - Form

    private func form(_ client: Client) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HStack(spacing: Spacing.row) {
                    Avatar(name: client.name, id: client.id.uuidString, size: 52)
                    Text(verbatim: client.name)
                        .font(Typography.subtitle).foregroundStyle(Palette.ink)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("clientMessage.summary")
                Text(viewModel.hasNumber ? "clientMessage.subtitle" : "clientMessage.subtitle.noNumber")
                    .font(Typography.body).foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("clientMessage.subtitle")
                BelloNoteField(
                    title: Text("messageClient.replies"), text: $viewModel.draft, identifier: "clientMessage.draft"
                )
                outcome
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
        }
        .accessibilityIdentifier("clientMessage.form")
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { openButton }
    }

    @ViewBuilder
    private var outcome: some View {
        switch viewModel.outcome {
        case .opened(let channel)?:
            HStack(spacing: Spacing.sm) {
                InlineCheck()
                Text(channel == .whatsapp ? "appointment.opened.whatsapp" : "appointment.opened.sms")
                    .font(Typography.meta).foregroundStyle(Palette.sageText)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("clientMessage.opened")
        case .needsShareSheet(let text)?:
            ShareFallbackCard(text: text, identifier: "clientMessage.shareFallback")
        case nil:
            EmptyView()
        }
    }

    private var openButton: some View {
        Button { viewModel.open() } label: {
            if viewModel.isWorking {
                ProgressView()
            } else {
                Text(viewModel.hasNumber ? "messageClient.open" : "messageClient.share")
            }
        }
        .buttonStyle(.belloPrimary)
        .disabled(!viewModel.canOpen)
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
        .accessibilityIdentifier("clientMessage.openButton")
    }
}
