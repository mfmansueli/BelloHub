//
//  BelloCardModifier.swift
//  BelloHub
//

import SwiftUI

private struct BelloCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let elevation: Elevation

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(Palette.surface, in: shape)
            .overlay { shape.strokeBorder(Palette.hairline, lineWidth: 1) }
            .belloElevation(elevation, cornerRadius: cornerRadius)
    }
}

extension View {
    /// A card: `surface` fill, 1 pt hairline and the warm elevation. Cards on `bg` use all three.
    func belloCard(cornerRadius: CGFloat = Radius.card, elevation: Elevation = .e1) -> some View {
        modifier(BelloCardModifier(cornerRadius: cornerRadius, elevation: elevation))
    }
}
