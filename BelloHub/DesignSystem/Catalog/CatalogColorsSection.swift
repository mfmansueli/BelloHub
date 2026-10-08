//
//  CatalogColorsSection.swift
//  BelloHub
//

#if DEBUG
import SwiftUI

/// Every semantic color as a swatch with its name, plus the status and avatar pairs.
struct CatalogColorsSection: View {
    private let tokens: [(name: String, color: Color)] = [
        ("bg", Palette.bg), ("surface", Palette.surface), ("sunken", Palette.sunken), ("hairline", Palette.hairline),
        ("ink", Palette.ink), ("ink2", Palette.ink2), ("ink3", Palette.ink3), ("fieldBorder", Palette.fieldBorder),
        ("rose", Palette.rose), ("roseText", Palette.roseText), ("roseWash", Palette.roseWash),
        ("roseDeepWash", Palette.roseDeepWash), ("roseDeepText", Palette.roseDeepText),
        ("sage", Palette.sage), ("sageText", Palette.sageText), ("sageWash", Palette.sageWash),
        ("sageDeepWash", Palette.sageDeepWash), ("peach", Palette.peach), ("peachText", Palette.peachText),
        ("peachWash", Palette.peachWash), ("amberText", Palette.amberText), ("amberBg", Palette.amberBg),
        ("coralText", Palette.coralText), ("coralBg", Palette.coralBg), ("neutralWash", Palette.neutralWash),
        ("neutralText", Palette.neutralText)
    ]

    var body: some View {
        CatalogSection(title: "Colors", identifier: "catalog.section.colors") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: Spacing.sm)], spacing: Spacing.sm) {
                ForEach(tokens, id: \.name) { token in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                            .fill(token.color)
                            .frame(height: 44)
                            .overlay {
                                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                                    .strokeBorder(Palette.hairline, lineWidth: 1)
                            }
                        Text(verbatim: token.name).font(Typography.footnote).foregroundStyle(Palette.ink2)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            HStack(spacing: Spacing.sm) {
                ForEach(AvatarPalette.allCases, id: \.self) { pair in
                    Avatar(name: "\(pair)", id: "\(pair)")
                }
            }
        }
    }
}
#endif
