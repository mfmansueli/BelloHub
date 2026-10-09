//
//  ConsentRecordSheet.swift
//  BelloHub
//

import PhotosUI
import SwiftUI

/// The sheet that records a consent (D55): what it is about, her own label, signed or not and when, a note, and an
/// optional photo or file of the real signed paper. Editing an existing record also offers to delete it. Sealed in
/// the vault when she saves; the paper itself stays with her.
struct ConsentRecordSheet: View {
    @Bindable var viewModel: ConsentRecordViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var isImportingFile = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SheetHeader(
                    title: viewModel.isEditing ? "consent.title.edit" : "consent.title.new",
                    subtitle: "consent.subtitle", closeLabel: "common.close",
                    closeIdentifier: "consent.closeButton", onClose: { dismiss() }
                )
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    kindChips
                    BelloTextField(
                        title: "consent.label", text: $viewModel.draft.label, prompt: "consent.label.prompt",
                        isSensitive: true, identifier: "consent.labelField"
                    )
                    signedSection
                    BelloNoteField(
                        title: Text("consent.note"), text: $viewModel.draft.note, prompt: "healthForm.optional",
                        isSensitive: true, identifier: "consent.noteField"
                    )
                    documentSection
                    if viewModel.isEditing { deleteButton }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.lg)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { saveBar }
        .background(Palette.bg)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onChange(of: viewModel.didSave) { _, didSave in
            if didSave { dismiss() }
        }
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
        .fileImporter(isPresented: $isImportingFile, allowedContentTypes: viewModel.allowedFileTypes) { outcome in
            Task { await viewModel.attachFile(outcome) }
        }
        .confirmationDialog(
            Text("consent.delete.confirm"), isPresented: $viewModel.isConfirmingDelete, titleVisibility: .visible
        ) {
            Button(role: .destructive) { viewModel.delete() } label: { Text("consent.delete") }
                .accessibilityIdentifier("consent.deleteConfirmButton")
            Button(role: .cancel) {} label: { Text("common.cancel") }
        }
    }

    // MARK: - Parts

    private var kindChips: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("consent.kind").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
            FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm, wrapsLongChildren: true) {
                ForEach(ConsentKind.allCases) { kind in
                    Button { viewModel.draft.kind = kind } label: { Text(kind.title.localized(in: locale)) }
                        .buttonStyle(.belloChip(selected: viewModel.draft.kind == kind))
                        .accessibilityAddTraits(viewModel.draft.kind == kind ? .isSelected : [])
                        .accessibilityIdentifier("consent.kind.\(kind.rawValue)")
                }
            }
        }
    }

    /// The switch and, while it is on, the day. The whole card is the native toggle, so VoiceOver finds one switch.
    private var signedSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ToggleRow(
                title: text("consent.signed"), subtitle: text("consent.signed.subtitle"),
                isOn: $viewModel.draft.isSigned, identifier: "consent.signedToggle"
            )
            .belloCard()
            if viewModel.draft.isSigned {
                DatePicker(selection: $viewModel.draft.signedAt, displayedComponents: .date) {
                    Text("consent.date").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                }
                .tint(Palette.roseText)
                .frame(minHeight: Spacing.touchTarget)
                .accessibilityIdentifier("consent.datePicker")
            }
        }
    }

    private var documentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("consent.document").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
            if let document = viewModel.draft.document {
                ConsentDocumentPreview(document: document)
                Button { viewModel.removeDocument() } label: {
                    Label { Text("consent.document.remove") } icon: { Image(icon: .trash) }
                }
                .buttonStyle(.belloTertiary)
                .accessibilityIdentifier("consent.removeDocumentButton")
            } else if viewModel.isPreparingDocument {
                HStack(spacing: Spacing.row) {
                    ProgressView().accessibilityHidden(true)
                    Text("treatmentFlow.photos.processing").font(Typography.body).foregroundStyle(Palette.ink2)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("consent.preparingDocument")
            } else {
                Text("consent.document.hint").font(Typography.footnote).foregroundStyle(Palette.ink2)
                FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm, wrapsLongChildren: true) {
                    PhotosPicker(selection: $pickedPhoto, matching: .images) {
                        Label { Text("consent.document.addPhoto") } icon: { Image(icon: .image) }
                    }
                    .buttonStyle(.belloSecondary)
                    .accessibilityIdentifier("consent.addPhotoButton")
                    Button { isImportingFile = true } label: {
                        Label { Text("consent.document.addFile") } icon: { Image(icon: .document) }
                    }
                    .buttonStyle(.belloSecondary)
                    .accessibilityIdentifier("consent.addFileButton")
                }
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) { viewModel.isConfirmingDelete = true } label: {
            Label { Text("consent.delete") } icon: { Image(icon: .trash) }
        }
        .buttonStyle(.belloTertiary)
        .accessibilityIdentifier("consent.deleteButton")
    }

    private var saveBar: some View {
        VStack(spacing: Spacing.sm) {
            if let message = viewModel.errorMessage {
                Text(verbatim: message)
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.coralText)
                    .accessibilityAddTraits(.updatesFrequently)
                    .accessibilityIdentifier("consent.error")
            }
            Button { viewModel.save() } label: {
                if viewModel.isSaving { ProgressView() } else { Text("consent.save") }
            }
            .buttonStyle(.belloPrimary)
            .disabled(!viewModel.canSave)
            .accessibilityIdentifier("consent.saveButton")
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
    }

    // MARK: - Private

    private func text(_ key: LocalizedStringResource) -> String {
        String(localized: key.localized(in: locale))
    }

    private func load(_ item: PhotosPickerItem) async {
        defer { pickedPhoto = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        await viewModel.attachPhoto(data)
    }
}
