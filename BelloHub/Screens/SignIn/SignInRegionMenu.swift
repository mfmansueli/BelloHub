//
//  SignInRegionMenu.swift
//  BelloHub
//

import SwiftUI

/// The country calling code next to the phone field: shows "+55" and opens a menu of the countries the product
/// knows, each with its flag, name and code.
struct SignInRegionMenu: View {
    @Binding var region: RegionPreset
    let regions: [RegionPreset]
    @Environment(\.locale) private var locale

    var body: some View {
        Menu {
            Picker(selection: $region) {
                ForEach(regions) { preset in
                    Text(verbatim: "\(Self.flag(preset.code))  \(name(of: preset.code))  +\(preset.callingCode)")
                        .tag(preset)
                }
            } label: { Text("onb.signIn.countryCode") }
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(verbatim: "+\(region.callingCode)").font(Typography.bodyStrong)
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 56)
            .background(Palette.surface, in: shape)
            .overlay { shape.strokeBorder(Palette.fieldBorder, lineWidth: 1.5) }
        }
        .accessibilityLabel(Text("onb.signIn.countryCode"))
        .accessibilityValue(Text(verbatim: "\(name(of: region.code)) +\(region.callingCode)"))
        .accessibilityIdentifier("signIn.countryMenu")
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
    }

    private func name(of code: String) -> String {
        locale.localizedString(forRegionCode: code) ?? code
    }

    /// The flag emoji of an ISO region code, built from its two regional-indicator letters.
    static func flag(_ code: String) -> String {
        let base: UInt32 = 127_397
        return code.uppercased().unicodeScalars.compactMap { Unicode.Scalar(base + $0.value) }
            .map(String.init).joined()
    }
}
