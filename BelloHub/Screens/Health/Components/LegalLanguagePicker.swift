//
//  LegalLanguagePicker.swift
//  BelloHub
//

import SwiftUI

/// The language a legal text is shown in. The system menu picker: it shows the current language and opens the list,
/// each language written in itself. The professional's business language is the default; a client who reads another
/// language can be shown the text in it.
struct LegalLanguagePicker: View {
    @Binding var selection: AppLocalization
    var identifier = "legal.languagePicker"

    var body: some View {
        Picker(
            selection: $selection,
            content: {
                ForEach(AppLocalization.allCases) { language in
                    Text(verbatim: language.nativeName).tag(language)
                }
            },
            label: { Text("legal.textLanguage") }
        )
        .pickerStyle(.menu)
        .tint(Palette.roseText)
        .font(Typography.body)
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: Spacing.touchTarget)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .strokeBorder(Palette.fieldBorder, lineWidth: 1)
        }
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    LegalLanguagePicker(selection: .constant(.ptBR))
        .padding()
        .background(Palette.bg)
}
