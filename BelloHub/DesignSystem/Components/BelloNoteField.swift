//
//  BelloNoteField.swift
//  BelloHub
//

import SwiftUI

/// A field for a few lines of free text (a note, an answer in the client's own words): the look of `BelloTextField`
/// with a minimum of three lines that grows as she types. `BelloTextField` stays one line, which suits names and phone
/// numbers; this one exists because a note that scrolls sideways cannot be read back.
/// `title` is also the field's accessibility label; `showsTitle: false` hides it when the screen already shows the
/// question above. `isSensitive` turns off autocorrection and autocapitalization, so the keyboard never learns
/// clinical text.
struct BelloNoteField: View {
    let title: Text
    @Binding var text: String
    var prompt: LocalizedStringKey?
    var showsTitle = true
    var isSensitive = false
    /// Goes on the text field itself: an identifier on the surrounding stack would overwrite its children's.
    var identifier: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if showsTitle {
                title
                    .font(Typography.metaStrong)
                    .foregroundStyle(Palette.ink2)
                    .accessibilityHidden(true)
            }
            TextField(text: $text, prompt: prompt.map { Text.prompt($0) }, axis: .vertical) { title }
                .lineLimit(3...8)
                .font(Typography.body)
                .foregroundStyle(Palette.ink)
                .focused($isFocused)
                .autocorrectionDisabled(isSensitive)
                .textInputAutocapitalization(isSensitive ? .never : nil)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.row)
                .frame(minHeight: 52, alignment: .topLeading)
                .background(Palette.sunken, in: shape)
                .overlay { shape.strokeBorder(Palette.fieldBorder, lineWidth: 1.5) }
                .overlay {
                    if isFocused {
                        shape.strokeBorder(Palette.roseText, lineWidth: 3).padding(-3).allowsHitTesting(false)
                    }
                }
                .accessibilityIdentifier(identifier ?? "")
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
    }
}
