//
//  AddNameSheet.swift
//  BelloHub
//

import SwiftUI

/// A small sheet for one name she uses: what it is called and whether it is a service or a protocol.
struct AddNameSheet: View {
    let onAdd: (String, VocabularyKind) -> Void

    @State private var name = ""
    @State private var kind = VocabularyKind.service
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                BelloTextField(
                    title: "onb.terminology.addName", text: $name, prompt: "onb.terminology.namePrompt",
                    identifier: "addName.nameField"
                )
                .focused($isFocused)
                Picker(selection: $kind) {
                    Text("onb.terminology.kind.service").tag(VocabularyKind.service)
                    Text("onb.terminology.kind.protocol").tag(VocabularyKind.protocolName)
                } label: { Text("onb.terminology.kind") }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("addName.kindPicker")
                Spacer(minLength: 0)
                Button(action: add) { Text("onb.terminology.addConfirm") }
                    .buttonStyle(.belloPrimary)
                    .disabled(OnboardingRules.cleaned(name).isEmpty)
                    .accessibilityIdentifier("addName.addButton")
            }
            .padding(Spacing.gutter)
            .background(Palette.bg)
            .navigationTitle(Text("onb.terminology.addTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.cancel") }
                }
            }
            .onAppear { isFocused = true }
        }
        .presentationDetents([.medium])
        .presentationBackground(Palette.bg)
    }

    private func add() {
        onAdd(name, kind)
        dismiss()
    }
}

#Preview {
    AddNameSheet { _, _ in }
}
