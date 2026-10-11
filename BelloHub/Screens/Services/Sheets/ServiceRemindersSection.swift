//
//  ServiceRemindersSection.swift
//  BelloHub
//

import SwiftUI

/// The switches of the service form: before and after photos, aftercare (with the words she shares) and the patch test
/// (with how long before the first visit it is asked for). The extra controls appear only while their switch is on.
struct ServiceRemindersSection: View {
    @Binding var draft: ServiceDraft
    let formatters: Formatters

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ListCard(dividerInset: Spacing.md) {
                ToggleRow(
                    title: text("onb.service.photos"), subtitle: text("onb.service.photosHint"),
                    isOn: $draft.remindsPhotos, identifier: "serviceEditor.photosToggle"
                )
                ToggleRow(
                    title: text("onb.service.aftercare"), subtitle: text("onb.service.aftercareHint"),
                    isOn: $draft.sharesAftercare, identifier: "serviceEditor.aftercareToggle"
                )
                ToggleRow(
                    title: text("services.patch.title"), subtitle: patchHint,
                    isOn: $draft.requiresPatchTest, identifier: "serviceEditor.patchTestToggle"
                )
            }
            if draft.requiresPatchTest { patchHours }
            if draft.sharesAftercare {
                BelloNoteField(
                    title: Text("services.aftercare.template"), text: $draft.aftercareText,
                    prompt: "services.aftercare.prompt", identifier: "serviceEditor.aftercareField"
                )
            }
        }
    }

    // MARK: - Patch test

    private var hourOptions: [Int] { ServiceRules.patchTestHourOptions(including: draft.patchTestHoursBefore) }

    private var patchHours: some View {
        ListCard(dividerInset: Spacing.md) {
            LabeledFieldRow(label: "services.patch.hours") {
                Picker(selection: $draft.patchTestHoursBefore) {
                    ForEach(hourOptions, id: \.self) { hours in
                        Text(verbatim: formatters.duration(minutes: hours * 60)).tag(hours)
                    }
                } label: { Text("services.patch.hours") }
                .pickerStyle(.menu)
                .tint(Palette.ink)
                .accessibilityIdentifier("serviceEditor.patchHoursMenu")
            }
        }
    }

    /// "Ask new clients for a patch test at least 48 hr ahead": the hours are the ones she chose.
    private var patchHint: String {
        let hours = formatters.duration(minutes: draft.patchTestHoursBefore * 60)
        return String(localized: LocalizedStringResource(
            "services.patch.hint", defaultValue: "Ask new clients for a patch test at least \(hours) ahead"
        ).localized(in: locale))
    }

    private func text(_ key: LocalizedStringResource) -> String {
        String(localized: key.localized(in: locale))
    }
}
