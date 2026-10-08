//
//  CustomServiceSheet.swift
//  BelloHub
//

import SwiftUI

/// 1.5 Onb-4-CustomService. A service she names herself: name, category, an optional price, the duration, when a
/// client is due again, and two reminders. Opens as a native sheet.
struct CustomServiceSheet: View {
    let currencyCode: String
    let onAdd: (DraftService) -> Void

    @State private var service = DraftService()
    @State private var priceText = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    fields
                    followUp
                    reminders
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.vertical, Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.bg)
            .navigationTitle(Text("onb.service.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.cancel") }
                        .accessibilityIdentifier("customService.cancelButton")
                }
            }
            .safeAreaInset(edge: .bottom) { addButton }
        }
        .presentationDetents([.large])
        .presentationBackground(Palette.bg)
    }

    // MARK: - Sections

    private var fields: some View {
        ListCard(dividerInset: Spacing.md) {
            fieldRow("onb.service.name") {
                TextField(text: $service.name, prompt: .prompt("onb.service.name")) { Text("onb.service.name") }
                    .accessibilityIdentifier("customService.nameField")
            }
            fieldRow("onb.service.category") {
                TextField(text: $service.category, prompt: .prompt("onb.service.category")) {
                    Text("onb.service.category")
                }
                    .accessibilityIdentifier("customService.categoryField")
            }
            fieldRow("onb.service.price") {
                TextField(text: $priceText, prompt: .prompt("onb.service.pricePrompt")) { Text("onb.service.price") }
                    .keyboardType(.decimalPad)
                    .foregroundStyle(PriceInput(priceText, locale: locale).isInvalid ? Palette.coralText : Palette.ink)
                    .accessibilityIdentifier("customService.priceField")
            }
            fieldRow("onb.service.duration") {
                Picker(selection: $service.minutes) {
                    ForEach(OnboardingRules.durationOptions, id: \.self) { minutes in
                        Text(verbatim: formatters.minutes(minutes)).tag(minutes)
                    }
                } label: { Text("onb.service.duration") }
                    .pickerStyle(.menu)
                    .tint(Palette.ink)
                    .accessibilityIdentifier("customService.durationMenu")
            }
        }
    }

    private func fieldRow<Field: View>(_ label: LocalizedStringKey, @ViewBuilder field: () -> Field) -> some View {
        HStack(spacing: Spacing.md) {
            Text(label).font(Typography.body).foregroundStyle(Palette.ink2).frame(width: 96, alignment: .leading)
            field().font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: 56)
    }

    private var followUp: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("onb.service.followUp").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: Spacing.sm) {
                ForEach(OnboardingRules.followUpWeekOptions, id: \.self) { weeks in
                    Button { service.followUpWeeks = service.followUpWeeks == weeks ? nil : weeks } label: {
                        Text(verbatim: formatters.weeks(weeks))
                    }
                    .buttonStyle(.belloChip(selected: service.followUpWeeks == weeks))
                    .accessibilityAddTraits(service.followUpWeeks == weeks ? .isSelected : [])
                    .accessibilityIdentifier("customService.followUp.\(weeks)")
                }
            }
            Text("onb.service.followUpHint").font(Typography.footnote).foregroundStyle(Palette.ink2)
        }
    }

    private var reminders: some View {
        ListCard(dividerInset: Spacing.md) {
            ToggleRow(
                title: text("onb.service.photos"), subtitle: text("onb.service.photosHint"),
                isOn: $service.remindsPhotos, identifier: "customService.photosToggle"
            )
            ToggleRow(
                title: text("onb.service.aftercare"), subtitle: text("onb.service.aftercareHint"),
                isOn: $service.sharesAftercare, identifier: "customService.aftercareToggle"
            )
        }
    }

    private func text(_ key: LocalizedStringResource) -> String {
        String(localized: key.localized(in: locale))
    }

    private var addButton: some View {
        Button(action: add) { Text("onb.service.add") }
            .buttonStyle(.belloPrimary)
            .disabled(!canAdd)
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
            .background(Palette.bg)
            .accessibilityIdentifier("customService.addButton")
    }

    // MARK: - Actions

    private var parsedPrice: PriceInput { PriceInput(priceText, locale: locale) }

    private var canAdd: Bool {
        var candidate = service
        candidate.priceAmount = parsedPrice.amount
        return OnboardingRules.issues(in: candidate).isEmpty && !parsedPrice.isInvalid
    }

    private func add() {
        var finished = service
        finished.priceAmount = parsedPrice.amount
        guard canAdd else { return }
        onAdd(finished)
        dismiss()
    }

    private var formatters: Formatters {
        Formatters(locale: locale, timeZone: .current, currencyCode: currencyCode)
    }
}

#Preview {
    CustomServiceSheet(currencyCode: "BRL") { _ in }
}
