//
//  ServiceTimingSection.swift
//  BelloHub
//

import SwiftUI

/// "Time around the visit" in the service form (D56): prep before and clean-up after, which her agenda keeps free but
/// clients never see in the length or the price, and processing time inside the visit, while she is free for another
/// client (colour developing, a mask setting). Native menus and a switch; the processing menus appear while it is on.
/// Most services need none of it, so the section is a native disclosure (routine item 10), closed until she opens it
/// or the service already has extra time, with an example from the routine under the card.
struct ServiceTimingSection: View {
    @Binding var draft: ServiceDraft
    let formatters: Formatters

    @State private var isExpanded: Bool
    @Environment(\.locale) private var locale

    init(draft: Binding<ServiceDraft>, formatters: Formatters) {
        _draft = draft
        self.formatters = formatters
        let current = draft.wrappedValue
        let hasExtraTime = current.prepMinutes > 0 || current.cleanupMinutes > 0 || current.hasProcessing
        _isExpanded = State(initialValue: hasExtraTime)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            content.padding(.top, Spacing.sm)
        } label: {
            Text("services.timing.disclosure").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                .frame(minHeight: Spacing.touchTarget, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
        }
        .tint(Palette.roseText)
        .accessibilityIdentifier("serviceEditor.timingDisclosure")
        .onChange(of: draft.minutes) { draft = ServiceRules.fittingProcessing(draft) }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ListCard(dividerInset: Spacing.md) {
                menuRow("services.timing.prep", selection: $draft.prepMinutes,
                        options: ServiceRules.extraMinuteOptions(including: draft.prepMinutes),
                        identifier: "serviceEditor.prepMenu")
                menuRow("services.timing.cleanup", selection: $draft.cleanupMinutes,
                        options: ServiceRules.extraMinuteOptions(including: draft.cleanupMinutes),
                        identifier: "serviceEditor.cleanupMenu")
                ToggleRow(
                    title: text("services.timing.processing"), subtitle: text("services.timing.processingHint"),
                    isOn: Binding(get: { draft.hasProcessing }, set: { isOn in
                        draft.hasProcessing = isOn
                        draft = ServiceRules.fittingProcessing(draft)
                    }),
                    identifier: "serviceEditor.processingToggle"
                )
                if draft.hasProcessing { processingRows }
            }
            Text("services.timing.hint").font(Typography.footnote).foregroundStyle(Palette.ink2)
            Text("services.timing.example").font(Typography.footnote).foregroundStyle(Palette.ink2)
        }
    }

    // MARK: - Parts

    @ViewBuilder
    private var processingRows: some View {
        menuRow("services.timing.processingLength", selection: $draft.processingMinutes,
                options: ServiceRules.processingOptions(visitMinutes: draft.minutes,
                                                        including: draft.processingMinutes),
                identifier: "serviceEditor.processingMenu")
        menuRow("services.timing.processingStart", selection: $draft.processingStartMinutes,
                options: ServiceRules.processingStartOptions(
                    visitMinutes: draft.minutes, processing: draft.processingMinutes,
                    including: draft.processingStartMinutes
                ),
                identifier: "serviceEditor.processingStartMenu", zero: "services.timing.processingStartNow")
    }

    private func menuRow(
        _ title: LocalizedStringKey, selection: Binding<Int>, options: [Int], identifier: String,
        zero: LocalizedStringResource = "services.timing.none"
    ) -> some View {
        LabeledFieldRow(label: title) {
            Picker(selection: selection) {
                ForEach(options, id: \.self) { minutes in
                    Text(verbatim: minutes == 0 ? text(zero) : formatters.minutes(minutes)).tag(minutes)
                }
            } label: { Text(title) }
            .pickerStyle(.menu)
            .tint(Palette.ink)
            .accessibilityIdentifier(identifier)
        }
    }

    private func text(_ key: LocalizedStringResource) -> String {
        String(localized: key.localized(in: locale))
    }
}
