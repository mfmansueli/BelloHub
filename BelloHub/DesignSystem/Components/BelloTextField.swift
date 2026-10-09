//
//  BelloTextField.swift
//  BelloHub
//

import SwiftUI

/// A labeled field: 52 pt high, radius 14, `sunken` fill, 1.5 pt `fieldBorder`, and a 3 pt `roseText`
/// focus ring outside the border. An error shows its message under the field and is spoken as the hint.
/// `isSensitive` turns off autocorrection, autocapitalization and spellcheck, so the keyboard never
/// learns clinical text (docs/10-WEB-BOOKING.md section 5 has the same rule for the web).
struct BelloTextField: View {
    let title: Text
    @Binding var text: String
    var prompt: LocalizedStringKey?
    var errorMessage: LocalizedStringKey?
    var isSensitive = false
    /// Goes on the text field itself: an identifier on the surrounding stack would overwrite its children's.
    var identifier: String?
    @FocusState private var isFocused: Bool

    init(
        title: LocalizedStringKey, text: Binding<String>, prompt: LocalizedStringKey? = nil,
        errorMessage: LocalizedStringKey? = nil, isSensitive: Bool = false, identifier: String? = nil
    ) {
        self.init(
            titleText: Text(title), text: text, prompt: prompt, errorMessage: errorMessage, isSensitive: isSensitive,
            identifier: identifier
        )
    }

    /// For a title that is already text, such as the name of a field she created (`Text(verbatim:)`).
    init(
        titleText: Text, text: Binding<String>, prompt: LocalizedStringKey? = nil,
        errorMessage: LocalizedStringKey? = nil, isSensitive: Bool = false, identifier: String? = nil
    ) {
        self.title = titleText
        self._text = text
        self.prompt = prompt
        self.errorMessage = errorMessage
        self.isSensitive = isSensitive
        self.identifier = identifier
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            title
                .font(Typography.metaStrong)
                .foregroundStyle(Palette.ink2)
            TextField(text: $text, prompt: prompt.map { Text.prompt($0) }) { title }
                .font(Typography.body)
                .foregroundStyle(Palette.ink)
                .focused($isFocused)
                .autocorrectionDisabled(isSensitive)
                .textInputAutocapitalization(isSensitive ? .never : nil)
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: 52)
                .background(Palette.sunken, in: shape)
                .overlay { shape.strokeBorder(borderColor, lineWidth: 1.5) }
                .overlay {
                    if isFocused {
                        shape.strokeBorder(Palette.roseText, lineWidth: 3).padding(-3).allowsHitTesting(false)
                    }
                }
                .accessibilityHint(errorMessage.map { Text($0) } ?? Text(verbatim: ""))
                .accessibilityIdentifier(identifier ?? "")
            if let errorMessage {
                Text(errorMessage)
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.coralText)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
    }

    private var borderColor: Color {
        errorMessage == nil ? Palette.fieldBorder : Palette.coralText
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
    }
}
