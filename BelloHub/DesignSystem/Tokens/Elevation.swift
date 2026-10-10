//
//  Elevation.swift
//  BelloHub
//

import SwiftUI

/// Soft, tinted, two-layer shadows (docs/08-DESIGN-SYSTEM.md section 4). In dark mode shadows barely
/// show, so elevation falls back to a subtle top highlight and the card's own hairline.
enum Elevation {
    case e1
    case e2
    case sheet

    struct Layer {
        let opacity: Double
        let radius: CGFloat
        let offsetY: CGFloat
    }

    /// Always two layers (a tight contact shadow and a soft ambient one); the sheet's contact layer is empty.
    var layers: (contact: Layer, ambient: Layer) {
        switch self {
        case .e1: (Layer(opacity: 0.05, radius: 1, offsetY: 1), Layer(opacity: 0.14, radius: 10, offsetY: 8))
        case .e2: (Layer(opacity: 0.06, radius: 2, offsetY: 2), Layer(opacity: 0.28, radius: 18, offsetY: 20))
        case .sheet: (Layer(opacity: 0, radius: 0, offsetY: 0), Layer(opacity: 0.25, radius: 20, offsetY: -12))
        }
    }

    /// Shadow tint, a neutral green-graphite (rgba 46, 51, 41). The warm brown it replaced turned muddy under the
    /// sage and ivory of the 2026-10-10 palette.
    static let tint = Color(hex: 0x2E3329)
}

private struct ElevationModifier: ViewModifier {
    let elevation: Elevation
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if colorScheme == .dark {
            content.overlay(alignment: .top) {
                // Why: a shadow is invisible on a dark page, so a 1 pt top highlight carries the depth.
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.08), .clear], startPoint: .top, endPoint: .center
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        } else {
            let layers = elevation.layers
            content
                .shadow(color: Elevation.tint.opacity(layers.contact.opacity), radius: layers.contact.radius,
                        x: 0, y: layers.contact.offsetY)
                .shadow(color: Elevation.tint.opacity(layers.ambient.opacity), radius: layers.ambient.radius,
                        x: 0, y: layers.ambient.offsetY)
        }
    }
}

extension View {
    /// Applies a warm elevation. Pass the corner radius of the shape the view is clipped to.
    func belloElevation(_ elevation: Elevation, cornerRadius: CGFloat = Radius.card) -> some View {
        modifier(ElevationModifier(elevation: elevation, cornerRadius: cornerRadius))
    }
}
