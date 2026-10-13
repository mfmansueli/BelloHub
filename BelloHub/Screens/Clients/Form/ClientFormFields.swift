//
//  ClientFormFields.swift
//  BelloHub
//

import SwiftUI

/// The three fields the new-client sheet and the edit screen share: name, WhatsApp number and email. A problem shows
/// next to its field after the first tap on Save, and the number's problem is the normalizer's own (too short, not a
/// number of this country). When another client already has the number, the form says so and offers to open her.
struct ClientFormFields: View {
    @Bindable var viewModel: ClientFormViewModel
    /// `newClient` or `clientEdit`: the first part of every identifier.
    let idPrefix: String
    let onOpenExisting: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            BelloTextField(
                title: "clientForm.name", text: $viewModel.draft.name, prompt: "clientForm.name.prompt",
                errorMessage: viewModel.nameIssue == nil ? nil : "clientForm.name.missing",
                identifier: "\(idPrefix).nameField"
            )
            .textContentType(.name)
            .textInputAutocapitalization(.words)
            BelloTextField(
                title: "clientForm.phone", text: $viewModel.draft.phone, prompt: "clientForm.phone.prompt",
                errorMessage: phoneErrorMessage, identifier: "\(idPrefix).phoneField"
            )
            .keyboardType(.phonePad)
            .textContentType(.telephoneNumber)
            BelloTextField(
                title: "clientForm.confirmPhone", text: $viewModel.draft.confirmPhone,
                prompt: "clientForm.confirmPhone.prompt",
                errorMessage: confirmPhoneErrorMessage, identifier: "\(idPrefix).confirmPhoneField"
            )
            .keyboardType(.phonePad)
            .textContentType(.telephoneNumber)
            if let existing = viewModel.duplicateNotice {
                duplicateNotice(existing)
            }
            BelloTextField(
                title: "clientForm.email", text: $viewModel.draft.email, prompt: "clientForm.email.prompt",
                errorMessage: emailErrorMessage,
                identifier: "\(idPrefix).emailField"
            )
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            BelloTextField(
                title: "clientForm.confirmEmail", text: $viewModel.draft.confirmEmail,
                prompt: "clientForm.confirmEmail.prompt",
                errorMessage: confirmEmailErrorMessage,
                identifier: "\(idPrefix).confirmEmailField"
            )
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
    }

    private var phoneErrorMessage: LocalizedStringKey? {
        if viewModel.phoneMissing { return "clientForm.phone.missing" }
        if let failure = viewModel.phoneFailure { return Self.message(for: failure) }
        return nil
    }

    private var confirmPhoneErrorMessage: LocalizedStringKey? {
        if viewModel.phoneMismatch { return "clientForm.phone.mismatch" }
        return nil
    }

    private var emailErrorMessage: LocalizedStringKey? {
        if viewModel.emailMissing { return "clientForm.email.missing" }
        if viewModel.emailIssue != nil { return "clientForm.email.invalid" }
        return nil
    }

    private var confirmEmailErrorMessage: LocalizedStringKey? {
        if viewModel.emailMismatch { return "clientForm.email.mismatch" }
        return nil
    }

    private func duplicateNotice(_ existingID: UUID) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            InlineNotice(style: .warning, title: "clientForm.duplicate.title", message: "clientForm.duplicate.message")
            Button { onOpenExisting(existingID) } label: { Text("clientForm.duplicate.open") }
                .buttonStyle(.belloSecondary)
                .accessibilityIdentifier("\(idPrefix).openExistingButton")
        }
        .accessibilityIdentifier("\(idPrefix).duplicateNotice")
    }

    /// The same two sentences the sign-in screen uses for a phone number that cannot be right.
    private static func message(for failure: PhoneNormalizer.Failure) -> LocalizedStringKey {
        switch failure {
        case .empty, .tooShort: "onb.signIn.error.phoneShort"
        case .tooLong, .implausibleLength: "onb.signIn.error.phone"
        }
    }
}
