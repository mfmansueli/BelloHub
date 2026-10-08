//
//  Directional.swift
//  BelloHub
//

import SwiftUI

/// Horizontal motion that flips in right-to-left languages. Vertical motion is direction-neutral.
/// Never use `.offset(x:)` with a hard-coded sign in a screen: use this.
enum Directional {
    static func x(_ value: CGFloat, layoutDirection: LayoutDirection) -> CGFloat {
        layoutDirection == .rightToLeft ? -value : value
    }
}

private struct DirectionalOffsetModifier: ViewModifier {
    let horizontal: CGFloat
    let vertical: CGFloat
    @Environment(\.layoutDirection) private var layoutDirection

    func body(content: Content) -> some View {
        content.offset(
            x: Directional.x(horizontal, layoutDirection: layoutDirection),
            y: vertical
        )
    }
}

extension View {
    /// `offset` whose horizontal part follows the reading direction (positive means toward the trailing edge).
    func directionalOffset(x horizontal: CGFloat = 0, y vertical: CGFloat = 0) -> some View {
        modifier(DirectionalOffsetModifier(horizontal: horizontal, vertical: vertical))
    }
}
