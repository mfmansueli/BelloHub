//
//  ImportColumnPickerRow.swift
//  BelloHub
//

import SwiftUI

/// "Name" on one side, a native menu `Picker` of the file's columns on the other. At accessibility text sizes the menu
/// moves under its label so neither is squeezed.
struct ImportColumnPickerRow: View {
    let role: ImportColumnRole
    let options: [ImportColumnOption]
    @Binding var selection: Int?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xs))
            : AnyLayout(HStackLayout(spacing: Spacing.row))
        layout {
            roleLabel.font(Typography.body).foregroundStyle(Palette.ink)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: Spacing.sm) }
            picker
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
    }

    private var roleLabel: Text {
        switch role {
        case .name: Text("import.field.name")
        case .lastName: Text("import.field.lastName")
        case .phone: Text("import.field.phone")
        case .email: Text("import.field.email")
        }
    }

    private var picker: some View {
        Picker(selection: $selection) {
            Text("import.field.none").tag(Int?.none)
            ForEach(options) { option in
                Text(verbatim: label(for: option)).tag(Int?.some(option.index))
            }
        } label: {
            roleLabel
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .tint(Palette.accent)
        .frame(minHeight: Spacing.touchTarget)
        .accessibilityLabel(roleLabel)
        .accessibilityIdentifier("importClients.mapping.\(role.rawValue)Picker")
    }

    /// The title the file gives the column, or "Column 3" with the first value so an untitled column can be told apart.
    private func label(for option: ImportColumnOption) -> String {
        if let title = option.title { return BidiIsolate.wrap(title) }
        let column = String(localized: LocalizedStringResource(
            "import.column", defaultValue: "Column \(option.index + 1)"
        ).localized(in: locale))
        return option.sample.isEmpty ? column : "\(column): \(BidiIsolate.wrap(option.sample))"
    }
}
