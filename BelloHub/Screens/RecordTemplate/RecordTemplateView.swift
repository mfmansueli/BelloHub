//
//  RecordTemplateView.swift
//  BelloHub
//

import SwiftUI

/// 6.13 RecordTemplate. What she remembers about each client: the fields of the treatment record per profession
/// (switch the catalog's on and off, add her own), and what a new client is asked before the first visit. Every change
/// is saved at once, so the prototype's "Save changes" button is not needed. A native `List`, for the drag handles,
/// swipe actions and edit mode that reordering and deleting her own fields need.
struct RecordTemplateView: View {
    @State private var viewModel: RecordTemplateViewModel
    @State private var editor: FieldEditorMode?
    @State private var pendingDeletion: RecordFieldSetting?
    @State private var choosingServices: RecordFieldSetting?
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize

    init(profile: ProfileService, services: (any AgendaRepository)? = nil) {
        let catalog = Self.catalog(for: InterfaceLocale.localization)
        _viewModel = State(initialValue: RecordTemplateViewModel(
            profile: profile, catalog: catalog, services: services
        ))
    }

    /// The field names of the interface language. A catalog that cannot be read leaves the standard fields showing
    /// their keys instead of blocking the screen.
    private static func catalog(for localization: AppLocalization) -> ProfessionCatalog {
        (try? ProfessionCatalog.loadBundled(localization: localization))
            ?? ProfessionCatalog(localization: localization.rawValue, status: "needs_review", entries: [])
    }

    var body: some View {
        content
            .background(Palette.bg)
            .navigationTitle(Text("recordTemplate.title"))
            .navigationBarTitleDisplayMode(.large)
            .task { await viewModel.loadAsync() }
            .onChange(of: locale) { _, new in viewModel.useCatalog(Self.catalog(for: AppLocalization(resolving: new))) }
            .sheet(item: $editor) { mode in
                FieldEditorSheet(mode: mode, viewModel: viewModel)
            }
            .sheet(item: $choosingServices) { field in
                FieldServicesSheet(
                    fieldName: viewModel.name(of: field), services: viewModel.services, selected: field.serviceIDs
                ) { ids in viewModel.setServices(field.key, ids) }
            }
            .fieldDeletionDialog(
                $pendingDeletion, name: viewModel.name(of:),
                onConfirm: { field in Task { await viewModel.deleteField(field.key) } }
            )
    }

    @ViewBuilder
    private var content: some View {
        if let profession = viewModel.selectedProfession {
            list(for: profession)
        } else {
            EmptyState(icon: .sliders, title: "recordTemplate.empty.title", message: "recordTemplate.empty.message")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("recordTemplate.empty")
        }
    }

    // MARK: - List

    private func list(for profession: ProfessionID) -> some View {
        List {
            introSection
            if viewModel.professions.count > 1 { chipsSection }
            if let message = viewModel.errorMessage {
                Section {
                    ErrorNotice(message: message, actionTitle: "recordTemplate.dismiss", action: viewModel.dismissError)
                        .accessibilityIdentifier("recordTemplate.error")
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            }
            standardSection(for: profession)
            customSection(for: profession)
            if !viewModel.enabledFields(for: profession).isEmpty { requiredSection(for: profession) }
            intakeSection(for: profession)
            formsSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.loadAsync() }
        .toolbar {
            if viewModel.customFields(for: profession).count > 1 {
                ToolbarItem(placement: .primaryAction) {
                    EditButton().accessibilityIdentifier("recordTemplate.editButton")
                }
            }
        }
    }

    private var introSection: some View {
        let term = viewModel.clientTerm.singularText(in: locale)
        return Section {
            Text(LocalizedStringResource(
                "recordTemplate.subtitle",
                defaultValue: "What you want to remember about each \(term). Start with these and adjust any time."
            ).localized(in: locale))
                .font(Typography.body).foregroundStyle(Palette.ink2)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                // A little inset: at none the first letter of a wrapped line is clipped by the list's edge.
                .listRowInsets(EdgeInsets(top: 0, leading: Spacing.sm, bottom: Spacing.sm, trailing: Spacing.sm))
        }
    }

    /// One chip per profession she has, as in the setup. Only shown when she has more than one.
    private var chipsSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(viewModel.professions, id: \.self) { id in
                        Button { viewModel.select(id) } label: { Text(verbatim: viewModel.professionName(id)) }
                            .buttonStyle(.belloChip(selected: viewModel.selectedProfession == id))
                            .accessibilityAddTraits(viewModel.selectedProfession == id ? .isSelected : [])
                            .accessibilityIdentifier("recordTemplate.profession.\(id.rawValue)")
                    }
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
        }
    }

    // MARK: - Fields

    private func standardSection(for profession: ProfessionID) -> some View {
        let counts = viewModel.counts(for: profession)
        return Section {
            ForEach(viewModel.standardFields(for: profession)) { field in
                ToggleRow(
                    title: viewModel.name(of: field), subtitle: servicesLine(field),
                    isOn: Binding(get: { field.isOn }, set: { viewModel.setField(field.key, on: $0) }),
                    identifier: "recordTemplate.field.\(field.key)"
                )
                .listRowBackground(Palette.surface)
                .listRowInsets(EdgeInsets())
                .swipeActions(edge: .trailing) { servicesAction(field) }
            }
        } header: {
            // The count goes under the title at the accessibility text sizes, where beside it the title would break
            // in the middle of a word.
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xs))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Spacing.row))
            layout {
                sectionTitle("onb.record.fields")
                if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
                Text(LocalizedStringResource(
                    "onb.record.count", defaultValue: "\(counts.on) of \(counts.total) on"
                ).localized(in: locale))
                    .font(Typography.footnote).foregroundStyle(Palette.ink2).textCase(nil)
            }
        } footer: {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("onb.record.fieldsHint")
                Text("recordTemplate.offNote")
            }
            .font(Typography.footnote).foregroundStyle(Palette.ink2)
        }
    }

    private func customSection(for profession: ProfessionID) -> some View {
        let custom = viewModel.customFields(for: profession)
        return Section {
            ForEach(custom) { field in
                CustomFieldRow(
                    field: field,
                    isOn: Binding(get: { field.isOn }, set: { viewModel.setField(field.key, on: $0) }),
                    onEdit: { editor = .edit(field) }
                )
                .listRowBackground(Palette.surface)
                .listRowInsets(EdgeInsets())
                .swipeActions(edge: .leading) { servicesAction(field) }
            }
            .onMove { source, destination in viewModel.moveFields(from: source, to: destination) }
            .onDelete { offsets in pendingDeletion = offsets.first.map { custom[$0] } }
            if viewModel.canAddField(for: profession) {
                addFieldRow
            }
        } header: {
            sectionTitle("recordTemplate.section.yours")
        } footer: {
            if !viewModel.canAddField(for: profession) {
                Text("recordTemplate.limit").font(Typography.footnote).foregroundStyle(Palette.ink2)
            }
        }
    }

    private var addFieldRow: some View {
        Button { editor = .add } label: {
            HStack(spacing: Spacing.row) {
                Image(icon: .plus)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                Text("recordTemplate.addField").font(Typography.bodyStrong)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Palette.roseText)
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Palette.surface)
        .listRowInsets(EdgeInsets())
        .accessibilityIdentifier("recordTemplate.addFieldButton")
    }

    /// "Only for…" under a field's name when she narrowed it to some services.
    private func servicesLine(_ field: RecordFieldSetting) -> String? {
        viewModel.servicesSummary(of: field).map { names in
            LocalizedStringResource("recordTemplate.services.only", defaultValue: "Only for \(names)")
                .resolved(in: locale)
        }
    }

    /// The swipe action that narrows a field to some services. Hidden when she has no services to choose from.
    @ViewBuilder
    private func servicesAction(_ field: RecordFieldSetting) -> some View {
        if !viewModel.services.isEmpty {
            Button { choosingServices = field } label: {
                Label { Text("recordTemplate.services.action") } icon: { Image(icon: .scissors) }
            }
            .tint(Palette.sage)
            .accessibilityIdentifier("recordTemplate.services.action.\(field.key)")
        }
    }

    // MARK: - Needed to finalize

    /// Which fields a record needs before it can be finalized. Drafts never need them, so a busy day is never blocked:
    /// she writes what she can and finalizes when the rest is there.
    private func requiredSection(for profession: ProfessionID) -> some View {
        Section {
            ForEach(viewModel.enabledFields(for: profession)) { field in
                ToggleRow(
                    title: viewModel.name(of: field),
                    isOn: Binding(get: { field.isRequired }, set: { viewModel.setRequired(field.key, $0) }),
                    identifier: "recordTemplate.required.\(field.key)"
                )
                .listRowBackground(Palette.surface)
                .listRowInsets(EdgeInsets())
            }
        } header: {
            sectionTitle("recordTemplate.required.title")
        } footer: {
            Text("recordTemplate.required.footer").font(Typography.footnote).foregroundStyle(Palette.ink2)
        }
    }

    // MARK: - Before the first visit

    private func intakeSection(for profession: ProfessionID) -> some View {
        Section {
            ForEach(IntakeItem.allCases) { item in
                ToggleRow(
                    title: String(localized: item.title.localized(in: locale)),
                    subtitle: String(localized: item.hint.localized(in: locale)),
                    isOn: Binding(
                        get: { viewModel.isIntakeOn(item, for: profession) },
                        set: { viewModel.setIntake(item, on: $0) }
                    ),
                    identifier: "recordTemplate.intake.\(item.rawValue)"
                )
                .listRowBackground(Palette.surface)
                .listRowInsets(EdgeInsets())
            }
        } header: {
            sectionTitle("onb.record.intake")
        }
    }

    /// The row into the client forms (6.14): the questions and the consent text behind these switches.
    private var formsSection: some View {
        Section {
            NavigationLink(value: MoreRoute.formTemplates) {
                MoreRow(
                    icon: .document, tint: .peach, title: Text("recordTemplate.forms.title"),
                    subtitle: Text("recordTemplate.forms.subtitle")
                )
            }
            .listRowBackground(Palette.surface)
            .listRowInsets(EdgeInsets())
            .accessibilityIdentifier("recordTemplate.formsRow")
        }
    }

    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(Typography.section).foregroundStyle(Palette.ink)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    NavigationStack {
        RecordTemplateView(profile: ProfileService(vault: VaultService(repository: nil)))
    }
}
