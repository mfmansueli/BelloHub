//
//  SuggestTimeSheet.swift
//  BelloHub
//

import SwiftUI

/// "Suggest another time" (2.10): she picks a day and time; the server declines the request and holds that time for
/// the client; then she sends the link with the system share sheet (WhatsApp is one tap there). Before the server
/// answered nothing changed; offline it says so.
struct SuggestTimeSheet: View {
    @Bindable var viewModel: BookingRequestViewModel
    let clientName: String
    let timeZone: TimeZone

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text("bookingRequest.suggest.message").font(Typography.body).foregroundStyle(Palette.ink2)
                    if viewModel.isSuggested { sent } else { picker }
                    if let message = viewModel.suggestionErrorMessage {
                        ErrorNotice(message: message).accessibilityIdentifier("bookingRequest.suggest.error")
                    }
                }
                .padding(Spacing.gutter)
            }
            .background(Palette.bg)
            .navigationTitle(Text("bookingRequest.suggest.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.close") }
                        .accessibilityIdentifier("bookingRequest.suggest.closeButton")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !viewModel.isSuggested {
                    Button(action: viewModel.suggest) { Text("bookingRequest.suggest.send") }
                        .buttonStyle(.belloPrimary)
                        .disabled(viewModel.isSuggesting)
                        .accessibilityIdentifier("bookingRequest.suggest.sendButton")
                        .padding(.horizontal, Spacing.gutter)
                        .padding(.vertical, Spacing.md)
                        .background(Palette.bg)
                }
            }
        }
    }

    private var picker: some View {
        DatePicker(
            selection: $viewModel.suggestedStart, in: Date()...,
            displayedComponents: [.date, .hourAndMinute]
        ) {
            Text("bookingRequest.suggest.when")
        }
        .datePickerStyle(.graphical)
        .environment(\.timeZone, timeZone)
        .padding(Spacing.md)
        .belloCard(cornerRadius: Radius.tile)
        .accessibilityIdentifier("bookingRequest.suggest.picker")
    }

    @ViewBuilder
    private var sent: some View {
        InlineNotice(
            style: .info, title: "bookingRequest.suggest.held.title", message: "bookingRequest.suggest.held.message"
        )
        .accessibilityIdentifier("bookingRequest.suggest.held")
        if let url = viewModel.suggestionURL {
            ShareLink(item: url, message: Text(shareMessage)) {
                Label { Text("bookingRequest.suggest.share") } icon: { Image(icon: .share) }
            }
            .buttonStyle(.belloPrimary)
            .accessibilityIdentifier("bookingRequest.suggest.shareButton")
        }
    }

    /// "Hi Ana! That time does not work for me. Could you come at this one instead?"
    private var shareMessage: LocalizedStringResource {
        LocalizedStringResource(
            "bookingRequest.suggest.shareMessage",
            defaultValue: """
            Hi \(BidiIsolate.wrap(firstName))! That time does not work for me. Could you come at this one instead?
            """
        ).localized(in: locale)
    }

    private var firstName: String {
        clientName.split(separator: " ").first.map(String.init) ?? clientName
    }
}
