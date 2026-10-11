//
//  ContraindicationPickerView.swift
//  BelloHub
//

import SwiftUI

/// The list of everything a service can warn about, grouped by the health question it comes from, with a check mark on
/// each one she chose. Pushed inside the service form, so the choice applies to the form's draft and is saved with it.
/// A native `List` with one button per row; the selected trait tells VoiceOver which are on.
struct ContraindicationPickerView: View {
    @Binding var selected: [String]
    let groups: [ContraindicationGroup]

    var body: some View {
        List {
            Section {
                Text("services.contra.pickerHint")
                    .font(Typography.meta).foregroundStyle(Palette.ink2)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: Spacing.sm, bottom: Spacing.sm, trailing: Spacing.sm))
            }
            ForEach(groups) { group in
                Section {
                    ForEach(group.options) { option in row(option) }
                } header: {
                    Text(verbatim: group.title)
                        .font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                        .textCase(nil)
                        .accessibilityAddTraits(.isHeader)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.bg)
        .navigationTitle(Text("services.contra.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ option: ContraindicationOption) -> some View {
        let isOn = selected.contains(option.token)
        return Button { selected = ContraindicationOptions.toggling(option.token, in: selected) } label: {
            HStack(spacing: Spacing.row) {
                Text(verbatim: option.title).font(Typography.body).foregroundStyle(Palette.ink)
                Spacer(minLength: 0)
                if isOn {
                    Image(icon: .check)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.roseText)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Palette.surface)
        .listRowInsets(EdgeInsets(top: 0, leading: Spacing.md, bottom: 0, trailing: Spacing.md))
        .accessibilityLabel(Text(verbatim: option.summary))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("contraindications.option.\(option.token)")
    }
}
