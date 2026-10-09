//
//  CredentialsContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of 6.10: the switch that shows her credentials on her booking page, the list of courses and certificates
/// (tap to change, swipe to delete), her professional registration number and a preview of what clients see. A native
/// `List`, for the same reasons as the other lists of the business section.
struct CredentialsContentView: View {
    @State private var viewModel: CredentialsViewModel
    @State private var editor: CredentialEditorMode?
    @State private var pendingDeletion: Credential?
    @State private var showsPreview = false
    @FocusState private var isRegistrationFocused: Bool
    @Environment(\.locale) private var locale

    init(repository: (any CatalogRepository)?, profile: ProfileService, locale: Locale) {
        let zone = profile.profile.flatMap { TimeZone(identifier: $0.timeZoneID) } ?? .current
        _viewModel = State(initialValue: CredentialsViewModel(repository: repository, locale: locale, timeZone: zone))
    }

    var body: some View {
        List {
            Section {
                Text("credentials.subtitle")
                    .font(Typography.body).foregroundStyle(Palette.ink2)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: Spacing.sm, bottom: Spacing.sm, trailing: Spacing.sm))
            }
            notices
            Section { pageSwitch }
            credentialsSection
            registrationSection
            Section { previewButton.listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.bg)
        .navigationTitle(Text("credentials.title"))
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await viewModel.loadAsync() }
        .task { await viewModel.loadAsync() }
        .onChange(of: isRegistrationFocused) { _, isFocused in
            if !isFocused { viewModel.commitRegistration() }
        }
        .onDisappear { viewModel.commitRegistration() }
        .sheet(item: $editor) { mode in
            CredentialEditorSheet(mode: mode, viewModel: viewModel)
        }
        .sheet(isPresented: $showsPreview) {
            CredentialsPreviewSheet(
                trainings: viewModel.trainings, registration: viewModel.registration,
                showsOnPage: viewModel.showsOnPage, details: viewModel.details(of:)
            )
        }
        .deletionDialog(
            $pendingDeletion,
            title: { credential in
                Text(LocalizedStringResource(
                    "credentials.delete.title", defaultValue: "Delete “\(credential.title)”?"
                ).localized(in: locale))
            },
            message: { _ in Text("credentials.delete.message") },
            confirm: DeletionConfirm(
                title: "credentials.delete.confirm", identifier: "credentials.deleteConfirmButton"
            ),
            onConfirm: { credential in Task { await viewModel.delete(credential) } }
        )
    }

    // MARK: - Notices

    @ViewBuilder
    private var notices: some View {
        if let message = viewModel.errorMessage {
            Section {
                ErrorNotice(message: message, actionTitle: "credentials.retry", action: viewModel.load)
                    .accessibilityIdentifier("credentials.error")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        if let message = viewModel.saveErrorMessage {
            Section {
                ErrorNotice(message: message, actionTitle: "credentials.dismiss", action: viewModel.dismissSaveError)
                    .accessibilityIdentifier("credentials.saveError")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
    }

    // MARK: - Page switch

    private var pageSwitch: some View {
        Toggle(isOn: Binding(get: { viewModel.showsOnPage }, set: { viewModel.setShowsOnPage($0) })) {
            HStack(spacing: Spacing.row) {
                Image(icon: .globe)
                    .foregroundStyle(Palette.sageText)
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                    .background(
                        Palette.sageWash, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("credentials.show.title").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    Text(viewModel.showsOnPage ? "credentials.show.on" : "credentials.show.off")
                        .font(Typography.meta).foregroundStyle(Palette.ink2)
                }
            }
        }
        .tint(Palette.sage)
        .frame(minHeight: 64)
        .listRowBackground(Palette.surface)
        .accessibilityIdentifier("credentials.showToggle")
    }

    // MARK: - Credentials

    private var credentialsSection: some View {
        Section {
            if viewModel.showsSkeleton {
                ForEach(0..<2, id: \.self) { _ in Skeleton(height: 56).listRowBackground(Palette.surface) }
            }
            if viewModel.showsEmptyState {
                Text("credentials.empty")
                    .font(Typography.meta).foregroundStyle(Palette.ink2)
                    .frame(minHeight: 56, alignment: .leading)
                    .listRowBackground(Palette.surface)
                    .accessibilityIdentifier("credentials.empty")
            }
            ForEach(viewModel.trainings) { credential in
                Button { editor = .edit(credential) } label: {
                    CredentialRow(credential: credential, details: viewModel.details(of: credential))
                }
                .buttonStyle(.plain)
                .listRowBackground(Palette.surface)
                .listRowInsets(EdgeInsets(top: 0, leading: Spacing.md, bottom: 0, trailing: Spacing.md))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) { pendingDeletion = credential } label: {
                        Text("credentials.delete.action")
                    }
                    .accessibilityIdentifier("credentials.deleteAction.\(credential.id.uuidString)")
                }
                .accessibilityIdentifier("credentials.row.\(credential.id.uuidString)")
                .accessibilityHint(Text("credentials.row.hint"))
            }
            if viewModel.hasLoaded { addRow }
        } header: {
            Text("credentials.section.yours")
                .font(Typography.section).foregroundStyle(Palette.ink)
                .textCase(nil)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var addRow: some View {
        Button { editor = .add } label: {
            HStack(spacing: Spacing.row) {
                Image(icon: .plus)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                Text("credentials.add").font(Typography.bodyStrong)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Palette.roseText)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Palette.surface)
        .listRowInsets(EdgeInsets(top: 0, leading: Spacing.md, bottom: 0, trailing: Spacing.md))
        .accessibilityIdentifier("credentials.addButton")
    }

    // MARK: - Registration

    private var registrationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("credentials.registration.title").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Text("credentials.registration.hint").font(Typography.meta).foregroundStyle(Palette.ink2)
                TextField(
                    text: $viewModel.registrationText, prompt: .prompt("credentials.registration.prompt")
                ) { Text("credentials.registration.title") }
                    .font(Typography.body)
                    .foregroundStyle(viewModel.isRegistrationValid ? Palette.ink : Palette.coralText)
                    .focused($isRegistrationFocused)
                    .submitLabel(.done)
                    .onSubmit { isRegistrationFocused = false }
                    .padding(.horizontal, Spacing.md)
                    .frame(minHeight: 52)
                    .background(Palette.sunken, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
                            .strokeBorder(Palette.fieldBorder, lineWidth: 1.5)
                    }
                    .accessibilityIdentifier("credentials.registrationField")
                if !viewModel.isRegistrationValid {
                    Text("credentials.registration.tooLong")
                        .font(Typography.footnote).foregroundStyle(Palette.coralText)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .padding(.vertical, Spacing.row)
            .listRowBackground(Palette.surface)
        } header: {
            Text("credentials.section.registration")
                .font(Typography.section).foregroundStyle(Palette.ink)
                .textCase(nil)
                .accessibilityAddTraits(.isHeader)
        }
    }

    // MARK: - Preview

    private var previewButton: some View {
        Button { showsPreview = true } label: { Text("credentials.preview") }
            .buttonStyle(.belloSecondary)
            .padding(.vertical, Spacing.md)
            .accessibilityIdentifier("credentials.previewButton")
    }
}
