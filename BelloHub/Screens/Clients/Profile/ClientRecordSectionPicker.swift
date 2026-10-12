//
//  ClientRecordSectionPicker.swift
//  BelloHub
//

import SwiftUI

/// Switches the record between History, Photos, Information and Documents. A native segmented control: four short
/// words fit an iPhone, and VoiceOver reads it as one control with its selected value. At the accessibility text
/// sizes four segments would truncate, so the same choice becomes a native menu picker, which grows with the text.
struct ClientRecordSectionPicker: View {
    @Binding var selection: ClientRecordSection
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            picker.pickerStyle(.menu)
                .tint(Palette.roseText)
                .frame(maxWidth: .infinity, minHeight: Spacing.touchTarget, alignment: .leading)
        } else {
            picker.pickerStyle(.segmented)
        }
    }

    private var picker: some View {
        Picker(selection: $selection) {
            ForEach(ClientRecordSection.allCases) { section in
                Text(section.title.localized(in: locale)).tag(section)
            }
        } label: {
            Text("clientRecord.section.label")
        }
        .accessibilityIdentifier("clientRecord.sections")
    }
}
