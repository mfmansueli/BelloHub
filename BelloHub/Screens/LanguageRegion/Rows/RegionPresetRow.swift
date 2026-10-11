//
//  RegionPresetRow.swift
//  BelloHub
//

import SwiftUI

/// One region preset of Language and region (7.2): the code as a tile, the region's name in the app language, its
/// language and currency, and a tick when it is the chosen one.
struct RegionPresetRow: View {
    let preset: RegionPreset
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.row) {
                Text(verbatim: preset.code)
                    .font(Typography.metaStrong)
                    .foregroundStyle(isSelected ? Palette.selectionInk : Palette.ink)
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                    .background(
                        isSelected ? Palette.selectionFill : Palette.sunken,
                        in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: locale.localizedString(forRegionCode: preset.code) ?? preset.code)
                        .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    Text(verbatim: subtitle).font(Typography.meta).foregroundStyle(Palette.ink2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isSelected {
                    Image(icon: .check).foregroundStyle(Palette.sageText).accessibilityHidden(true)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("languageRegion.region.\(preset.code)")
    }

    private var subtitle: String {
        let language = AppLocalization(rawValue: preset.defaultLocalization)?.nativeName ?? preset.defaultLocalization
        return "\(language) · \(preset.defaultCurrency)"
    }
}
