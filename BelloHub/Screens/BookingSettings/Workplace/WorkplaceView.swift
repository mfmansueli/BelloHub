//
//  WorkplaceView.swift
//  BelloHub
//

import SwiftUI

/// "Where you work", pushed from Booking settings (owner, 2026-10-11: the confirmation should say where the place is).
/// The address in four plain fields and an optional "how to find us" note, who may see it (only clients with a
/// confirmed booking, the default, or also the booking page), and a live preview of what a client gets, with the two
/// map links built from the text. Saved with Save, removed with Remove; both publish with her page.
struct WorkplaceView: View {
    @State private var viewModel: WorkplaceViewModel
    @State private var confirmsRemove = false

    @Environment(\.locale) private var locale

    init(editor: BookingSetupEditor, businessRegion: String) {
        _viewModel = State(initialValue: WorkplaceViewModel(editor: editor, businessRegion: businessRegion))
    }

    private var countries: [String] {
        WorkplaceCountries.codes(businessRegion: viewModel.businessRegion, locale: locale)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                Text("workplace.subtitle").font(Typography.body).foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                if let message = viewModel.errorMessage {
                    ErrorNotice(message: message, actionTitle: "bookingSetup.dismiss", action: viewModel.dismissError)
                        .accessibilityIdentifier("workplace.saveError")
                }
                addressSection
                visibilitySection
                previewSection
                actions
                FooterNote(text: "workplace.footer", icon: .lock)
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.bg)
        .navigationTitle(Text("workplace.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.appear() }
        .confirmationDialog(
            Text("workplace.remove.confirmTitle"), isPresented: $confirmsRemove, titleVisibility: .visible
        ) {
            Button("workplace.remove.confirm", role: .destructive) { viewModel.remove() }
                .accessibilityIdentifier("workplace.removeConfirmButton")
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("workplace.remove.confirmMessage")
        }
    }

    // MARK: - Sections

    private var addressSection: some View {
        SettingsSection(title: "workplace.section.address") {
            BelloTextField(
                title: "workplace.street", text: $viewModel.street, prompt: "workplace.street.prompt",
                identifier: "workplace.streetField"
            )
            .textContentType(.fullStreetAddress)
            BelloTextField(
                title: "workplace.postalCode", text: $viewModel.postalCode, identifier: "workplace.postalCodeField"
            )
            .textContentType(.postalCode)
            BelloTextField(title: "workplace.city", text: $viewModel.city, identifier: "workplace.cityField")
                .textContentType(.addressCity)
            countryRow
            BelloNoteField(
                title: Text("workplace.directions"), text: $viewModel.directions, prompt: "workplace.directions.prompt",
                identifier: "workplace.directionsField"
            )
            if viewModel.isTooLong {
                Text("workplace.tooLong").font(Typography.footnote).foregroundStyle(Palette.coralText)
                    .accessibilityIdentifier("workplace.tooLong")
            }
        }
    }

    private var countryRow: some View {
        HStack(spacing: Spacing.row) {
            Text("workplace.country").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Picker(selection: $viewModel.countryCode) {
                ForEach(countries, id: \.self) { code in
                    Text(verbatim: WorkplaceCountries.name(code, locale: locale)).tag(code)
                }
            } label: {
                Text("workplace.country")
            }
            .pickerStyle(.menu)
            .tint(Palette.roseText)
            .accessibilityIdentifier("workplace.countryPicker")
        }
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: 56)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
    }

    private var visibilitySection: some View {
        SettingsSection(title: "workplace.section.visibility") {
            ForEach(LocationVisibility.allCases) { option in
                ChoiceCard(
                    title: String(localized: option.title.localized(in: locale)),
                    subtitle: String(localized: option.detail.localized(in: locale)),
                    isSelected: viewModel.visibility == option,
                    identifier: "workplace.visibility.\(option.rawValue)"
                ) { viewModel.visibility = option }
            }
        }
    }

    private var previewSection: some View {
        SettingsSection(title: "workplace.section.preview", subtitle: "workplace.preview.subtitle") {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if let lines = viewModel.previewLines {
                    Label {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            ForEach(lines, id: \.self) { line in
                                Text(verbatim: line).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                            }
                            if let directions = viewModel.previewDirections {
                                Text(verbatim: directions).font(Typography.meta).foregroundStyle(Palette.ink2)
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(icon: .mapPin).foregroundStyle(Palette.roseText)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("workplace.preview.address")
                    mapLinks
                } else {
                    Text("workplace.preview.empty").font(Typography.meta).foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("workplace.preview.empty")
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
    }

    /// Both links open the map app or page from the text alone, the same links the client gets.
    @ViewBuilder
    private var mapLinks: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.lg) { mapLinkButtons }
            VStack(alignment: .leading, spacing: Spacing.xs) { mapLinkButtons }
        }
    }

    @ViewBuilder
    private var mapLinkButtons: some View {
        if let apple = viewModel.appleMapsURL {
            Link(destination: apple) { Text("workplace.map.apple") }
                .font(Typography.metaStrong).foregroundStyle(Palette.roseText)
                .frame(minHeight: Spacing.touchTarget)
                .accessibilityHint(Text("workplace.map.hint"))
                .accessibilityIdentifier("workplace.map.apple")
        }
        if let google = viewModel.googleMapsURL {
            Link(destination: google) { Text("workplace.map.google") }
                .font(Typography.metaStrong).foregroundStyle(Palette.roseText)
                .frame(minHeight: Spacing.touchTarget)
                .accessibilityHint(Text("workplace.map.hint"))
                .accessibilityIdentifier("workplace.map.google")
        }
    }

    private var actions: some View {
        VStack(spacing: Spacing.row) {
            Button { viewModel.save() } label: {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Text(viewModel.isSaved ? "workplace.saved" : "workplace.save")
                }
            }
            .buttonStyle(.belloPrimary)
            .disabled(!viewModel.canSave)
            .accessibilityIdentifier("workplace.saveButton")
            if viewModel.stored != nil {
                Button(role: .destructive) { confirmsRemove = true } label: { Text("workplace.remove") }
                    .buttonStyle(.belloSecondary)
                    .accessibilityIdentifier("workplace.removeButton")
            }
        }
    }
}

#if DEBUG
#Preview {
    let vault = VaultService(repository: InMemoryClientRecordRepository())
    NavigationStack {
        WorkplaceView(editor: BookingSetupEditor(service: BookingSetupService(vault: vault)), businessRegion: "BR")
    }
}
#endif
