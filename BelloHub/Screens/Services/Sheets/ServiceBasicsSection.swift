//
//  ServiceBasicsSection.swift
//  BelloHub
//

import SwiftUI

/// The first card of the service form: name, price and length. The price is read the way her language writes numbers
/// (`PriceInput`) and turns coral while it is not an amount; the length is a menu because there are many choices.
struct ServiceBasicsSection: View {
    @Binding var draft: ServiceDraft
    let formatters: Formatters
    /// What is wrong with the name, shown under the card; nil while it is fine or still empty.
    let nameError: LocalizedStringKey?

    @Environment(\.locale) private var locale

    private var isPriceInvalid: Bool { PriceInput(draft.priceText, locale: locale).isInvalid }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ListCard(dividerInset: Spacing.md) {
                LabeledFieldRow(label: "onb.service.name") {
                    TextField(text: $draft.name, prompt: .prompt("services.editor.namePrompt")) {
                        Text("onb.service.name")
                    }
                    .accessibilityIdentifier("serviceEditor.nameField")
                }
                LabeledFieldRow(label: "onb.service.price") {
                    TextField(text: $draft.priceText, prompt: .prompt("onb.service.pricePrompt")) {
                        Text("onb.service.price")
                    }
                    .keyboardType(.decimalPad)
                    .foregroundStyle(isPriceInvalid ? Palette.coralText : Palette.ink)
                    .accessibilityIdentifier("serviceEditor.priceField")
                }
                LabeledFieldRow(label: "onb.service.duration") {
                    Picker(selection: $draft.minutes) {
                        ForEach(ServiceRules.durationOptions(including: draft.minutes), id: \.self) { minutes in
                            Text(verbatim: formatters.minutes(minutes)).tag(minutes)
                        }
                    } label: { Text("onb.service.duration") }
                    .pickerStyle(.menu)
                    .tint(Palette.ink)
                    .accessibilityIdentifier("serviceEditor.durationMenu")
                }
            }
            if let nameError {
                Text(nameError).font(Typography.footnote).foregroundStyle(Palette.coralText)
                    .accessibilityAddTraits(.updatesFrequently)
                    .accessibilityIdentifier("serviceEditor.nameError")
            }
            if isPriceInvalid {
                Text("services.editor.priceInvalid").font(Typography.footnote).foregroundStyle(Palette.coralText)
                    .accessibilityAddTraits(.updatesFrequently)
                    .accessibilityIdentifier("serviceEditor.priceError")
            }
        }
    }
}
