//
//  ClientNoteField.swift
//  BelloHub
//

import SwiftUI

/// "Important to know": a few lines of free text, in the look of the other fields. Private, so the keyboard is told not
/// to learn it (no autocorrection, no suggestions), the same rule the sensitive text fields follow.
struct ClientNoteField: View {
    @Binding var text: String
    let identifier: String
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("clientForm.note")
                .font(Typography.metaStrong)
                .foregroundStyle(Palette.ink2)
            TextField(text: $text, prompt: .prompt("clientForm.note.prompt"), axis: .vertical) {
                Text("clientForm.note")
            }
            .font(Typography.body)
            .foregroundStyle(Palette.ink)
            .lineLimit(3...8)
            .focused($isFocused)
            .autocorrectionDisabled()
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .background(Palette.sunken, in: shape)
            .overlay { shape.strokeBorder(Palette.fieldBorder, lineWidth: 1.5) }
            .overlay {
                if isFocused {
                    shape.strokeBorder(Palette.roseText, lineWidth: 3).padding(-3).allowsHitTesting(false)
                }
            }
            .accessibilityIdentifier(identifier)
            FooterNote(text: "clientForm.note.footer")
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
    }
}
