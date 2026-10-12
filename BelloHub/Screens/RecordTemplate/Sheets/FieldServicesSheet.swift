//
//  FieldServicesSheet.swift
//  BelloHub
//

import SwiftUI

/// "Ask this field for…": every service, or only the ones she picks, so a brow field is not asked at a facial. The
/// field and what records already hold for it stay as they are; only the form of the next visits changes.
struct FieldServicesSheet: View {
    let fieldName: String
    let services: [Service]
    let onSave: ([UUID]) -> Void
    @State private var selected: Set<UUID>
    @Environment(\.dismiss) private var dismiss

    init(fieldName: String, services: [Service], selected: [UUID], onSave: @escaping ([UUID]) -> Void) {
        self.fieldName = fieldName
        self.services = services
        self.onSave = onSave
        _selected = State(initialValue: Set(selected))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row(title: Text("recordTemplate.services.all"), isChecked: selected.isEmpty,
                        identifier: "recordTemplate.services.all") { selected = [] }
                    ForEach(services) { service in
                        row(title: Text(verbatim: service.name), isChecked: selected.contains(service.id),
                            identifier: "recordTemplate.services.\(service.id.uuidString)") { toggle(service.id) }
                    }
                } header: {
                    Text(verbatim: fieldName).font(Typography.section).foregroundStyle(Palette.ink).textCase(nil)
                } footer: {
                    Text("recordTemplate.services.footer").font(Typography.footnote).foregroundStyle(Palette.ink2)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Palette.bg)
            .navigationTitle(Text("recordTemplate.services.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.cancel") }
                        .accessibilityIdentifier("recordTemplate.services.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { save() } label: { Text("recordTemplate.services.save") }
                        .accessibilityIdentifier("recordTemplate.services.save")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Palette.bg)
    }

    private func row(title: Text, isChecked: Bool, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.row) {
                title.font(Typography.body).foregroundStyle(Palette.ink)
                Spacer(minLength: Spacing.sm)
                if isChecked {
                    Image(icon: .check).foregroundStyle(Palette.roseText).accessibilityHidden(true)
                }
            }
            .frame(minHeight: Spacing.touchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Palette.surface)
        .accessibilityAddTraits(isChecked ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    private func toggle(_ id: UUID) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    /// Kept in the order of her services, so the summary reads like her list.
    private func save() {
        onSave(services.map(\.id).filter(selected.contains))
        dismiss()
    }
}
