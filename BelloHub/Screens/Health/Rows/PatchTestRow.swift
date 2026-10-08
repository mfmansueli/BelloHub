//
//  PatchTestRow.swift
//  BelloHub
//

import SwiftUI

/// One patch test: the product, when and where it was tried and for how long the skin was watched, and the result as
/// a chip with a word (never color alone). At accessibility sizes the chip drops under the text.
struct PatchTestRow: View {
    let patchTest: PatchTest
    let formatters: Formatters
    let identifier: String
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.locale) private var locale

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    summary
                    chip
                }
            } else {
                HStack(alignment: .top, spacing: Spacing.row) {
                    summary
                    Spacer(minLength: Spacing.sm)
                    chip
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(verbatim: patchTest.product).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
            Text(verbatim: detail).font(Typography.meta).foregroundStyle(Palette.ink2)
        }
    }

    @ViewBuilder
    private var chip: some View {
        switch patchTest.result {
        case .noReaction: StatusChip(label: "health.patch.result.none", style: StatusPalette.confirmed)
        case .mildReaction: StatusChip(label: "health.patch.result.mild", style: StatusPalette.pending)
        case .reaction: StatusChip(label: "health.patch.result.reaction", style: StatusPalette.attention)
        }
    }

    /// "Jul 20 · Inner arm, 24 hr": the date, the area when there is one, and how long it was watched.
    private var detail: String {
        let date = formatters.shortDate(patchTest.testedAt)
        let hours = formatters.duration(minutes: patchTest.observedHours * 60)
        let resource: LocalizedStringResource
        if let area = patchTest.area, !area.isEmpty {
            resource = LocalizedStringResource(
                "health.patch.detail", defaultValue: "\(date) · \(BidiIsolate.wrap(area)), \(hours)"
            )
        } else {
            resource = LocalizedStringResource("health.patch.detailNoArea", defaultValue: "\(date) · \(hours)")
        }
        return String(localized: resource.localized(in: locale))
    }
}
