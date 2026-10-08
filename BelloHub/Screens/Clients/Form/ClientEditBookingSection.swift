//
//  ClientEditBookingSection.swift
//  BelloHub
//

import SwiftUI

/// "Online booking" and "Reminders and follow-ups" on the edit screen: whether the client can book through the link and
/// whether the app may remind her. Stopping online booking takes a private reason (sealed in the vault) and never
/// touches her existing appointments. The words are neutral: no "she", so they read right for every client term.
struct ClientEditBookingSection: View {
    @Bindable var viewModel: ClientFormViewModel
    /// The professional's first name, who the booking page tells the client to message.
    let professionalName: String
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("clientEdit.booking.title")
                .font(Typography.metaStrong)
                .foregroundStyle(Palette.ink2)
                .accessibilityAddTraits(.isHeader)
            ListCard(dividerInset: Spacing.md) {
                ToggleRow(
                    title: text(LocalizedStringResource(
                        "clientEdit.stop.title", defaultValue: "Stop online booking for \(clientName)"
                    )),
                    subtitle: text(LocalizedStringResource("clientEdit.stop.subtitle")),
                    isOn: $viewModel.draft.onlineBookingStopped, identifier: "clientEdit.stopBookingToggle"
                )
            }
            if viewModel.draft.onlineBookingStopped {
                BelloTextField(
                    title: "clientEdit.stop.reason", text: $viewModel.draft.stopReason,
                    prompt: "clientEdit.stop.reasonPrompt", isSensitive: true, identifier: "clientEdit.stopReasonField"
                )
                .padding(.top, Spacing.sm)
                Text(text(LocalizedStringResource(
                    "clientEdit.stop.hint",
                    defaultValue: """
                    On your booking page the message reads: Please message \(BidiIsolate.wrap(professionalName)) \
                    to book. Existing appointments are not touched.
                    """
                )))
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.ink2)
            }
            ListCard(dividerInset: Spacing.md) {
                ToggleRow(
                    title: text(LocalizedStringResource("clientEdit.reminders.title")),
                    subtitle: text(LocalizedStringResource("clientEdit.reminders.subtitle")),
                    isOn: $viewModel.draft.remindersEnabled, identifier: "clientEdit.remindersToggle"
                )
            }
            .padding(.top, Spacing.md)
        }
    }

    private var clientName: String {
        BidiIsolate.wrap(viewModel.firstName)
    }

    private func text(_ resource: LocalizedStringResource) -> String {
        String(localized: resource.localized(in: locale))
    }
}
